# Aggregate

Collect observations from all project directories into the global homunculus.

## Run

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/aggregate.sh"
```

## Report

After running, report:

```
Aggregation complete.

Sources: [N] projects
New observations: [N]
Total global: [N]

Sources:
- [PROJECT_PATH_1]
- [PROJECT_PATH_2]
...
```

## If No Sources Found

```
No project sources found yet.

The aggregator auto-discovers projects with .claude/homunculus/ directories
in ~/Development, ~/Projects, and ~/Code.

To manually add a source:
Edit ~/.claude/homunculus/sources.json and add paths to the "sources" array.
```

## Managing Sources

The sources file is at `~/.claude/homunculus/sources.json`:

```json
{
  "sources": [
    "/path/to/project1",
    "/path/to/project2"
  ],
  "auto_discover": true
}
```

- `auto_discover: true` - Automatically find projects with observations
- `sources` - Manually specified project paths

Each aggregation tracks the last timestamp per source to avoid duplicates.
