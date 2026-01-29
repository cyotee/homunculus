---
description: Add a project to observation sources
---

# Add Source

Add a project path to the homunculus observation sources.

## Detect Current Project

First, check if current working directory has a `.claude/` directory:

```bash
test -d ".claude" && echo "HAS_CLAUDE" || echo "NO_CLAUDE"
```

## Behavior

**If user provides a path argument:**
Use that path.

**If no argument AND current directory has `.claude/`:**
Offer to add the current directory.

**If no argument AND no `.claude/` in current directory:**
```
No .claude/ directory found in current project.

Specify a path: /homunculus:add-source /path/to/project
```

## Add the Source

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/add-source.sh" "<path>"
```

## Handle Result

**ADDED:**
```
Added: /path/to/project

Observations from this project will be included in /homunculus:aggregate.
```

**EXISTS:**
```
Already configured: /path/to/project
```

**INVALID:**
```
Path does not exist: /path/to/project
```

## After Adding

Suggest next steps:
```
Use /homunculus:sources to see all configured sources.
Use /homunculus:aggregate to collect observations.
```
