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

**Single-producer rule**: `qa-init` is the sole **producer** of the preflight cache payload; the orchestrator is the sole **writer** of `qaspec/preflight-cache.yaml` (openspec mode) or the engram key `qa-init/{project}/preflight` (engram mode). `qa-browser` and `qa-visual` read the cache; they MUST NOT produce or write it.

**TTL / freshness rule**: a cache entry whose `probed_at` is older than `ttl_hours` (default 24) is treated as absent. When treated as absent, the runtime specialist reports `runtime_available: unknown — preflight cache stale, re-run /qa-init` and refuses rather than guessing. A cached `false` never permanently disables runtime QA.

**Refusal rule**: when `runtime_available` is not `true`, `qa-browser` and `qa-visual` MUST return `status: skipped` with a single INFO finding with the cached reason, and **zero** runtime findings. Fabricating findings from static reading when the runtime backend is unavailable is prohibited. The `verdict_contribution` depends on launch context: if `launched_under_recommendation: true` (specialist was dispatched by the orchestrator under a `runtime_recommendation`), emit `UNVERIFIED`; otherwise emit `CLEAN` (solo `/qa-browser <url>` invocations retain `CLEAN` — R5 containment).

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

### Preflight Outcome Truth Table

`qa-init` uses this table to map the orchestrator's probe results to cache fields. Each row is
an exclusive branch evaluated in order; stop at the first matching condition.

| Condition | `bash_available` | `runtime_available` | `unavailable_reason` | `detection_mechanism` | `smoke_test` |
|-----------|-----------------|--------------------|-----------------------|-----------------------|-------------|
| P0 absent or fails (no Bash) | `false` | `false` | `"bash-unavailable"` | `"bash-unavailable"` | `"skipped"` |
| P1 exit non-zero (no agent-browser) | `true` | `false` | `"agent-browser-not-installed"` | `null` | `"skipped"` |
| P2 succeeds, `chrome.available: true` (doctor confirmed Chrome) | `true` | (depends on P3) | (depends on P3) | `"doctor"` | (depends on P3) |
| P2 fails or `chrome.available: false`; P2b finds a binary | `true` | (depends on P3) | (depends on P3) | `"chrome-probe-fallback"` | (depends on P3) |
| P2 fails or `chrome.available: false`; P2b finds no binary | `true` | `false` | `"no-chrome-binary"` | `"chrome-probe-fallback"` | `"skipped"` |
| P3 exits non-zero (smoke test failed) | `true` | `false` | `"smoke-test-failed"` | (set by P2/P2b) | `"failed"` |
| P3 exits 0 (runtime confirmed) | `true` | `true` | `null` | (set by P2/P2b) | `"passed"` |

`unavailable_reason` enum values: `null`, `"bash-unavailable"`, `"agent-browser-not-installed"`, `"no-chrome-binary"`, `"smoke-test-failed"`.

### Engram Preflight Cache Key

```
title:     qa-init/{project-name}/preflight
topic_key: qa-init/{project-name}/preflight
type:      architecture
```

## Sole Writer

The orchestrator is the **only entity** that writes review artifacts to the filesystem or
to Engram review keys. Specialists are **producers**: they return their report payload in
their result envelope. The orchestrator is the **writer**: it persists the payload.

This distinction applies across all artifact types:

| Artifact | Producer | Writer |
|----------|----------|--------|
| Preflight cache (`qaspec/preflight-cache.yaml` / `qa-init/{project}/preflight`) | `qa-init` | Orchestrator |
| Specialist reports (`qaspec/reviews/{review-id}/*.md` / `qase/{review-id}/*-report`) | Each specialist | Orchestrator |
| Final report and actionable-issues | `qa-report` | Orchestrator |
| Dismissal patterns | `qa-feedback` | Orchestrator |

A specialist that uses its `Write` tool to persist a report has broken the sole-writer
rule. The only write a specialist MAY perform is `mem_save` to its own engram review key —
`mem_save` targets the memory store, not the audited repository (boundary B3).

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

## Review-Scoped Runtime Coverage

This section tracks whether runtime verification ran for a given review. It is **separate** from the
preflight cache above — the preflight cache describes the environment; this section describes the
review outcome.

### `runtime_unverified_reason` Enum

When `runtime_coverage` is `unverified`, the orchestrator records one of these values in the review
context and forwards it to `qa-report`:

| Value | Meaning |
|-------|---------|
| `null` | Coverage was verified or not required — no reason to record |
| `"bash-unavailable"` | Value-copied from preflight `unavailable_reason`; the environment has no Bash |
| `"agent-browser-not-installed"` | Value-copied from preflight; agent-browser CLI not found |
| `"no-chrome-binary"` | Value-copied from preflight; no Chrome-compatible binary detected |
| `"smoke-test-failed"` | Value-copied from preflight; smoke test exited non-zero |
| `"preflight-cache-absent"` | No preflight cache exists — `/qa-init` has not been run |
| `"preflight-cache-stale"` | Cache exists but `probed_at` is older than `ttl_hours` |
| `"no-url-resolved"` | URL resolution (Decision C) produced no result in an unattended run |
| `"user-declined"` | User answered "no" or "skip" at the URL resolution prompt |

The four value-copied spellings (`bash-unavailable`, `agent-browser-not-installed`, `no-chrome-binary`,
`smoke-test-failed`) are copied from the preflight `unavailable_reason` enum above. They are **copied,
not imported** — the frozen preflight enum and truth table above are untouched. `user-declined` has
no preflight row and never will; it is a review-time event, not an environment fact.
