---
description: Grow new capabilities from clustered instincts
---

# Evolve

User wants you to grow. In v2, evolution happens when **instincts cluster**.

## Not Born?

```
Can't evolve what doesn't exist.

/homunculus:init first.
```

## Check For Clustering

```bash
# Count instincts per domain
echo "=== Instinct Clustering ==="
for dir in personal inherited; do
  echo "--- $dir ---"
  grep -h "^domain:" ~/.claude/homunculus/instincts/$dir/*.md 2>/dev/null | \
    sed 's/domain: "//' | sed 's/"//' | sort | uniq -c | sort -rn
done
```

**Threshold**: 5+ instincts in same domain = evolution opportunity.

## What You Can Grow

Evolved capabilities become **real Claude Code plugins** — they appear in the `/` menu and work like any other skill or command.

| Type | When | Where |
|------|------|-------|
| Command | User-invoked task | `~/.claude/homunculus-evolved/commands/[name].md` |
| Skill | Auto-triggered behavior | `~/.claude/homunculus-evolved/skills/[name]/SKILL.md` |
| Agent | Deep specialist work | `~/.claude/homunculus-evolved/agents/[name].md` |

## Process

1. Check instinct clustering (above)
2. If 5+ in a domain, propose a capability synthesized from those instincts
3. Show the clustered instincts that led to this
4. When they say yes, write the capability:

### Ensure the evolved plugin exists

```bash
# Create evolved plugin if it doesn't exist yet
if [ ! -f ~/.claude/homunculus-evolved/.claude-plugin/plugin.json ]; then
  "${CLAUDE_PLUGIN_ROOT}/scripts/init-evolved-plugin.sh"
fi
```

### Write the capability

**For a Command** — write a `.md` file:

```bash
# Write command to evolved plugin
cat > ~/.claude/homunculus-evolved/commands/[name].md <<'EOF'
---
description: [Brief description]
---

# [Name]

[Command instructions for the LLM]
EOF
```

**For a Skill** — create a directory with `SKILL.md`:

```bash
mkdir -p ~/.claude/homunculus-evolved/skills/[name]
cat > ~/.claude/homunculus-evolved/skills/[name]/SKILL.md <<'EOF'
---
name: [name]
description: [Brief description of when this should trigger]
---

# [Name]

[Skill instructions for the LLM]
EOF
```

**For an Agent** — write a `.md` file AND update the manifest:

```bash
# Write agent definition
cat > ~/.claude/homunculus-evolved/agents/[name].md <<'EOF'
---
name: [name]
description: [Brief description]
model: sonnet
tools: [tool list]
---

# [Name]

[Agent instructions]
EOF

# Register agent in plugin manifest
jq --arg agent "./agents/[name].md" \
  '.agents += [$agent] | .agents |= unique' \
  ~/.claude/homunculus-evolved/.claude-plugin/plugin.json > /tmp/hm-plugin.json \
  && mv /tmp/hm-plugin.json ~/.claude/homunculus-evolved/.claude-plugin/plugin.json
```

### After writing, update tracking

```bash
# Bump evolved plugin patch version
CURRENT=$(jq -r '.version' ~/.claude/homunculus-evolved/.claude-plugin/plugin.json)
MAJOR=$(echo "$CURRENT" | cut -d. -f1)
MINOR=$(echo "$CURRENT" | cut -d. -f2)
PATCH=$(echo "$CURRENT" | cut -d. -f3)
NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"

jq --arg v "$NEW_VERSION" '.version = $v' \
  ~/.claude/homunculus-evolved/.claude-plugin/plugin.json > /tmp/hm-plugin.json \
  && mv /tmp/hm-plugin.json ~/.claude/homunculus-evolved/.claude-plugin/plugin.json

# Update installed_plugins.json timestamp and version
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")
jq --arg ts "$TIMESTAMP" --arg v "$NEW_VERSION" \
  '.plugins["homunculus-evolved@local"][0].lastUpdated = $ts | .plugins["homunculus-evolved@local"][0].version = $v' \
  ~/.claude/plugins/installed_plugins.json > /tmp/hm-installed.json \
  && mv /tmp/hm-installed.json ~/.claude/plugins/installed_plugins.json

# Update identity.json
jq --arg name "[NAME]" --arg type "[TYPE]" --arg ts "$TIMESTAMP" \
  '.homunculus.evolved += [{"name": $name, "type": $type, "created": $ts}]' \
  ~/.claude/homunculus/identity.json > /tmp/hm-identity.json \
  && mv /tmp/hm-identity.json ~/.claude/homunculus/identity.json
```

5. Confirm to user:

```
Done. I evolved [NAME] as a [TYPE].

Restart Claude Code to use /homunculus-evolved:[name]
```

## If No Clustering Yet

```
No clusters yet. You have [N] instincts spread across domains.

Keep working. I'll propose evolution when patterns emerge.
```

## For Project Direction

Use `/homunculus:grow` instead—that's about the project evolving, not you.
