#!/bin/bash
# List configured homunculus sources with status
#
# Shows: path, exists, has .claude/, observation count

set -e

GLOBAL_DIR="$HOME/.claude/homunculus"
SOURCES_FILE="$GLOBAL_DIR/sources.json"

# Ensure sources file exists
if [ ! -f "$SOURCES_FILE" ]; then
  echo '{"sources": []}' > "$SOURCES_FILE"
fi

sources=$(jq -r '.sources[]' "$SOURCES_FILE" 2>/dev/null)

if [ -z "$sources" ]; then
  echo "NO_SOURCES"
  exit 0
fi

# Output format: path|exists|has_claude|obs_count
while read -r source_path; do
  if [ -n "$source_path" ]; then
    exists="false"
    has_claude="false"
    obs_count=0

    if [ -d "$source_path" ]; then
      exists="true"
      if [ -d "$source_path/.claude" ]; then
        has_claude="true"
        obs_file="$source_path/.claude/homunculus/observations.jsonl"
        if [ -f "$obs_file" ]; then
          obs_count=$(wc -l < "$obs_file" | tr -d ' ')
        fi
      fi
    fi

    echo "$source_path|$exists|$has_claude|$obs_count"
  fi
done <<< "$sources"
