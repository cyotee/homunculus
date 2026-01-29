---
description: List configured observation sources with status
---

# Sources

Show all configured sources and their status.

## Run

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/sources.sh"
```

## Parse Output

Each line is `path|exists|has_claude|obs_count`

- `exists` - Directory exists on disk
- `has_claude` - Has a `.claude/` directory
- `obs_count` - Pending observations (not yet aggregated)

If output is `NO_SOURCES`, no sources are configured.

## Display Format

Present as a table:

```
Sources (N configured):

| Path | Status | Observations |
|------|--------|--------------|
| /path/to/project | Active | 42 pending |
| /missing/path | Missing | - |
| /no/claude/dir | No .claude/ | - |
```

**Status values:**
- **Active** - exists=true, has_claude=true
- **No .claude/** - exists=true, has_claude=false
- **Missing** - exists=false

## If No Sources

```
No sources configured.

Use /homunculus:add-source to add one.
```
