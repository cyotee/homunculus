#!/bin/bash
# Homunculus Observation Aggregator
# Collects observations from configured sources into global store.
# Prunes source files after verified aggregation.
#
# Usage:
#   aggregate.sh              - Aggregate from all configured sources
#   aggregate.sh --migrate <path>  - One-time migration from a specific path
#
# Sources are configured in ~/.claude/homunculus/sources.json

set -e

GLOBAL_DIR="$HOME/.claude/homunculus"
GLOBAL_OBS="$GLOBAL_DIR/observations.jsonl"
SOURCES_FILE="$GLOBAL_DIR/sources.json"

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

# Aggregate and prune a single source
# Returns: 0 on success, 1 on verification failure, 2 on no observations
aggregate_source() {
  local source_path="$1"
  local source_obs="$source_path/.claude/homunculus/observations.jsonl"

  if [ ! -f "$source_obs" ]; then
    echo "No observations at: $source_path"
    return 2
  fi

  local source_count=$(wc -l < "$source_obs" | tr -d ' ')
  if [ "$source_count" -eq 0 ]; then
    echo "Empty observations at: $source_path"
    return 2
  fi

  # Count global observations before
  local global_before=$(wc -l < "$GLOBAL_OBS" | tr -d ' ')

  # Append observations with source tag
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      echo "$line" | jq -c --arg src "$source_path" '. + {source: $src}' >> "$GLOBAL_OBS"
    fi
  done < "$source_obs"

  # Count global observations after
  local global_after=$(wc -l < "$GLOBAL_OBS" | tr -d ' ')
  local added=$((global_after - global_before))

  # Verify all observations were written
  if [ "$added" -ne "$source_count" ]; then
    echo "ERROR: Verification failed for $source_path"
    echo "  Expected: $source_count, Added: $added"
    echo "  Source file NOT pruned"
    return 1
  fi

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

  local obs_count=$(wc -l < "$obs_file" | tr -d ' ')
  if [ "$obs_count" -eq 0 ]; then
    echo "No observations to migrate (file is empty)"
    exit 0
  fi

  echo "Found $obs_count observations at: $migrate_path"
  echo "Migrating to global store..."
  echo ""

  aggregate_source "$migrate_path"
  local result=$?

  echo ""
  if [ $result -eq 0 ]; then
    echo "=== Migration Complete ==="
    local total=$(wc -l < "$GLOBAL_OBS" 2>/dev/null | tr -d ' ')
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

# Main aggregation from all configured sources
main_aggregate() {
  echo "=== Homunculus Observation Aggregator ==="
  echo ""

  local sources=$(jq -r '.sources[]' "$SOURCES_FILE" 2>/dev/null)

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
      aggregate_source "$source_path"
      source_count=$((source_count + 1))
    fi
  done <<< "$sources"

  echo ""
  echo "=== Aggregation Complete ==="
  local total=$(wc -l < "$GLOBAL_OBS" 2>/dev/null | tr -d ' ')
  echo "Sources: $source_count"
  echo "Total global observations: ${total:-0}"
}

# Parse arguments
if [ "$1" = "--migrate" ]; then
  if [ -z "$2" ]; then
    echo "ERROR: --migrate requires a path argument"
    echo ""
    echo "Usage: /homunculus:aggregate --migrate /path/to/worktree"
    exit 1
  fi
  migrate_path "$2"
else
  main_aggregate
fi
