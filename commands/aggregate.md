# Aggregate

Collect observations from configured sources into the global homunculus, then prune source files.

## Usage

**Standard aggregation (all sources):**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh"
```

**One-time migration from a path:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --migrate "<path>"
```

## Detect Arguments and Execute

Parse the user's command arguments and run the appropriate script invocation.

**If `--migrate <path>` provided:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --migrate "<path>"
```

**If no arguments:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh"
```

**If `--migrate` without path AND current directory has `.claude/homunculus/`:**
Ask: "Migrate observations from current directory?"
If confirmed:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --migrate "$(pwd)"
```

## Standard Aggregation Behavior

1. Read observations from each configured source
2. Append to global store with source tag
3. Verify write count matches source count
4. Prune source file (only after verification)

If verification fails, the source file is NOT pruned.

## Migration Behavior

The `--migrate` option performs a one-time harvest of observations from a path **without adding it to sources**. This is ideal for:

- Git worktrees before deletion
- Temporary project directories
- One-off observation collection

Behavior:
1. Validate path exists and has observations
2. Aggregate observations with source tag
3. Verify and prune (same safety as standard)
4. Report completion WITHOUT adding to sources

## Report

**Standard aggregation:**
```
Aggregation complete.

Sources: [N]
Total global observations: [N]
```

**Migration:**
```
Migration complete.

Migrated: [N] observations from /path/to/worktree
Total global observations: [N]

The path was NOT added to sources.
```

## If No Sources Configured

```
No sources configured.

Add project paths to ~/.claude/homunculus/sources.json

Or use --migrate to do a one-time harvest:
  /homunculus:aggregate --migrate /path/to/worktree
```

## Managing Sources

The sources file is at `~/.claude/homunculus/sources.json`:

```json
{
  "sources": [
    "/path/to/project1",
    "/path/to/project2"
  ]
}
```
