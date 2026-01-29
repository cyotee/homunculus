#!/bin/bash
# Add a source to homunculus configuration
#
# Usage: add-source.sh <path>
# Returns: ADDED, EXISTS, or INVALID

set -e

GLOBAL_DIR="$HOME/.claude/homunculus"
SOURCES_FILE="$GLOBAL_DIR/sources.json"

# Ensure global directory exists
mkdir -p "$GLOBAL_DIR"

# Initialize sources file if it doesn't exist
if [ ! -f "$SOURCES_FILE" ]; then
  echo '{"sources": []}' > "$SOURCES_FILE"
fi

SOURCE_PATH="$1"

if [ -z "$SOURCE_PATH" ]; then
  echo "ERROR: No path provided"
  exit 1
fi

# Check if path exists and resolve to absolute path
if [ ! -d "$SOURCE_PATH" ]; then
  echo "INVALID"
  exit 0
fi

SOURCE_PATH=$(cd "$SOURCE_PATH" && pwd)

# Check if already exists
existing=$(jq -r --arg path "$SOURCE_PATH" '.sources | index($path)' "$SOURCES_FILE" 2>/dev/null)

if [ "$existing" != "null" ]; then
  echo "EXISTS"
  exit 0
fi

# Add to sources
jq --arg path "$SOURCE_PATH" '.sources += [$path]' "$SOURCES_FILE" > "$SOURCES_FILE.tmp"
mv "$SOURCES_FILE.tmp" "$SOURCES_FILE"

echo "ADDED"
