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

## Runtime Preflight Cache

See also `skills/_shared/qase/oracle-contract.md` for the tier semantics that runtime specialists enforce after a successful preflight.

**Single-writer rule**: `qa-init` is the ONLY writer of the preflight cache. `qa-browser` and `qa-visual` read it and MUST NOT write to it.

**TTL / freshness rule**: a cache entry whose `probed_at` is older than `ttl_hours` (default 24) is treated as absent. When treated as absent, the runtime specialist reports `runtime_available: unknown — preflight cache stale, re-run /qa-init` and refuses rather than guessing. A cached `false` never permanently disables runtime QA.

**Refusal rule**: when `runtime_available` is not `true`, `qa-browser` and `qa-visual` MUST return `status: skipped` with `verdict_contribution: CLEAN`, a single INFO finding with the cached reason, and **zero** runtime findings. Fabricating findings from static reading when the runtime backend is unavailable is prohibited.

### Preflight Cache Schema (openspec: `qaspec/preflight-cache.yaml`)

```yaml
preflight:
  schema_version: 1
  bash_available: true | false
  agent_browser:
    available: true | false
    version: "0.32.2" | null
    detection: "command -v" | null
  doctor:
    ran: true | false
    exit_code: 0 | 1 | null
    failed_checks: []        # check names from doctor --json when exit_code is 1
  chrome_binary:
    available: true | false
    name: "chromium" | "google-chrome-stable" | "google-chrome" | "chrome" | null
    detection: "doctor" | "probe-fallback" | null
  smoke_test: passed | failed | skipped
  smoke_test_error: null | "stderr text from the failed smoke command"
  runtime_available: true | false
  unavailable_reason: null | "specific human-readable cause"
  detection_mechanism: "doctor" | "chrome-probe-fallback" | "bash-unavailable"
  probed_at: "ISO-8601"
  ttl_hours: 24
detected_start_hints:
  - command: "npm run dev"
    source: "package.json scripts.dev"
    likely_port: 3000
detected_cleanup_hook: null | { kind: "endpoint" | "command", value: "..." }
```

`detection_mechanism` records how the runtime backend was probed: `"doctor"` when `agent-browser doctor --json` ran and was parseable, `"chrome-probe-fallback"` when the multi-name Chrome probe was used, or `"bash-unavailable"` when no Bash tool was present.

### Engram Preflight Cache Key

```
title:     qa-init/{project-name}/preflight
topic_key: qa-init/{project-name}/preflight
type:      architecture
```

## Common Rules

- If mode is `none`, do NOT create or modify any project files. Return results inline only.
- If mode is `engram`, do NOT write any project files. Persist to Engram and return observation IDs.
- If mode is `openspec`, write files ONLY to the paths defined in `openspec-convention.md`.
- NEVER force `qaspec/` creation unless the orchestrator explicitly passed `openspec` mode.
- If you are unsure which mode to use, default to `none`.
- Binary artifacts (screenshots, `.webm`, `.har`) are NEVER stored in Engram. In `engram` and `none` modes they are written to a run-scoped temp directory (`${TMPDIR:-/tmp}/qase/{review-id}/{flow-slug}/...`) and referenced by absolute path with an explicit `(ephemeral)` marker. This satisfies the rule that engram mode writes no project files.

## Detail Level

The orchestrator may also pass `detail_level`: `concise | standard | deep`.
This controls output verbosity but does NOT affect what gets persisted — always persist the full artifact.

- `concise`: BLOCKERs and WARNINGs only, no code suggestions
- `standard`: BLOCKERs, WARNINGs, and top INFO findings with code suggestions
- `deep`: All findings including INFO, full code suggestions, references
