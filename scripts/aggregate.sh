#!/bin/bash
# Homunculus Observation Aggregator
# Collects observations from configured sources into global store.
# Supports incremental aggregation via state tracking.
#
# Usage:
#   aggregate.sh                    - Incremental aggregation from all sources
#   aggregate.sh --force            - Full re-aggregation ignoring state
#   aggregate.sh --migrate <path>   - One-time migration from a specific path
#   aggregate.sh --reprocess        - Restore archived observations for re-analysis
#   aggregate.sh --export           - Export all observations (current + archive)
#   aggregate.sh --import <file>    - Import exported observations
#
# Sources are configured in ~/.claude/homunculus/sources.json

set -e

GLOBAL_DIR="$HOME/.claude/homunculus"
GLOBAL_OBS="$GLOBAL_DIR/observations.jsonl"
GLOBAL_ARCHIVE="$GLOBAL_DIR/observations.archive.jsonl"
SOURCES_FILE="$GLOBAL_DIR/sources.json"
STATE_FILE="$GLOBAL_DIR/aggregation-state.json"
EXPORTS_DIR="$GLOBAL_DIR/exports"

FORCE_MODE=false

# Ensure global directory exists
mkdir -p "$GLOBAL_DIR"

# Initialize sources file if it doesn't exist
if [ ! -f "$SOURCES_FILE" ]; then
  echo '{"sources": []}' > "$SOURCES_FILE"
fi

# Initialize global observations if it doesn't exist
if [ ! -f "$GLOBAL_OBS" ]; then
  touch "$GLOBAL_OBS"
fi

# Initialize state file if it doesn't exist
if [ ! -f "$STATE_FILE" ]; then
  echo '{}' > "$STATE_FILE"
fi

# Get the last-aggregated timestamp for a source from state
get_last_timestamp() {
  local source_path="$1"
  jq -r --arg src "$source_path" '.[$src].lastTimestamp // "1970-01-01T00:00:00Z"' "$STATE_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z"
}

# Update state for a source after successful aggregation
update_state() {
  local source_path="$1"
  local newest_timestamp="$2"
  local lines_added="$3"
  local now
  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  local prev_lines
  prev_lines=$(jq -r --arg src "$source_path" '.[$src].linesAggregated // 0' "$STATE_FILE" 2>/dev/null || echo "0")
  local total_lines=$((prev_lines + lines_added))

  local tmp
  tmp=$(mktemp)
  jq --arg src "$source_path" \
     --arg ts "$newest_timestamp" \
     --arg now "$now" \
     --arg lines "$total_lines" \
     '.[$src] = {lastTimestamp: $ts, lastAggregated: $now, linesAggregated: ($lines|tonumber)}' \
     "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

# Aggregate a single source (incremental or full)
# Returns: 0 on success, 1 on verification failure, 2 on no observations
aggregate_source() {
  local source_path="$1"
  local source_obs="$source_path/.claude/homunculus/observations.jsonl"

  if [ ! -f "$source_obs" ]; then
    echo "No observations at: $source_path"
    return 2
  fi

  local source_count
  source_count=$(wc -l < "$source_obs" | tr -d ' ')
  if [ "$source_count" -eq 0 ]; then
    echo "Empty observations at: $source_path"
    return 2
  fi

  # Get cutoff timestamp for incremental mode
  local cutoff="1970-01-01T00:00:00Z"
  if [ "$FORCE_MODE" = false ]; then
    cutoff=$(get_last_timestamp "$source_path")
  fi

  # Count global observations before
  local global_before
  global_before=$(wc -l < "$GLOBAL_OBS" | tr -d ' ')

  # Track newest timestamp seen
  local newest_ts="$cutoff"
  local filtered_count=0

  # Append observations with source tag, filtering by timestamp if incremental
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      local obs_ts
      obs_ts=$(echo "$line" | jq -r '.timestamp // "1970-01-01T00:00:00Z"' 2>/dev/null || echo "1970-01-01T00:00:00Z")

      # Skip observations older than or equal to cutoff (incremental)
      if [ "$obs_ts" \> "$cutoff" ] || [ "$FORCE_MODE" = true ]; then
        echo "$line" | jq -c --arg src "$source_path" '. + {source: $src}' >> "$GLOBAL_OBS"
        filtered_count=$((filtered_count + 1))

        # Track newest
        if [ "$obs_ts" \> "$newest_ts" ]; then
          newest_ts="$obs_ts"
        fi
      fi
    fi
  done < "$source_obs"

  if [ "$filtered_count" -eq 0 ]; then
    echo "No new observations at: $source_path (all already aggregated)"
    return 2
  fi

  # Count global observations after
  local global_after
  global_after=$(wc -l < "$GLOBAL_OBS" | tr -d ' ')
  local added=$((global_after - global_before))

  # Verify filtered observations were written
  if [ "$added" -ne "$filtered_count" ]; then
    echo "ERROR: Verification failed for $source_path"
    echo "  Expected: $filtered_count, Added: $added"
    echo "  Source file NOT pruned"
    return 1
  fi

  # Update state with newest timestamp
  update_state "$source_path" "$newest_ts" "$added"

  # Prune source file
  : > "$source_obs"
  echo "Aggregated $added observations from: $source_path (pruned)"
  return 0
}

# Migrate observations from a single path (one-time, not added to sources)
migrate_path() {
  local migrate_path="$1"

  echo "=== Homunculus One-Time Migration ==="
  echo ""

  # Validate path exists
  if [ ! -d "$migrate_path" ]; then
    echo "ERROR: Path does not exist: $migrate_path"
    exit 1
  fi

  # Resolve to absolute path
  migrate_path=$(cd "$migrate_path" && pwd)

  local obs_file="$migrate_path/.claude/homunculus/observations.jsonl"
  if [ ! -f "$obs_file" ]; then
    echo "No observations found at: $migrate_path"
    echo ""
    echo "Expected: $obs_file"
    exit 0
  fi

  local obs_count
  obs_count=$(wc -l < "$obs_file" | tr -d ' ')
  if [ "$obs_count" -eq 0 ]; then
    echo "No observations to migrate (file is empty)"
    exit 0
  fi

  echo "Found $obs_count observations at: $migrate_path"
  echo "Migrating to global store..."
  echo ""

  # Force mode for migrations (always take everything)
  FORCE_MODE=true
  aggregate_source "$migrate_path"
  local result=$?

  echo ""
  if [ $result -eq 0 ]; then
    echo "=== Migration Complete ==="
    local total
    total=$(wc -l < "$GLOBAL_OBS" 2>/dev/null | tr -d ' ')
    echo "Migrated: $obs_count observations"
    echo "Total global observations: ${total:-0}"
    echo ""
    echo "The path was NOT added to sources."
    echo "Use /homunculus:add-source to add it permanently."
  elif [ $result -eq 1 ]; then
    echo "=== Migration Failed ==="
    echo "Verification failed. Source file preserved."
  fi
}

# Reprocess archived observations
reprocess_archive() {
  echo "=== Homunculus Reprocess Archive ==="
  echo ""

  if [ ! -f "$GLOBAL_ARCHIVE" ]; then
    echo "No archive found at: $GLOBAL_ARCHIVE"
    echo "Nothing to reprocess."
    exit 0
  fi

  local archive_count
  archive_count=$(wc -l < "$GLOBAL_ARCHIVE" | tr -d ' ')
  if [ "$archive_count" -eq 0 ]; then
    echo "Archive is empty. Nothing to reprocess."
    exit 0
  fi

  echo "Found $archive_count archived observations."
  echo "Restoring to active observations for re-analysis..."

  # Append archive to current observations
  cat "$GLOBAL_ARCHIVE" >> "$GLOBAL_OBS"

  local total
  total=$(wc -l < "$GLOBAL_OBS" | tr -d ' ')

  echo ""
  echo "=== Reprocess Complete ==="
  echo "Restored: $archive_count observations"
  echo "Total active observations: $total"
  echo ""
  echo "Run the observer agent to re-analyze these observations."
}

# Export all observations (current + archive)
export_observations() {
  echo "=== Homunculus Observation Export ==="
  echo ""

  mkdir -p "$EXPORTS_DIR"

  local timestamp
  timestamp=$(date +%Y%m%d-%H%M%S)
  local export_file="$EXPORTS_DIR/observations-$timestamp.jsonl.gz"
  local manifest_file="$EXPORTS_DIR/observations-$timestamp.manifest.json"

  local current_count=0
  local archive_count=0

  if [ -f "$GLOBAL_OBS" ]; then
    current_count=$(wc -l < "$GLOBAL_OBS" | tr -d ' ')
  fi
  if [ -f "$GLOBAL_ARCHIVE" ]; then
    archive_count=$(wc -l < "$GLOBAL_ARCHIVE" | tr -d ' ')
  fi

  local total=$((current_count + archive_count))

  if [ "$total" -eq 0 ]; then
    echo "No observations to export."
    exit 0
  fi

  echo "Exporting $total observations ($current_count active, $archive_count archived)..."

  # Combine and compress
  {
    [ -f "$GLOBAL_ARCHIVE" ] && cat "$GLOBAL_ARCHIVE"
    [ -f "$GLOBAL_OBS" ] && cat "$GLOBAL_OBS"
  } | gzip > "$export_file"

  # Find date range
  local earliest=""
  local latest=""
  if [ -f "$GLOBAL_ARCHIVE" ]; then
    earliest=$(head -1 "$GLOBAL_ARCHIVE" | jq -r '.timestamp // empty' 2>/dev/null)
  fi
  if [ -z "$earliest" ] && [ -f "$GLOBAL_OBS" ]; then
    earliest=$(head -1 "$GLOBAL_OBS" | jq -r '.timestamp // empty' 2>/dev/null)
  fi
  if [ -f "$GLOBAL_OBS" ]; then
    latest=$(tail -1 "$GLOBAL_OBS" | jq -r '.timestamp // empty' 2>/dev/null)
  fi
  if [ -z "$latest" ] && [ -f "$GLOBAL_ARCHIVE" ]; then
    latest=$(tail -1 "$GLOBAL_ARCHIVE" | jq -r '.timestamp // empty' 2>/dev/null)
  fi

  # Create manifest
  cat > "$manifest_file" << EOF
{
  "exported": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "version": "2.4.0",
  "observations": {
    "active": $current_count,
    "archived": $archive_count,
    "total": $total
  },
  "dateRange": {
    "earliest": "${earliest:-unknown}",
    "latest": "${latest:-unknown}"
  },
  "file": "$(basename "$export_file")"
}
EOF

  local file_size
  file_size=$(ls -lh "$export_file" | awk '{print $5}')

  echo ""
  echo "=== Export Complete ==="
  echo "File: $export_file"
  echo "Size: $file_size"
  echo "Observations: $total ($current_count active, $archive_count archived)"
  echo "Date range: ${earliest:-unknown} to ${latest:-unknown}"
  echo "Manifest: $manifest_file"
  echo ""
  echo "Import on another instance with:"
  echo "  /homunculus:aggregate --import $export_file"
}

# Import exported observations
import_observations() {
  local import_file="$1"

  echo "=== Homunculus Observation Import ==="
  echo ""

  if [ ! -f "$import_file" ]; then
    echo "ERROR: File not found: $import_file"
    exit 1
  fi

  # Detect if gzipped
  local is_gz=false
  case "$import_file" in
    *.gz) is_gz=true ;;
  esac

  local import_count
  if [ "$is_gz" = true ]; then
    import_count=$(gunzip -c "$import_file" | wc -l | tr -d ' ')
  else
    import_count=$(wc -l < "$import_file" | tr -d ' ')
  fi

  if [ "$import_count" -eq 0 ]; then
    echo "Import file is empty. Nothing to import."
    exit 0
  fi

  echo "Found $import_count observations to import."
  echo "Appending to global observations..."
  echo ""
  echo "NOTE: Duplicate observations may exist if importing"
  echo "from the same instance. This is harmless but increases"
  echo "file size. Run --export after pruning if needed."

  local before
  before=$(wc -l < "$GLOBAL_OBS" | tr -d ' ')

  if [ "$is_gz" = true ]; then
    gunzip -c "$import_file" >> "$GLOBAL_OBS"
  else
    cat "$import_file" >> "$GLOBAL_OBS"
  fi

  local after
  after=$(wc -l < "$GLOBAL_OBS" | tr -d ' ')
  local added=$((after - before))

  echo ""
  echo "=== Import Complete ==="
  echo "Imported: $added observations"
  echo "Total active observations: $after"
  echo ""
  echo "Run the observer agent to analyze imported observations."
}

# Main aggregation from all configured sources
main_aggregate() {
  echo "=== Homunculus Observation Aggregator ==="
  if [ "$FORCE_MODE" = true ]; then
    echo "(Force mode: ignoring state, re-aggregating everything)"
  fi
  echo ""

  local sources
  sources=$(jq -r '.sources[]' "$SOURCES_FILE" 2>/dev/null)

  if [ -z "$sources" ]; then
    echo "No sources configured."
    echo ""
    echo "Add project paths to: $SOURCES_FILE"
    echo ""
    echo "Example:"
    echo '  {"sources": ["/path/to/project1", "/path/to/project2"]}'
    echo ""
    echo "Or use --migrate to do a one-time harvest:"
    echo '  /homunculus:aggregate --migrate /path/to/worktree'
    exit 0
  fi

  echo "Aggregating observations..."
  echo ""

  local total_added=0
  local source_count=0

  while read -r source_path; do
    if [ -n "$source_path" ]; then
      aggregate_source "$source_path" || true
      source_count=$((source_count + 1))
    fi
  done <<< "$sources"

  echo ""
  echo "=== Aggregation Complete ==="
  local total
  total=$(wc -l < "$GLOBAL_OBS" 2>/dev/null | tr -d ' ')
  echo "Sources: $source_count"
  echo "Total global observations: ${total:-0}"
}

# Parse arguments
case "$1" in
  --migrate)
    if [ -z "$2" ]; then
      echo "ERROR: --migrate requires a path argument"
      echo ""
      echo "Usage: /homunculus:aggregate --migrate /path/to/worktree"
      exit 1
    fi
    migrate_path "$2"
    ;;
  --force)
    FORCE_MODE=true
    main_aggregate
    ;;
  --reprocess)
    reprocess_archive
    ;;
  --export)
    export_observations
    ;;
  --import)
    if [ -z "$2" ]; then
      echo "ERROR: --import requires a file path argument"
      echo ""
      echo "Usage: /homunculus:aggregate --import /path/to/export.jsonl.gz"
      exit 1
    fi
    import_observations "$2"
    ;;
  "")
    main_aggregate
    ;;
  *)
    echo "Unknown option: $1"
    echo ""
    echo "Usage:"
    echo "  aggregate.sh                    - Incremental aggregation"
    echo "  aggregate.sh --force            - Full re-aggregation"
    echo "  aggregate.sh --migrate <path>   - One-time migration"
    echo "  aggregate.sh --reprocess        - Restore archive for re-analysis"
    echo "  aggregate.sh --export           - Export all observations"
    echo "  aggregate.sh --import <file>    - Import exported observations"
    exit 1
    ;;
esac
