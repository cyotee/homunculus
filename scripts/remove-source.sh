#!/bin/bash
# Remove a source from homunculus configuration
#
# Usage: remove-source.sh <path>
# Returns: REMOVED, NOT_FOUND

set -e

GLOBAL_DIR="$HOME/.claude/homunculus"
SOURCES_FILE="$GLOBAL_DIR/sources.json"

if [ ! -f "$SOURCES_FILE" ]; then
  echo "NOT_FOUND"
  exit 0
fi

SOURCE_PATH="$1"

if [ -z "$SOURCE_PATH" ]; then
  echo "ERROR: No path provided"
  exit 1
fi

# Check if exists
existing=$(jq -r --arg path "$SOURCE_PATH" '.sources | index($path)' "$SOURCES_FILE" 2>/dev/null)

if [ "$existing" == "null" ]; then
  echo "NOT_FOUND"
  exit 0
fi

# Remove from sources
jq --arg path "$SOURCE_PATH" '.sources = (.sources | map(select(. != $path)))' "$SOURCES_FILE" > "$SOURCES_FILE.tmp"
mv "$SOURCES_FILE.tmp" "$SOURCES_FILE"

echo "REMOVED"
