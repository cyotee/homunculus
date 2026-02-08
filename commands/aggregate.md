# Aggregate

Collect observations from configured sources into the global homunculus, then prune source files. Supports incremental aggregation, full rebuild, archive reprocessing, and portable export/import.

## Usage

**Incremental aggregation (default — only new observations):**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh"
```

**Force full re-aggregation (ignore state):**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --force
```

**One-time migration from a path:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --migrate "<path>"
```

**Reprocess archived observations:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --reprocess
```

**Export all observations (current + archive):**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --export
```

**Import exported observations from another instance:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --import "<file>"
```

## Detect Arguments and Execute

Parse the user's command arguments and run the appropriate script invocation.

**If `--force` provided:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --force
```

**If `--migrate <path>` provided:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --migrate "<path>"
```

**If `--reprocess` provided:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --reprocess
```

**If `--export` provided:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --export
```

**If `--import <file>` provided:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --import "<file>"
```

**If `--migrate` without path AND current directory has `.claude/homunculus/`:**
Ask: "Migrate observations from current directory?"
If confirmed:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh" --migrate "$(pwd)"
```

**If no arguments:**
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh"
```

## Incremental Aggregation (Default)

Uses `~/.claude/homunculus/aggregation-state.json` to track the last-aggregated timestamp per source. Only observations newer than the stored timestamp are appended to the global store.

1. Read state to get cutoff timestamp per source
2. Filter observations newer than cutoff
3. Append to global store with source tag
4. Verify write count matches filtered count
5. Update state with newest timestamp
6. Prune source file (only after verification)

If verification fails, the source file is NOT pruned and state is NOT updated.

## Force Mode

The `--force` flag ignores the aggregation state and re-processes all observations from all sources. Use this to rebuild after state corruption or when you want a clean re-aggregation.

## Migration Behavior

The `--migrate` option performs a one-time harvest of observations from a path **without adding it to sources**. Always runs in force mode. Ideal for:

- Git worktrees before deletion
- Temporary project directories
- One-off observation collection

## Reprocess Behavior

The `--reprocess` option restores archived observations (`observations.archive.jsonl`) back into the active observations file (`observations.jsonl`). This allows the observer agent to re-analyze previously processed observations. Use when:

- Instincts were lost or corrupted
- Observer logic has been improved and you want to re-derive instincts
- Starting fresh analysis on existing data

## Export Behavior

The `--export` option combines active observations and archived observations into a single compressed file (`observations-TIMESTAMP.jsonl.gz`) with a companion manifest. Use for:

- Backing up before major changes
- Migrating to a new machine
- Sharing observation data between instances

## Import Behavior

The `--import` option loads an exported observations file (`.jsonl.gz` or plain `.jsonl`) into the active observations. Supports both compressed and uncompressed files. Note: duplicates are not deduplicated; this is harmless but increases file size.

## Report

**Incremental aggregation:**
```
Aggregation complete.

Sources: [N]
Total global observations: [N]
```

**Force aggregation:**
```
(Force mode: ignoring state, re-aggregating everything)

Aggregation complete.
...
```

**Migration:**
```
Migration complete.

Migrated: [N] observations from /path/to/worktree
Total global observations: [N]

The path was NOT added to sources.
```

**Reprocess:**
```
Restored: [N] observations
Total active observations: [N]

Run the observer agent to re-analyze these observations.
```

**Export:**
```
File: [PATH]
Size: [SIZE]
Observations: [N] ([N] active, [N] archived)
```

**Import:**
```
Imported: [N] observations
Total active observations: [N]
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
