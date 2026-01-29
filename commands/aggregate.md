# Aggregate

Collect observations from configured sources into the global homunculus, then prune source files.

## Run

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh"
```

## Behavior

1. Read observations from each configured source
2. Append to global store with source tag
3. Verify write count matches source count
4. Prune source file (only after verification)

If verification fails, the source file is NOT pruned.

## Report

After running, report:

```
Aggregation complete.

Sources: [N]
Total global observations: [N]
```

## If No Sources Configured

```
No sources configured.

Add project paths to ~/.claude/homunculus/sources.json

Example:
  {"sources": ["/path/to/project1", "/path/to/project2"]}
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
