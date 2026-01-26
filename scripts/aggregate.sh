#!/bin/bash
# Homunculus Observation Aggregator
# Collects observations from local project directories into global store.
# Deduplicates by timestamp to avoid duplicate entries.

set -e

GLOBAL_DIR="$HOME/.claude/homunculus"
GLOBAL_OBS="$GLOBAL_DIR/observations.jsonl"
SOURCES_FILE="$GLOBAL_DIR/sources.json"
AGGREGATION_STATE="$GLOBAL_DIR/aggregation-state.json"

# Ensure global directory exists
mkdir -p "$GLOBAL_DIR"

# Initialize sources file if it doesn't exist
if [ ! -f "$SOURCES_FILE" ]; then
  echo '{"sources": [], "auto_discover": true}' > "$SOURCES_FILE"
fi

# Initialize aggregation state if it doesn't exist
if [ ! -f "$AGGREGATION_STATE" ]; then
  echo '{}' > "$AGGREGATION_STATE"
fi

# Auto-discover projects with .claude/homunculus directories
discover_sources() {
  local auto_discover=$(jq -r '.auto_discover // true' "$SOURCES_FILE")

  if [ "$auto_discover" = "true" ]; then
    # Find all .claude/homunculus/observations.jsonl files
    # Exclude the global one and look in common development directories
    find "$HOME/Development" "$HOME/Projects" "$HOME/Code" -name "observations.jsonl" -path "*/.claude/homunculus/*" 2>/dev/null | while read obs_file; do
      # Get project root (parent of .claude)
      local project_root=$(dirname "$(dirname "$(dirname "$obs_file")")")

      # Skip if it's the global directory
      if [ "$project_root" = "$HOME" ]; then
        continue
      fi

      # Add to sources if not already there
      local existing=$(jq -r --arg path "$project_root" '.sources[] | select(. == $path)' "$SOURCES_FILE" 2>/dev/null)
      if [ -z "$existing" ]; then
        jq --arg path "$project_root" '.sources += [$path]' "$SOURCES_FILE" > "$SOURCES_FILE.tmp" && mv "$SOURCES_FILE.tmp" "$SOURCES_FILE"
        echo "Discovered: $project_root"
      fi
    done
  fi
}

# Get last aggregation timestamp for a source
get_last_timestamp() {
  local source_path="$1"
  local source_key=$(echo "$source_path" | sed 's/[\/]/_/g')
  jq -r --arg key "$source_key" '.[$key] // "1970-01-01T00:00:00Z"' "$AGGREGATION_STATE"
}

# Update last aggregation timestamp for a source
set_last_timestamp() {
  local source_path="$1"
  local timestamp="$2"
  local source_key=$(echo "$source_path" | sed 's/[\/]/_/g')
  jq --arg key "$source_key" --arg ts "$timestamp" '.[$key] = $ts' "$AGGREGATION_STATE" > "$AGGREGATION_STATE.tmp" && mv "$AGGREGATION_STATE.tmp" "$AGGREGATION_STATE"
}

# Aggregate observations from a single source
aggregate_source() {
  local source_path="$1"
  local source_obs="$source_path/.claude/homunculus/observations.jsonl"

  if [ ! -f "$source_obs" ]; then
    echo "No observations at: $source_path"
    return 0
  fi

  local last_ts=$(get_last_timestamp "$source_path")
  local count=0
  local latest_ts="$last_ts"

  # Read observations newer than last aggregation
  while IFS= read -r line; do
    local ts=$(echo "$line" | jq -r '.timestamp // "1970-01-01T00:00:00Z"')

    # Skip if older than or equal to last aggregation
    if [[ "$ts" < "$last_ts" ]] || [[ "$ts" = "$last_ts" ]]; then
      continue
    fi

    # Add source path to observation and append to global
    echo "$line" | jq -c --arg src "$source_path" '. + {source: $src}' >> "$GLOBAL_OBS"
    count=$((count + 1))

    # Track latest timestamp
    if [[ "$ts" > "$latest_ts" ]]; then
      latest_ts="$ts"
    fi
  done < "$source_obs"

  # Update last aggregation timestamp
  if [ "$count" -gt 0 ]; then
    set_last_timestamp "$source_path" "$latest_ts"
    echo "Aggregated $count observations from: $source_path"
  else
    echo "No new observations from: $source_path"
  fi
}

# Main aggregation
main() {
  echo "=== Homunculus Observation Aggregator ==="
  echo ""

  # Discover new sources
  echo "Discovering sources..."
  discover_sources
  echo ""

  # Get all sources
  local sources=$(jq -r '.sources[]' "$SOURCES_FILE" 2>/dev/null)

  if [ -z "$sources" ]; then
    echo "No sources found. Add project paths to: $SOURCES_FILE"
    echo "Or enable auto_discover to scan Development/Projects/Code directories."
    exit 0
  fi

  # Aggregate from each source
  echo "Aggregating observations..."
  echo ""

  echo "$sources" | while read source_path; do
    if [ -n "$source_path" ]; then
      aggregate_source "$source_path"
    fi
  done

  echo ""
  echo "=== Aggregation Complete ==="

  # Show summary
  local total=$(wc -l < "$GLOBAL_OBS" 2>/dev/null | tr -d ' ')
  echo "Total global observations: ${total:-0}"
}

# Run main
main "$@"
