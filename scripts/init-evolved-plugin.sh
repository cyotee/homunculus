#!/bin/bash
# init-evolved-plugin.sh
# Creates the homunculus-evolved plugin directory and registers it
# with Claude Code's plugin system. Idempotent — safe to run multiple times.

set -euo pipefail

EVOLVED_DIR="${HOME}/.claude/homunculus-evolved"
PLUGIN_JSON="${EVOLVED_DIR}/.claude-plugin/plugin.json"
INSTALLED_PLUGINS="${HOME}/.claude/plugins/installed_plugins.json"
SETTINGS="${HOME}/.claude/settings.json"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# ─── Create plugin directory structure ───

if [ -d "$EVOLVED_DIR" ] && [ -f "$PLUGIN_JSON" ]; then
  echo "Evolved plugin already exists at ${EVOLVED_DIR}"
else
  echo "Creating evolved plugin at ${EVOLVED_DIR}"
  mkdir -p "${EVOLVED_DIR}/.claude-plugin"
  mkdir -p "${EVOLVED_DIR}/commands"
  mkdir -p "${EVOLVED_DIR}/skills"
  mkdir -p "${EVOLVED_DIR}/agents"

  cat > "$PLUGIN_JSON" <<'MANIFEST'
{
  "name": "homunculus-evolved",
  "version": "0.1.0",
  "description": "Capabilities evolved by your homunculus. Commands, skills, and agents grown from observed patterns.",
  "author": {
    "name": "homunculus"
  },
  "license": "MIT",
  "commands": "./commands/",
  "skills": "./skills/",
  "agents": []
}
MANIFEST

  echo "Plugin structure created."
fi

# ─── Register in installed_plugins.json ───

if [ -f "$INSTALLED_PLUGINS" ]; then
  # Check if already registered
  if jq -e '.plugins["homunculus-evolved@local"]' "$INSTALLED_PLUGINS" >/dev/null 2>&1; then
    echo "Plugin already registered in installed_plugins.json"
  else
    echo "Registering plugin in installed_plugins.json"
    jq --arg path "$EVOLVED_DIR" --arg ts "$TIMESTAMP" \
      '.plugins["homunculus-evolved@local"] = [{"scope":"user","installPath":$path,"version":"0.1.0","installedAt":$ts,"lastUpdated":$ts}]' \
      "$INSTALLED_PLUGINS" > "${INSTALLED_PLUGINS}.tmp" && mv "${INSTALLED_PLUGINS}.tmp" "$INSTALLED_PLUGINS"
    echo "Registered."
  fi
else
  echo "Warning: ${INSTALLED_PLUGINS} not found. Plugin not registered."
fi

# ─── Enable in settings.json ───

if [ -f "$SETTINGS" ]; then
  if jq -e '.enabledPlugins["homunculus-evolved@local"]' "$SETTINGS" >/dev/null 2>&1; then
    echo "Plugin already enabled in settings.json"
  else
    echo "Enabling plugin in settings.json"
    jq '.enabledPlugins["homunculus-evolved@local"] = true' \
      "$SETTINGS" > "${SETTINGS}.tmp" && mv "${SETTINGS}.tmp" "$SETTINGS"
    echo "Enabled."
  fi
else
  echo "Warning: ${SETTINGS} not found. Plugin not enabled."
fi

echo ""
echo "Evolved plugin ready at ${EVOLVED_DIR}"
echo "Restart Claude Code to discover evolved capabilities."
