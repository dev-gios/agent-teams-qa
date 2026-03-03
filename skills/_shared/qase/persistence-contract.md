# Persistence Contract (shared across all QASE skills)

## Mode Resolution

The orchestrator passes `artifact_store.mode` with one of: `engram | openspec | none`.

Default resolution (when orchestrator does not explicitly set a mode):
1. If Engram is available → use `engram`
2. Otherwise → use `none`

`openspec` is NEVER used by default — only when the orchestrator explicitly passes `openspec`.

When falling back to `none`, recommend the user enable `engram` for better results.

## Engram Detection

**The orchestrator** is responsible for detecting Engram availability BEFORE launching any sub-agents.

### How to Detect

Engram is available if the MCP tools `mem_save`, `mem_search`, and `mem_get_observation` are present in the current session. These tools are provided by the Engram plugin (`engram@engram`).

**Detection method**: Attempt to call `mem_stats()`. If it succeeds, Engram is available. If the tool doesn't exist or fails, Engram is unavailable.

### Detection Flow

```
BEFORE launching any sub-agent:
├── Call mem_stats()
│   ├── SUCCESS → artifact_store.mode = "engram"
│   └── FAIL or tool not found → artifact_store.mode = "none"
├── Exception: user explicitly requested "openspec" → use "openspec"
└── Pass resolved mode to ALL sub-agents in their CONTEXT block
```

### Rules

- Detect ONCE per review pipeline, not per sub-agent
- Pass the resolved mode to every sub-agent — sub-agents NEVER detect on their own
- If Engram was available at detection but fails mid-review, sub-agents should degrade to `none` gracefully and note the failure in their output

## Behavior Per Mode

| Mode | Read from | Write to | Project files |
|------|-----------|----------|---------------|
| `engram` | Engram (see `engram-convention.md`) | Engram | Never |
| `openspec` | Filesystem (see `openspec-convention.md`) | Filesystem | Yes |
| `none` | Orchestrator prompt context | Nowhere | Never |

## Common Rules

- If mode is `none`, do NOT create or modify any project files. Return results inline only.
- If mode is `engram`, do NOT write any project files. Persist to Engram and return observation IDs.
- If mode is `openspec`, write files ONLY to the paths defined in `openspec-convention.md`.
- NEVER force `qaspec/` creation unless the orchestrator explicitly passed `openspec` mode.
- If you are unsure which mode to use, default to `none`.

## Detail Level

The orchestrator may also pass `detail_level`: `concise | standard | deep`.
This controls output verbosity but does NOT affect what gets persisted — always persist the full artifact.

- `concise`: BLOCKERs and WARNINGs only, no code suggestions
- `standard`: BLOCKERs, WARNINGs, and top INFO findings with code suggestions
- `deep`: All findings including INFO, full code suggestions, references
