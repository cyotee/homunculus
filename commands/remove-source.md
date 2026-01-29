---
description: Remove a project from observation sources
---

# Remove Source

Remove a project path from the homunculus observation sources.

## Check Current Sources First

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/sources.sh"
```

## Behavior

**If user provides a path argument:**
Remove that exact path.

**If no argument:**
Show current sources and ask which to remove:
```
Current sources:
1. /path/to/project1
2. /path/to/project2

Which source to remove? (number or path)
```

## Remove the Source

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/remove-source.sh" "<path>"
```

## Handle Result

**REMOVED:**
```
Removed: /path/to/project

This project's observations will no longer be aggregated.
Note: Existing observations in ~/.claude/homunculus/ are preserved.
```

**NOT_FOUND:**
```
Not configured: /path/to/project

Use /homunculus:sources to see configured sources.
```

## Warning for Active Sources

If the source has pending observations (obs_count > 0), warn before removing:
```
This source has [N] pending observations that haven't been aggregated.

Run /homunculus:aggregate first to preserve them, or confirm removal to discard.
```
