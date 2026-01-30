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

## Detect Arguments

Check if user provided `--migrate` flag:

**If `--migrate <path>` provided:**
Run the script with the migrate flag and path.

**If no arguments:**
Run standard aggregation from all sources.

**If `--migrate` without path AND current directory has `.claude/homunculus/`:**
Offer to migrate from current directory.

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
