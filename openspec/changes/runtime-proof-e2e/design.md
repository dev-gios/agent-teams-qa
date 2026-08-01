# Design: runtime-proof-e2e

**Change**: `runtime-proof-e2e`
**Phase**: design
**Input**: `openspec/changes/runtime-proof-e2e/proposal.md` (authoritative — decisions A, B, C, D are settled)
**Command syntax source**: `openspec/changes/runtime-proof-e2e/agent-browser-command-reference.md` (892 lines, `--help` output for agent-browser 0.32.2)

---

## Technical Approach

QASE gains a **runtime evidence pipeline** whose output is a step-by-step proof rather than an opinion. The pipeline has four moving parts and one new shared contract:

1. **Capability gate** (`qa-init`) — proves that a browser can actually be driven from this executor, in this sandbox, right now, and caches the verdict. Runtime specialists never probe the environment themselves; they read the cache.
2. **Flow engine** (`qa-browser` Step 9) — executes an orchestrator-supplied user flow one step at a time, with per-step buffer isolation so every step owns its own console, error, and network record.
3. **Oracle resolver** (new `oracle-contract.md`) — for each step, deterministically decides where the expectation came from, and stamps a tier on it. The tier is a checkable claim, not a self-declared label.
4. **Authority gate** (`severity-contract.md` + `qa-report`) — converts tier into blocking power. L1/L2/L3-schema can veto; L3-inferred and L4 structurally cannot.

The architectural pattern is **pipes-and-filters over a stateful external process**: each skill step is a filter that consumes browser state and emits an evidence row; the agent-browser daemon is the stateful process, addressed through a single named session. There is no adapter layer, no abstraction over the browser backend, and no second backend — the proposal removed Chrome DevTools MCP outright rather than hiding it behind an interface (non-goal 8).

### Layering and boundaries

```
┌──────────────────────────────────────────────────────────────────────┐
│ L0  agent-browser CLI 0.32.2  (external, version-pinned)             │
│     Reached ONLY through Bash. The MCP `core` tools profile is NOT   │
│     a supported backend — it lacks network, viewport, vitals, diff.  │
└──────────────────────────────────────────────────────────────────────┘
                    ▲ Bash only
┌───────────────────┴──────────────────────────────────────────────────┐
│ L1  Runtime specialists — the ONLY files containing browser commands │
│     skills/qa-init/SKILL.md      (preflight)                         │
│     skills/qa-browser/SKILL.md   (flow engine + runtime health)      │
│     skills/qa-visual/SKILL.md    (visual audit + baseline diff)      │
└──────────────────────────────────────────────────────────────────────┘
                    ▲ reads cache / writes evidence
┌───────────────────┴──────────────────────────────────────────────────┐
│ L2  Shared contracts — ZERO browser commands, by rule                │
│     oracle-contract.md (NEW) · severity-contract.md · issue-format.md│
│     persistence-contract.md · engram-convention.md ·                 │
│     openspec-convention.md · routing-rules.md                        │
└──────────────────────────────────────────────────────────────────────┘
                    ▲ reads findings + metadata envelope
┌───────────────────┴──────────────────────────────────────────────────┐
│ L3  Consensus — skills/qa-report/SKILL.md                            │
│     Reads findings and tiers. Never reads raw artifacts.             │
└──────────────────────────────────────────────────────────────────────┘
```

Four boundaries are load-bearing and are stated here so `sdd-verify` can check them:

| # | Boundary | Rule | Why it matters |
|---|----------|------|----------------|
| B1 | **Capability** | Only `qa-init` writes the preflight cache. `qa-browser` and `qa-visual` read it and refuse to run when `runtime_available: false`. | Stops each specialist reinventing detection and disagreeing about it. |
| B2 | **Backend** | No file under `skills/_shared/qase/` may contain an `agent-browser` command string. | A future backend swap touches exactly three files. |
| B3 | **Authority** | Tier semantics are defined in exactly one place (`oracle-contract.md`). `severity-contract.md` references it; `qa-report` enforces it. | Prevents the tier gate from drifting between the definition and the enforcement. |
| B4 | **Evidence** | `qa-report` consumes findings and the metadata envelope only. It never opens a screenshot, HAR, or recording. | Keeps consensus cheap and keeps binary artifacts out of the token budget. |

---

## Architecture Decisions

The four proposal decisions are recorded here in ADR form. They are **settled** — the records exist so the reasoning survives the proposal, and so a future revisit has the rejected alternatives in front of it.

### ADR-A — Tier-gated veto for `qa-browser`

**Context.** `veto_power: true` appears only on two specialists that never execute anything (`qa-security`, `qa-architect`). The only specialist that executes a user flow is `veto_power: false`. Executed evidence cannot block delivery; unexecuted opinion can. `qa-report` Step 3 is literally named "Apply Veto Logic" and reads a two-row table.

**Decision.** `skills/qa-browser/SKILL.md` frontmatter becomes `veto_power: true`. The veto is **scoped per finding** in `severity-contract.md` to BLOCKERs whose Oracle Tier is L1, L2, or L3-schema. `qa-visual` remains `veto_power: false`.

**Consequences.**
- Veto membership stops being a per-agent boolean and becomes a per-finding predicate for one member. `qa-report` Step 3 must evaluate a finding-level condition, not an agent-level lookup (see *Veto Gate Design* below — this is the R11 resolution).
- Three files must agree or the system lies: frontmatter, the severity veto table, and the `qa-report` Step 3 inline pseudocode. A **sync invariant** is defined below with a mechanical check.
- Blast radius on being wrong is two lines (`veto_power: false` + delete one table row), and flow evidence, oracle tiers, and the CLI migration all keep working after that revert.
- `skills/qa-report/SKILL.md` becomes an affected file that the proposal's table does not list. See *Deviations from the proposal* below.

**Rejected — escalate through severity rules only (proposal option b).** Cheaper, and it does produce REJECT on L1/L2 failures. Rejected because the frontmatter would still declare the runtime specialist non-authoritative, and `qa-report`'s override path would still treat executed evidence as overridable-by-consensus. It fixes the symptom in one file and preserves the cause in another.

**Rejected — blanket veto for all runtime skills.** `qa-visual` findings are overwhelmingly L4 (contrast ratios, spacing, motion heuristics) and it executes no flows. Granting veto would grant authority it cannot ground — the same unexamined authority this change is correcting.

**Rejected — ship veto-capable but flagged off.** Would require a fourth synchronised location (an enable flag) and would leave the inverted metadata in place for an unbounded period. The two-line revert is a cheaper safety mechanism than a feature flag.

### ADR-B — Extend `qa-browser` in place; no `qa-flow` skill in this slice

**Context.** `skills/qa-browser/SKILL.md:244` already has `### Step 9: User Flow Testing`. It is a stub: "execute the action", "verify step completed", with no oracle and no evidence record. The slice already changes the browser backend, adds a shared contract, rewires severity and veto, and adds a preflight to `qa-init`.

**Decision.** Flow evidence, network interception, session management, and oracle tiers land inside `skills/qa-browser/SKILL.md`, with Step 9 as the extension point. Step 9 is rewritten from a 20-line stub into the flow engine; Steps 1–8 are migrated to CLI and gain oracle stamps.

**Consequences.**
- `qa-browser` grows from 370 lines to an estimated 600–700. That is the cost, and it is why the extraction trigger is recorded rather than hand-waved.
- Orchestrator routing, engram topic keys, registry entries, and the issue-format variant set are all unchanged. The only new routing rule is the preflight precondition.
- Passive inspection (Steps 1–8: console, network, a11y, responsive, CWV) and active flow execution (Step 9) coexist in one file, separated by tier rather than by file: passive checks are overwhelmingly L4/advisory; flow execution is L1–L3 and authoritative. The oracle contract does the separation-of-concerns work that a file split was reaching for.

**Extraction trigger (committed).** Extract `qa-flow` when **any** holds: (1) `skills/qa-browser/SKILL.md` exceeds ~600 lines; (2) flow execution must be invocable independently of runtime health inspection; (3) deferred API/DB verification lands and needs an oracle-bearing host that is not browser-shaped.

**Rejected — new `qa-flow` skill.** Conceptually cleaner, and mixing passive inspection with active execution in one file is a real smell. Rejected **for this slice only**, on sequencing grounds: a new skill means new routing rules, a new registry entry, a new issue-format variant, new engram topic keys, and a second orchestrator command surface, all landing simultaneously with a backend migration and a veto change.

**Rejected — split and rename.** Breaking change to orchestrator commands and engram topic keys for clarity the extraction trigger already buys later at lower cost.

### ADR-C — L3 schema-first, pattern-inferred fallback, citation-gated

**Context.** L3 (code contract) is the tier that makes QASE universal — it is the only strong tier available on a project with no `openspec/` directory and no test suite. Its credibility is the whole change: a model that can self-declare `L3-schema` to reach BLOCKER restores the confident-opinion failure mode in new clothes.

**Decision.** Schema extraction (OpenAPI/Swagger, JSON Schema, Zod, Pydantic, class-validator, Prisma, GraphQL SDL) is primary and yields `L3-schema`. Static pattern extraction (validation regexes, error-message literals, redirect targets, guard clauses) is fallback and yields `L3-inferred`, capped at WARNING. Three tightenings are mechanical, not advisory:

1. **Citation mandatory for `L3-schema`** — `path:line` plus the literal contract text, verbatim. Missing any component → automatic downgrade to `L3-inferred` → cannot BLOCK.
2. **Corroboration mandatory for `L3-inferred`** — at least two independent signals, each with its own `path:line` and literal. Fewer than two → downgrade to L4.
3. **Absence stated, never implied** — when resolution lands below `L3-schema`, the evidence row carries an `Oracle Absence` note naming which higher tiers were consulted and why each was unavailable.

**Consequences.**
- Tier is a checkable claim. A reviewer can open `src/schemas/auth.ts:14` and confirm the literal. This is the single mechanism preventing tier inflation, and it is what makes ADR-A safe.
- Downgrades are transitive and re-validated at the new tier (a demoted `L3-schema` must still satisfy the `L3-inferred` corroboration rule, or it drops again to L4).
- On schema-less projects L3 degrades loudly rather than silently, so a weak oracle is never mistaken for a strong one.

**Rejected — live endpoint probing as an L3 source.** Ground truth and always current. Rejected because it needs the app running for oracle *construction* (not just verification), has side effects on POST, is blocked by auth, and overlaps the deferred API/endpoint testing scope. Deferred, not discarded.

**Rejected — pattern extraction as primary.** Works on every codebase, which is seductive given the universality constraint. Rejected because its false-positive profile (dead code, feature flags, i18n-keyed messages) is exactly what erodes trust, and trust is what this change is buying back.

**Rejected — capping `L3-inferred` at INFO from the start.** Would make pattern extraction nearly worthless in the first slice. WARNING is the right initial setting, and the rollback plan already names the INFO cap as the tightening lever if L3 proves noisy.

### ADR-D — Unique test identities, opt-in writes, visible ledger

**Context.** ADR-A makes this load-bearing rather than housekeeping. A signup flow that creates `qa@example.com` passes on run 1 and reports "email already exists" on run 2. Under ADR-A that false BLOCKER now carries veto weight.

**Decision.** Unique generated identities are **mandatory** for any write flow. Named sessions isolate client state. Teardown runs only when `qa-init` detected a cleanup hook. Write flows are opt-in per flow, refused on production, and every created record is listed in a Test Data Ledger.

**Consequences.**
- Run 2 of a write flow produces the same verdict as run 1 — proposal success criterion 14.
- Test data accumulates in the target application. This is a documented, inspectable limitation, not an invisible one; the Ledger is the record a human uses to clean up manually. Reverting QASE does not remove those records.
- `qa-browser` never discovers a signup form and decides to exercise it. This extends the existing safety rules at `skills/qa-browser/SKILL.md:350-358`.

**Rejected — session isolation alone.** The tidy answer, and wrong: `--session` isolates cookies, storage, and tabs — the browser, not the database. Presenting it as the dirty-state solution would create exactly the silent false-positive class this decision exists to prevent. The contract must say so plainly.

**Rejected — mandatory teardown.** Would make write-flow verification impossible on the majority of projects, which expose no cleanup endpoint. The universality constraint that forces L3 applies here too.

### ADR-E — Preflight is a cache with a single writer (supporting decision)

**Decision.** `qa-init` is the only writer of the preflight cache. `qa-browser` and `qa-visual` read it and refuse when `runtime_available: false`; they do not re-probe.

**Rationale.** Three specialists independently probing produces three answers and three failure messages for one condition. A single writer means one truth and one install instruction. The cache carries `probed_at` and a TTL so a stale `false` does not permanently disable runtime QA after the user installs the missing piece.

**Rejected — probe on every runtime invocation.** Correct but slow (`doctor` runs a live headless launch test), and it re-answers a question that has not changed. Rejected in favour of TTL-bounded caching with an explicit re-probe path.

### ADR-F — Command allowlist with an explicit quarantine (supporting decision)

**Decision.** Only commands appearing verbatim in `agent-browser-command-reference.md` may be written into a skill file by the apply phase. Commands this change needs that are **absent** from that reference go on a quarantine list and MUST be verified with `agent-browser <cmd> --help` before use, with a verified fallback designed for each.

**Rationale.** Three command errors have already been caught in this change (`wait networkidle`, global-flag ordering, a wrong "cookies get is invalid" correction). Risk R7's standing lesson is that the version-matched core guide is not exhaustive — `diff` is absent from it yet present in the CLI. The reverse is also true of the captured reference: it is a snapshot of specific `--help` invocations, and its `vitals` section actually contains top-level help. An allowlist plus a named quarantine converts "be careful" into a checkable rule. See *Command Correctness Discipline*.

---

## Data Flow

### Sequence Diagram 1: Runtime Preflight (`qa-init`)

Inserted as a new **Step 4: Runtime Preflight (Browser Backend)** between the current Step 3 (`skills/qa-init/SKILL.md:77-110`) and the current Step 4 Return Summary (`skills/qa-init/SKILL.md:112`), which renumbers to Step 5.

```
Orchestrator        qa-init SKILL            Bash / shell            agent-browser CLI
     |                   |                        |                        |
     |  launch (project, |                        |                        |
     |  artifact_store)  |                        |                        |
     |------------------>|                        |                        |
     |                   | Steps 1-3 (stack,      |                        |
     |                   | bootstrap, config)     |                        |
     |                   |                        |                        |
     |                   | ===== STEP 4: RUNTIME PREFLIGHT =====           |
     |                   |                        |                        |
     |                   | P0. Bash available?    |                        |
     |                   |   Is a Bash tool in my |                        |
     |                   |   tool set at all?     |                        |
     |                   |------ NO ------------->|  (cannot even attempt) |
     |                   |   bash_available:false |                        |
     |                   |   runtime_available:false                       |
     |                   |   reason: "executor has no Bash tool;           |
     |                   |            agent-browser is CLI-only"           |
     |                   |   ==> jump to P6 (persist), skip P1-P5          |
     |                   |                        |                        |
     |                   |------ YES ------------>|                        |
     |                   |   printf 'qase-bash-ok\n'                       |
     |                   |<--- "qase-bash-ok" ----|                        |
     |                   |   bash_available: true |                        |
     |                   |                        |                        |
     |                   | P1. Presence probe     |                        |
     |                   |   command -v agent-browser                      |
     |                   |----------------------->|                        |
     |                   |<-- path | exit 1 ------|                        |
     |                   |                        |                        |
     |                   |   BRANCH: not found                             |
     |                   |     agent_browser.available: false              |
     |                   |     runtime_available: false                    |
     |                   |     reason: "agent-browser not installed"       |
     |                   |     surface install hint (NEVER execute):       |
     |                   |       npm i -g agent-browser                    |
     |                   |       agent-browser install                     |
     |                   |       (Linux may need: install --with-deps)     |
     |                   |     ==> jump to P6                              |
     |                   |                        |                        |
     |                   | P2. Health check       |                        |
     |                   |   agent-browser doctor --json                   |
     |                   |----------------------->|----------------------->|
     |                   |                        |  env, Chrome install,  |
     |                   |                        |  daemon state, config, |
     |                   |                        |  key, providers,       |
     |                   |                        |  network, live launch  |
     |                   |<-- JSON + exit 0|1 ----|<-----------------------|
     |                   |   record: exit_code, failed_checks[], version   |
     |                   |   mechanism: "doctor"                           |
     |                   |                        |                        |
     |                   |   BRANCH: doctor absent / JSON unparseable      |
     |                   |     P2b. FALLBACK Chrome probing (diagnostic    |
     |                   |          only — never the final authority)      |
     |                   |       command -v chromium                       |
     |                   |       command -v google-chrome-stable           |
     |                   |       command -v google-chrome   <-- ABSENT on  |
     |                   |                        the reference machine    |
     |                   |       command -v chrome                         |
     |                   |     stop at first hit; record name + mechanism: |
     |                   |       "probe-fallback"                          |
     |                   |     NEVER probe a single name — that yields a   |
     |                   |     false negative on working environments      |
     |                   |                        |                        |
     |                   |   NOTE: exit 1 does NOT end the preflight.      |
     |                   |   The smoke test is the final authority.        |
     |                   |                        |                        |
     |                   | P3. Smoke connection   |                        |
     |                   |   S=$(agent-browser session id \                |
     |                   |        --scope worktree --prefix qase)          |
     |                   |----------------------->|----------------------->|
     |                   |<-- session id ---------|<-----------------------|
     |                   |                        |                        |
     |                   |   agent-browser --session "$S" open             |
     |                   |     (no URL: launches, stays on about:blank)    |
     |                   |----------------------->|----------------------->|
     |                   |                        |   [launch Chrome,      |
     |                   |                        |    start daemon]       |
     |                   |<-- exit code ----------|<-----------------------|
     |                   |                        |                        |
     |                   |   agent-browser --session "$S" get url --json   |
     |                   |----------------------->|----------------------->|
     |                   |<-- {"url":"about:blank"} ----------------------|
     |                   |                        |                        |
     |                   |   agent-browser --session "$S" close            |
     |                   |----------------------->|----------------------->|
     |                   |   (NEVER `close --all` — would kill other       |
     |                   |    agents' concurrent sessions)                 |
     |                   |                        |                        |
     |                   |   BRANCH: smoke FAILED                          |
     |                   |     smoke_test: failed                          |
     |                   |     runtime_available: false                    |
     |                   |     reason: "doctor {passed|failed}; smoke      |
     |                   |              connection failed: {stderr}"       |
     |                   |     <-- this is the installed-but-broken case   |
     |                   |         the preflight exists to make loud       |
     |                   |                        |                        |
     |                   | P4. Start-command hints (SUGGEST, NEVER RUN)    |
     |                   |   read package.json scripts.dev|start|serve     |
     |                   |   read Makefile run|serve|dev targets           |
     |                   |   read Procfile web:                            |
     |                   |   read docker-compose.yml services.*.ports      |
     |                   |   read README "Getting Started"                 |
     |                   |   read .env.example PORT=                       |
     |                   |   ==> detected_start_hints[]                    |
     |                   |                        |                        |
     |                   | P5. Cleanup-hook detection (opportunistic)      |
     |                   |   look for a test-reset endpoint or script      |
     |                   |   ==> detected_cleanup_hook | null              |
     |                   |   QASE never invents cleanup, never runs        |
     |                   |   migrations, never truncates tables            |
     |                   |                        |                        |
     |                   | P6. Persist cache      |                        |
     |                   |   openspec -> qaspec/preflight-cache.yaml       |
     |                   |   engram   -> topic_key                         |
     |                   |              qa-init/{project}/preflight        |
     |                   |   none     -> return inline, warn not persisted |
     |                   |                        |                        |
     |  <-- summary +    |                        |                        |
     |  Runtime Backend  |                        |                        |
     |      section -----|                        |                        |
```

#### Preflight outcome truth table

Every branch records a **specific** reason. "Runtime unavailable" with no reason is a defect.

| bash | agent-browser | `doctor` exit | smoke | `runtime_available` | recorded `reason` |
|---|---|---|---|---|---|
| false | — | — | skipped | `false` | executor has no Bash tool; agent-browser is CLI-only |
| true | absent | — | skipped | `false` | agent-browser not installed (install hint surfaced, not executed) |
| true | present | 0 | passed | `true` | `null` |
| true | present | 0 | **failed** | `false` | doctor passed but smoke connection failed: `{stderr}` |
| true | present | 1 | passed | `true` | doctor reported failed checks `[...]`; smoke succeeded — degraded confidence |
| true | present | 1 | failed | `false` | doctor failed `[...]`; smoke connection failed: `{stderr}` |
| true | present | unparseable | passed | `true` | doctor output unparseable; Chrome resolved by probe-fallback (`{name}`); smoke succeeded |
| true | present | unparseable | failed | `false` | doctor output unparseable; probe-fallback found `{name|nothing}`; smoke failed: `{stderr}` |

#### Preflight cache schema

Lives in `persistence-contract.md`. Consumed by `qa-browser` and `qa-visual` as a precondition.

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
    failed_checks: []            # names from doctor --json when exit_code is 1
  chrome_binary:
    available: true | false
    name: "chromium" | "google-chrome-stable" | "google-chrome" | "chrome" | null
    detection: "doctor" | "probe-fallback" | null
  smoke_test: passed | failed | skipped
  runtime_available: true | false
  reason: null | "specific human-readable cause"
  mechanism: "doctor" | "probe-fallback" | "none"
  probed_at: "ISO-8601"
  ttl_hours: 24
detected_start_hints:
  - command: "npm run dev"
    source: "package.json scripts.dev"
    likely_port: 3000
detected_cleanup_hook: null | { kind: "endpoint" | "command", value: "..." }
```

**Freshness rule.** A cache entry older than `ttl_hours` is treated as absent; the runtime specialist reports `runtime_available: unknown — preflight cache stale, re-run /qa-init` and refuses rather than guessing. A cached `false` never permanently disables runtime QA.

**Refusal rule (proposal success criterion 17).** When `runtime_available` is not `true`, `qa-browser` and `qa-visual` return `status: skipped` with `verdict_contribution: CLEAN`, a single INFO finding stating the cached reason, and **zero** runtime findings. Fabricating findings from static reading is the exact regression this change exists to prevent.

---

### Sequence Diagram 2: Flow Execution Loop (`qa-browser` Step 9)

`skills/qa-browser/SKILL.md:244` (`### Step 9: User Flow Testing`) is the extension point. The current stub becomes the engine below. `$S` is the session id; `$RUN` is the run token (see *State and Session Management*).

```
Orchestrator     qa-browser SKILL        Oracle sources         agent-browser CLI (via Bash)
     |                  |                      |                          |
     | flows[], url,    |                      |                          |
     | depth, mode      |                      |                          |
     |----------------->|                      |                          |
     |                  | F0. PRECONDITION     |                          |
     |                  |   read preflight cache (B1)                     |
     |                  |   runtime_available != true -> SKIP whole skill |
     |                  |                      |                          |
     |                  | F1. ORACLE SOURCING (once per flow, before any  |
     |                  |     browser action — never mid-step)            |
     |                  |   L1: glob openspec/changes/*/specs/**/*.md     |
     |                  |------------------------->|                      |
     |                  |   L2: test command from qa-init? EXECUTE it and |
     |                  |       read the output (not "tests exist")       |
     |                  |------------------------->|                      |
     |                  |   L3: schema scan, then pattern scan            |
     |                  |------------------------->|                      |
     |                  |   L4: always available                          |
     |                  |<-- candidate oracle set -|                      |
     |                  |                      |                          |
     |                  | F2. SESSION + RUN SETUP                         |
     |                  |   S=$(agent-browser session id \                |
     |                  |        --scope worktree --prefix qase)          |
     |                  |   RUN={epoch}-{6 hex}                           |
     |                  |   write flow evidence header + Test Data Ledger |
     |                  |                      |                          |
     |                  | F3. FLOW OPEN        |                          |
     |                  |   agent-browser --session "$S" open <url>       |
     |                  |------------------------------------------------>|
     |                  |   agent-browser --session "$S" wait --load networkidle
     |                  |------------------------------------------------>|
     |                  |   [depth=deep or explicit request only]         |
     |                  |   agent-browser --session "$S" network har start|
     |                  |------------------------------------------------>|
     |                  |   agent-browser --session "$S" \                |
     |                  |     record start ./<evid>/recordings/<slug>.webm|
     |                  |------------------------------------------------>|
     |                  |                      |                          |
     |  ======================= PER-STEP LOOP (step N) ==================  |
     |                  |                      |                          |
     |                  | S1. CLEAR BUFFERS (every step owns its own      |
     |                  |     diagnostics — this is what makes per-step   |
     |                  |     attribution honest)                         |
     |                  |   agent-browser --session "$S" console --clear  |
     |                  |------------------------------------------------>|
     |                  |   agent-browser --session "$S" errors --clear   |
     |                  |------------------------------------------------>|
     |                  |   agent-browser --session "$S" network requests --clear
     |                  |------------------------------------------------>|
     |                  |                      |                          |
     |                  | S2. [OPTIONAL] FAULT INJECTION                  |
     |                  |     only when the step declares one             |
     |                  |   agent-browser --session "$S" \                |
     |                  |     network route "**/api/login" --abort       |
     |                  |------------------------------------------------>|
     |                  |   (or --body '{"error":"boom"}' to mock)        |
     |                  |                      |                          |
     |                  | S3. ACT              |                          |
     |                  |   agent-browser --session "$S" snapshot -i      |
     |                  |------------------------------------------------>|
     |                  |   then ONE of:                                  |
     |                  |     find role button click --name "Sign In"     |
     |                  |     click "@e7" | click "#submit"               |
     |                  |     fill "#email" "qase+$RUN@example.com"       |
     |                  |     press "Enter"                               |
     |                  |------------------------------------------------>|
     |                  |                      |                          |
     |                  | S4. SETTLE (pick the narrowest that applies)    |
     |                  |   wait --url "**/dashboard"                     |
     |                  |   wait --text "Welcome back"                    |
     |                  |   wait "#result" | wait --load networkidle      |
     |                  |   wait --fn "!document.body.innerText           |
     |                  |              .includes('Loading...')"           |
     |                  |------------------------------------------------>|
     |                  |                      |                          |
     |                  | S5. OBSERVE          |                          |
     |                  |   get url | get title | get text "<sel>"        |
     |                  |   is visible "<sel>" | snapshot -i              |
     |                  |------------------------------------------------>|
     |                  |<-- observed state ------------------------------|
     |                  |                      |                          |
     |                  | S6. HARVEST PER-STEP DIAGNOSTICS                |
     |                  |   console --json     -> console/step-NN.json    |
     |                  |   errors  --json     -> errors/step-NN.json     |
     |                  |   network requests --json                       |
     |                  |                      -> network/step-NN.json    |
     |                  |   network request <id>  (only for status >= 400)|
     |                  |------------------------------------------------>|
     |                  |                      |                          |
     |                  | S7. CAPTURE ARTIFACT (every step, always)       |
     |                  |   screenshot ./<evid>/screenshots/step-NN.png   |
     |                  |   (--full at deep; --annotate when the finding  |
     |                  |    points at an element)                        |
     |                  |------------------------------------------------>|
     |                  |                      |                          |
     |                  | S8. RESOLVE EXPECTATION                         |
     |                  |   L1 -> L2 -> L3-schema -> L3-inferred -> L4    |
     |                  |------------------------->|                      |
     |                  |   validate the tier claim (citation /           |
     |                  |   corroboration); downgrade if it fails         |
     |                  |<-- tier + citation + absence note --------------|
     |                  |                      |                          |
     |                  | S9. CLASSIFY                                    |
     |                  |   PASS | FAIL | INCONCLUSIVE | SKIPPED          |
     |                  |   severity capped by tier (see gate)            |
     |                  |                      |                          |
     |                  | S10. TEARDOWN OF STEP SCOPE (mandatory, runs    |
     |                  |      even when the step FAILED or was           |
     |                  |      INCONCLUSIVE)                              |
     |                  |   if a route was installed in S2:               |
     |                  |     agent-browser --session "$S" \              |
     |                  |       network unroute "**/api/login"           |
     |                  |------------------------------------------------>|
     |                  |   unroute FAILS -> abort the flow. Later steps  |
     |                  |   would run against a contaminated network      |
     |                  |   layer and their evidence would be a lie.      |
     |                  |                      |                          |
     |                  | S11. EMIT EVIDENCE ROW -> flow evidence doc     |
     |                  |                      |                          |
     |  --------- DAEMON RECONNECTION BRANCH (any of S1-S7) ------------  |
     |                  |   command exits non-zero with a connection /    |
     |                  |   daemon / socket error                         |
     |                  |   agent-browser --session "$S" session info --json
     |                  |------------------------------------------------>|
     |                  |<-- daemon + launch + restore diagnostics -------|
     |                  |   daemon dead ->                                |
     |                  |     agent-browser --session "$S" open <url>     |
     |                  |     re-establish auth state (see State section) |
     |                  |     RETRY the current step ONCE                 |
     |                  |   retry succeeds -> continue, annotate the row  |
     |                  |     "backend reconnected mid-step"              |
     |                  |   retry fails    -> step = INCONCLUSIVE,        |
     |                  |     abort flow, status PARTIAL, flow-level      |
     |                  |     WARNING "runtime backend lost"              |
     |                  |   INVARIANT: a lost daemon is NEVER reported as |
     |                  |   an application defect and NEVER produces FAIL |
     |  ================= END PER-STEP LOOP =========================     |
     |                  |                      |                          |
     |                  | F4. FLOW TEARDOWN                               |
     |                  |   agent-browser --session "$S" network unroute  |
     |                  |     (belt-and-braces: removes ALL routes)       |
     |                  |   record stop                                   |
     |                  |   network har stop ./<evid>/har/<slug>.har      |
     |                  |   invoke detected_cleanup_hook IF recorded      |
     |                  |     by qa-init — otherwise do nothing           |
     |                  |------------------------------------------------>|
     |                  |   (do NOT `close` — later flows reuse the       |
     |                  |    session; close once after the last flow)     |
     |                  |                      |                          |
     |                  | F5. FLOW SUMMARY + Test Data Ledger + persist   |
     |  <-- envelope ---|                      |                          |
```

**Buffer-clearing note.** `network requests --clear` clears the captured request log; `network unroute` removes installed routes. They are different operations on different state and neither substitutes for the other. Clearing the log does not remove a route, and a leftover route silently poisons every subsequent step.

**Forced-failure scope rule.** A fault injection installed in S2 is scoped to exactly one step and removed in S10 of that same step. The flow-level `network unroute` in F4 is a safety net, not the primary mechanism.

---

## Oracle Resolution Algorithm

Deterministic, per step, evaluated after the observation is captured (S8). Two runs of the same flow against the same repo state MUST select the same tier.

```
INPUT:  step (action, intent), observed state, candidate oracle set from F1
OUTPUT: (tier, expectation, citation[], absence_note?) — always populated

1. CANDIDATE FILTER — a tier is a candidate only if it yields a STEP-SPECIFIC
   expectation. "The source exists" is not sufficient; the source must state an
   expected outcome for this exact action or path.

2. STRICT DESCENDING WALK — try tiers in this fixed order, first match wins:
      L1  -> L2  -> L3-schema  -> L3-inferred  -> L4
   No tier may be skipped and none may be tried out of order. If a tier yields
   no step-specific expectation, record why (feeds step 6) and continue.

3. TIE-BREAK WITHIN A TIER (determinism requirement):
      a. most specific match first (exact route/path > prefix > glob)
      b. then shortest file path
      c. then lexicographic file path
   Stated so two runs cannot disagree.

4. CLAIM VALIDATION — applied to the selected tier:

   | Tier         | Required to hold the claim                                        |
   |--------------|-------------------------------------------------------------------|
   | L1           | spec file path + scenario/heading title quoted verbatim           |
   | L2           | test command EXECUTED in this review + test name + the observed   |
   |              | runner output line                                                |
   | L3-schema    | path:line + the literal contract text, verbatim                   |
   | L3-inferred  | >= 2 independent signals, each with its own path:line + literal   |
   | L4           | a NAMED standard (WCAG SC id, RFC section, Web Vitals metric      |
   |              | name + threshold, Nielsen heuristic number)                       |

5. DOWNGRADE — transitive and re-validated:
      L1 without citation        -> L2 (re-enter step 4)
      L2 without executed output -> L3-schema (re-enter step 4)
      L3-schema without citation -> L3-inferred (re-enter step 4)
      L3-inferred with < 2 signals -> L4 (re-enter step 4)
      L4 without a named standard  -> UNGROUNDED
   A downgraded finding NEVER retains the higher tier's blocking power.

6. ABSENCE DECLARATION — mandatory whenever the result is below L3-schema.
   The evidence row carries an `Oracle Absence` note naming each higher tier
   consulted and why it was unavailable, e.g.:
      "L1 unavailable: no openspec/ directory"
      "L2 unavailable: qa-init recorded no test command"
      "L3-schema unavailable: no schema file declares this field"
   Silent degradation is how a weak oracle gets mistaken for a strong one.

7. UNGROUNDED — every tier exhausted:
      status  = INCONCLUSIVE (never FAIL)
      severity= INFO ceiling (never WARNING, never BLOCKER)
      row text= "no oracle available for this step: {consulted tiers and why}"
   The step is still recorded with action, observed, and artifact. An
   unverifiable step is reported as unverifiable, not as a pass and not as a
   defect.
```

### `L3-schema` vs `L3-inferred` — the concrete discriminator

| | `L3-schema` | `L3-inferred` |
|---|---|---|
| **Source kinds** | OpenAPI/Swagger, JSON Schema, Zod, Pydantic, class-validator, Prisma schema, GraphQL SDL | handler validation regexes, error-message string literals, redirect targets, guard clauses in components/handlers |
| **Citation** | **mandatory**: `path:line` + verbatim literal | **mandatory**: `path:line` + verbatim literal, **for each of >= 2 signals** |
| **Corroboration** | not required — the schema is the contract | required: two *independent* signals on the same path (e.g. a validation regex **and** a matching error-message literal) |
| **Example** | `src/schemas/auth.ts:14` — `z.string().email({ message: "Invalid email address" })` | `src/routes/auth.ts:41` — `if (!/^[^@]+@[^@]+$/.test(email))` **plus** `src/routes/auth.ts:42` — `return res.status(400).json({ error: "Invalid email address" })` |
| **Max severity** | BLOCKER | WARNING |
| **Veto-bearing** | yes | **no** |

Two signals from the same expression (a regex and its own inline message on one line) are **one** signal, not two. Independence means separately locatable evidence.

### Step status classification

| Status | When | Max severity | Notes |
|---|---|---|---|
| `PASS` | observed satisfies the resolved expectation | — | still records an artifact |
| `FAIL` | observed contradicts the resolved expectation | tier-capped (see gate) | the only status that can BLOCK |
| `INCONCLUSIVE` | action could not be performed, daemon lost, observation ambiguous, or oracle UNGROUNDED | INFO | never a defect claim |
| `SKIPPED` | refused by policy — production write flow, destructive element, missing credentials | INFO | reason mandatory; never silently omitted |

Flow-level rule: if more than half the steps are `INCONCLUSIVE`, the flow returns `status: partial` with a flow-level WARNING. A flow that mostly could not be verified must not read as a flow that mostly passed.

---

## Contract Threading Map — exact insertion points

Line numbers are against the files as they exist at the time of this design.

### 1. NEW — `skills/_shared/qase/oracle-contract.md`

Single source of truth for tier semantics (boundary B3). Required sections:

| Section | Contents |
|---|---|
| `## Purpose` | why expectations need a stated source |
| `## The Four Tiers` | table: tier, source, available-when, citation requirement, max severity, veto-bearing |
| `## Tier Population` | how each tier is gathered (L1 glob, L2 executed runner, L3 schema then pattern, L4 named standards) |
| `## Citation Requirements` | the ADR-C rules, verbatim and mechanical |
| `## Resolution Algorithm` | the 7-step walk above |
| `## Degradation and Absence` | downgrade table + the mandatory absence note |
| `## Blocking Matrix` | tier x severity ceiling x veto-bearing |
| `## Anti-Inflation Rules` | uncited `L3-schema` auto-downgrades; single-signal `L3-inferred` auto-downgrades; UNGROUNDED never FAILs |

No `agent-browser` command appears in this file (boundary B2).

### 2. `skills/_shared/qase/severity-contract.md`

| Insertion point | Change |
|---|---|
| after the severity table (line 11), before `## Veto Power` (line 13) | NEW `## Oracle Tier and Verdict` — references `oracle-contract.md`; states the ceilings: **L4 never produces BLOCKER**; **`L3-inferred` caps at WARNING**; L1/L2/`L3-schema` may produce BLOCKER; a runtime finding with no Oracle Tier field is treated as UNGROUNDED and capped at INFO |
| line 15 | "Two specialists have **veto power**" -> "**Three** specialists have **veto power** — one of them conditionally" |
| veto table (lines 17-20) | add row: `qa-browser` \| *BLOCKERs carrying Oracle Tier L1, L2, or L3-schema only. Findings at L3-inferred or L4 never carry veto and never produce BLOCKER.* |
| line 22 | extend the non-veto sentence to name `qa-visual` explicitly, and to state that `qa-browser` findings outside the tier gate are non-veto |
| verdict logic block (lines 26-39) | insert the tier gate **before** the veto branch (pseudocode below) |
| `## Severity Assignment Guidelines` (line 41) | NEW `### Runtime findings` subsection restating the ceilings so an author reading only this section cannot inflate |

### 3. `skills/_shared/qase/issue-format.md`

| Insertion point | Change |
|---|---|
| Browser Testing Variant, after `**Category**:` (line 59) | add `**Oracle Tier**: L1 \| L2 \| L3-schema \| L3-inferred \| L4` |
| Browser Testing Variant, after `#### Evidence` (line 70-71) | add required `#### Oracle Citation` — `path:line` + verbatim literal, or the `Oracle Absence` note |
| "Key differences" bullets (lines 77-81) | add a bullet for the Oracle Tier field and the citation requirement |
| Visual Testing Variant, after `**Category**:` (line 94) | add the same `**Oracle Tier**` line |
| Visual Testing Variant, after `#### Evidence` (line 105-106) | add the same `#### Oracle Citation` |
| "Key differences" bullets (lines 112-115) | note that `qa-visual` findings are predominantly L4 and therefore advisory |
| after the Visual Testing Variant (before `## Grouping`, line 117) | NEW `## Flow Evidence Format` — the per-step table (Action / Observed / Expected / Oracle Tier / Status / Artifact), the header block, the Flow Summary table, and the **Test Data Ledger** |
| Metadata Envelope (lines 152-164) | add `- **oracle-tier-breakdown**: L1={n} L2={n} L3-schema={n} L3-inferred={n} L4={n}`, `- **flow-evidence**: {path \| topic_key \| none}`, `- **runtime-available**: true \| false` |

### 4. `skills/_shared/qase/persistence-contract.md`

| Insertion point | Change |
|---|---|
| after `## Behavior Per Mode` table (line 48), before `## Common Rules` (line 50) | NEW `## Runtime Preflight Cache` — the schema above, single-writer rule (`qa-init` only), TTL/freshness rule, and the runtime-specialist refusal rule |
| `## Common Rules` (lines 50-56) | add: binary artifacts (screenshots, `.webm`, `.har`) are **never** stored in engram; in `engram` and `none` modes they are written to a run-scoped temp dir outside the repo and referenced by absolute path with an explicit *ephemeral* marker — this satisfies "engram mode writes no project files" |

### 5. `skills/_shared/qase/engram-convention.md`

| Insertion point | Change |
|---|---|
| after `### Review Artifacts` block (line 15) | NEW `### Flow Evidence (per-flow)` naming block: `qase/{review-id}/flow-evidence/{flow-slug}` |
| `### Project Init` block (lines 19-25) | add the preflight key `qa-init/{project-name}/preflight` as a project-scoped, long-lived artifact |
| Artifact Types table (lines 39-52) | add rows `flow-evidence` (qa-browser — per-flow step-by-step executed evidence) and `preflight-cache` (qa-init — runtime backend capability cache) |
| after the Artifact Types table | NEW note: engram stores markdown only; artifact **paths** are recorded, artifact **bytes** are not |

### 6. `skills/_shared/qase/openspec-convention.md`

| Insertion point | Change |
|---|---|
| Directory Structure (lines 5-25) | add `qaspec/preflight-cache.yaml`, `qaspec/baselines/`, and the `reviews/{review-id}/flow-evidence/` subtree (layout below) |
| Artifact File Paths table (lines 30-42) | qa-init also creates `qaspec/preflight-cache.yaml`; qa-browser also creates `qaspec/reviews/{review-id}/flow-evidence/{flow-slug}.md` + its artifact subtree; qa-visual also creates `qaspec/reviews/{review-id}/visual-diffs/` and reads/writes `qaspec/baselines/` |
| Writing Rules (lines 64-69) | add: visual **baselines persist across reviews** and MUST live at `qaspec/baselines/`, never inside a `reviews/{review-id}/` directory — same rule and same reason as feedback files (a baseline inside a review folder cannot be diffed against by the next review) |

### 7. `skills/_shared/qase/routing-rules.md`

| Insertion point | Change |
|---|---|
| Out-of-Band Specialists table (lines 98-101) | rewrite both rows: drop "Chrome DevTools", name the agent-browser CLI; add columns **Oracle Tiers** (`qa-browser`: L1-L4; `qa-visual`: predominantly L4) and **Veto** (`qa-browser`: tier-gated; `qa-visual`: none) |
| bullets at lines 103-107 | add: out-of-band runtime specialists require `runtime_available: true` in the preflight cache; when it is absent, stale, or false they return `skipped` with the cached reason and produce **zero** runtime findings |
| after those bullets | NEW `## Oracle-Tier-Aware Routing` — a runtime specialist's findings enter consensus with their tier attached; `qa-report` sorts and gates on tier, not on agent name alone |

### 8. Skill files (targets, not shared contracts)

| File | Insertion point | Change |
|---|---|---|
| `skills/qa-browser/SKILL.md` | frontmatter line 12 | `veto_power: false` -> `true` |
| | description lines 3-6 | drop "via Chrome DevTools MCP"; name agent-browser CLI |
| | `## Execution and Persistence Contract` (lines 31-39) | add a line referencing `oracle-contract.md`; add `flow-evidence` artifact type |
| | Step 1 (lines 43-59) | becomes **Establish Runtime Backend** — read preflight cache, resolve `$S`, `open`, `wait --load networkidle`, `snapshot`, `screenshot`, `console`, `network requests` |
| | Steps 2-8 (lines 61-242) | MCP tool names -> CLI commands; every finding gains an Oracle Tier (mostly L4); Step 8 CWV via `vitals` (quarantined — see below) |
| | **Step 9 (line 244)** | **primary extension point** — the stub becomes the flow engine of Sequence Diagram 2 |
| | Safety Rules (lines 350-358) | add: production write flows refused; write flows opt-in per flow; unique identities mandatory; never `close --all` |
| `skills/qa-visual/SKILL.md` | Step 1 (lines 47-61) | the MCP-tool-availability gate becomes the **preflight-cache** gate |
| | Step 6 (line 282) | `resize_page` -> `set viewport <w> <h>` |
| | Step 8 (line 411) | `emulate` -> `set media light reduced-motion` / `set media dark` |
| | new step before reporting | baseline regression via `diff screenshot --baseline` |
| | findings | Oracle Tier on every finding; `veto_power: false` unchanged |
| `skills/qa-init/SKILL.md` | between line 110 and line 112 | NEW **Step 4: Runtime Preflight (Browser Backend)**; current Step 4 renumbers to Step 5 |
| | all three return blocks (lines 116-182) | add a `### Runtime Backend` section reporting `runtime_available`, reason, mechanism, and start-command hints |
| `skills/qa-report/SKILL.md` | Step 3 (lines 69-90), Step 4 sort (lines 96-104), metadata (lines 209-220) | tier-gated veto — see below |

---

## Veto Gate Design (and the R11 resolution)

### The sync invariant

Tier-gated veto is stated in **four** places. All four must agree or the framework misrepresents its own authority.

| # | Location | What it must say | Mechanical check |
|---|---|---|---|
| V1 | `skills/qa-browser/SKILL.md` frontmatter | `veto_power: true` | `rg -n "veto_power: true" skills/` returns exactly 3 (`qa-security`, `qa-architect`, `qa-browser`) |
| V2 | `severity-contract.md` veto table | a `qa-browser` row whose Veto Scope names L1, L2, L3-schema and excludes L3-inferred and L4 | the row exists and its scope text contains all five tier tokens with the exclusion clause |
| V3 | `severity-contract.md` verdict logic | the tier gate precedes the veto branch | the pseudocode block contains the tier check |
| V4 | `qa-report/SKILL.md` Step 3 | the same three agents and the same tier predicate | Step 3 pseudocode names three agents, not two |

V1 and V2 MUST land in the same commit (proposal Decision A). `sdd-verify` checks all four.

### Verdict logic after the change

```
FOR EACH finding:
  # Gate 1 — severity ceiling by tier (authoring-time rule, re-enforced here)
  IF finding.agent IN {qa-browser, qa-visual}:
      IF finding.oracle_tier IS MISSING        -> treat as UNGROUNDED, cap at INFO
      IF finding.oracle_tier == L4             -> cap at WARNING
      IF finding.oracle_tier == L3-inferred    -> cap at WARNING
      IF finding.oracle_tier == L3-schema AND citation missing
                                               -> downgrade to L3-inferred, cap at WARNING
      # a BLOCKER arriving at a capped tier is DOWNGRADED, not honoured,
      # and a `tier-gate-violation` note is recorded in the report

  # Gate 2 — veto-bearing predicate (per finding, not per agent)
  veto_bearing = finding.severity == BLOCKER AND (
        finding.agent IN {qa-security, qa-architect}
     OR (finding.agent == qa-browser AND finding.oracle_tier IN {L1, L2, L3-schema})
  )

VERDICT:
  IF any BLOCKER exists:
      base = REJECT
      IF any finding has veto_bearing == true:
          -> REJECT (VETO) — requires explicit user acknowledgment
      ELSE:
          -> REJECT — standard, overridable by consensus
  ELSE IF any WARNING exists: -> APPROVE WITH WARNINGS
  ELSE:                       -> APPROVE
```

### R11 resolved — `qa-report` consensus with a third, tier-gated veto holder

The risk register asks what happens to consensus logic that "has only ever had two veto agents". The concrete answer:

1. **There is no arity assumption to break.** `qa-report` Step 3 (`skills/qa-report/SKILL.md:69-90`) evaluates an **existential quantifier over a set** — "IF BLOCKER is from veto agent" — not a vote, quorum, or tally. Veto is a disjunction: monotone, order-independent, and idempotent. Adding a third member changes set membership, not the algorithm. There is no path in `qa-report` where two veto holders behave differently from three, and no place where the count `2` is encoded.
2. **The one genuine change is that membership becomes finding-scoped.** For `qa-security` and `qa-architect` the predicate stays `agent ∈ vetoSet`. For `qa-browser` it becomes `agent == qa-browser AND oracle_tier ∈ {L1, L2, L3-schema}`. Step 3's inline pseudocode must be edited to evaluate the finding, not just the agent name.
3. **Defense in depth, not a single check.** L4 and `L3-inferred` can never legally be BLOCKER (severity ceiling at authoring time), so a legal `qa-browser` BLOCKER is already tier-eligible by construction. Gate 2 is therefore redundant on well-formed input — deliberately. On malformed input (a BLOCKER stamped L4, or a finding with no tier at all) Gate 1 downgrades it and records `tier-gate-violation`. `qa-report` never honours an ungated BLOCKER just because the agent holds the flag.
4. **Deduplication interacts with tiers.** Step 2 merges identical findings and "uses the HIGHEST severity". Extend that: when merging findings that carry Oracle Tiers, keep the **strongest** tier among them **only if its citation survives the merge**; otherwise keep the weakest cited tier. A merge must never manufacture blocking power that neither input had.
5. **Ranking.** Step 4's "Veto agent findings first" becomes "veto-**bearing** findings first", so a `qa-browser` L1 BLOCKER sorts with the security and architect BLOCKERs while a `qa-browser` L4 WARNING does not.
6. **Reporting.** Step 5 already computes "whether veto was triggered". The metadata block (lines 209-220) adds `- **veto-tiers**: [{tier per veto finding}]` alongside `veto-agents`, and the REJECT (VETO) next-step text names the tier so a reader can see *why* the evidence was authoritative.
7. **No new verdict value.** The lattice stays `APPROVE < APPROVE WITH WARNINGS < REJECT < REJECT (VETO)`. Nothing downstream of `qa-report` needs to learn a new state.

**Deviation from the proposal, stated plainly:** the proposal's affected-modules table does not list `skills/qa-report/SKILL.md`, but `qa-report` Step 3 **duplicates** the veto pseudocode inline rather than only referencing `severity-contract.md`. Leaving a stale copy that names two agents would reproduce exactly the "the metadata is lying" failure that ADR-A rejects option (b) for. The edit is surgical — Step 3's pseudocode, one line in Step 4's sort order, two metadata lines — and `qa-report` has no `veto_power` frontmatter field, so success criterion 3's count of exactly three is unaffected.

---

## Evidence Artifact Layout

### openspec mode

```
qaspec/
├── config.yaml
├── init.yaml
├── preflight-cache.yaml                       <- NEW, written by qa-init only
├── baselines/                                 <- NEW, persists ACROSS reviews
│   └── {page-slug}/
│       ├── 1440x900.png
│       ├── 768x1024.png
│       └── 375x812.png
├── feedback/
│   └── {agent}/{pattern-slug}.md
└── reviews/
    ├── archive/
    └── {review-id}/
        ├── scan.md
        ├── browser.md                          <- qa-browser findings report
        ├── visual.md                           <- qa-visual findings report
        ├── report.md
        ├── visual-diffs/                       <- NEW, diff output (per review)
        │   └── {page-slug}-{viewport}.png
        └── flow-evidence/                      <- NEW
            ├── {flow-slug}.md                  <- the evidence document
            └── {flow-slug}/                    <- its binary artifacts
                ├── screenshots/step-01.png ... step-NN.png
                ├── console/step-01.json    ... step-NN.json
                ├── errors/step-01.json     ... step-NN.json
                ├── network/step-01.json    ... step-NN.json
                ├── har/{flow-slug}.har          (deep / on request)
                └── recordings/{flow-slug}.webm  (deep / on request)
```

Rules:
- `{flow-slug}` is a kebab-case slug of the flow name; `NN` is zero-padded, one-based, matching the evidence row numbering exactly.
- The evidence document references artifacts by **path relative to the review directory**, so the whole review folder is portable.
- **Baselines live outside `reviews/`.** A baseline stored inside `reviews/{review-id}/` is unusable by the next review — same reasoning as the existing rule that feedback never lives inside a review.
- Diff *outputs* are per-review and belong in `visual-diffs/`; diff *inputs* (baselines) are cross-review.

### engram mode

Engram stores markdown, not bytes. The split is explicit:

| Artifact | Where | Key / path |
|---|---|---|
| flow evidence document | engram | `qase/{review-id}/flow-evidence/{flow-slug}` |
| browser findings report | engram | `qase/{review-id}/browser-report` |
| visual findings report | engram | `qase/{review-id}/visual-report` |
| preflight cache | engram | `qa-init/{project}/preflight` |
| screenshots, console/errors/network dumps, HAR, recordings | **temp dir, ephemeral** | `${TMPDIR:-/tmp}/qase/{review-id}/{flow-slug}/...` (same subtree shape as openspec) |
| visual baselines | **not available** | baseline diffing requires a durable store; in engram mode `diff screenshot --baseline` is skipped and reported as a stated limitation, not silently dropped |

Every evidence row referencing a temp path carries an explicit marker:

> `(ephemeral — artifact written outside the repo and not persisted; path valid for this session only)`

This keeps the persistence contract intact (engram mode writes no project files) while refusing to pretend an artifact is durable when it is not. `--screenshot-dir` (or `AGENT_BROWSER_SCREENSHOT_DIR`) sets the destination once instead of threading a path through every call.

### none mode

Same temp-dir layout as engram; the evidence document is returned inline with the same ephemeral markers. The user is told persistence is off and what that costs.

### Volume control (risk R10)

Artifact capture is tied to the existing depth controls:

| Artifact | concise | standard | deep |
|---|---|---|---|
| per-step screenshot | yes (required — every step, always) | yes | yes, `--full` |
| per-step console/errors JSON | yes | yes | yes |
| per-step network JSON | summary counts only | yes | yes + `network request <id>` detail for status >= 400 |
| HAR | no | no | yes |
| WebM recording | no | no | yes |
| `--annotate` screenshot | no | only when a finding points at an element | yes |

The per-step screenshot is never optional: proposal success criterion 13 requires **at least one artifact path per step**.

---

## State and Session Management

### Session identity

```bash
S="$(agent-browser session id --scope worktree --prefix qase)"
```

`--scope worktree` is chosen deliberately: parallel agent runs in different worktrees get different daemons and cannot cross-contaminate, while repeated runs in the same worktree reuse the daemon and its warm state. Session names are **never** hand-built — a hand-built name is the failure mode where two concurrent reviews share a browser.

Every subsequent command carries the session as a **global flag before the subcommand**:

```bash
agent-browser --session "$S" open http://localhost:3000
```

Global-flags-before-subcommand is verified verbatim in the reference (`agent-browser --session test open example.com`). Putting `--session` after the subcommand is the second of the three command errors already caught in this change.

### Run token and unique identities (ADR-D)

```
QASE_RUN_ID = {epoch-seconds}-{6 lowercase hex}
```

Derivation table — every field is a pure function of `QASE_RUN_ID`, so any record found later in the target application is traceable back to a run:

| Field | Template | Example |
|---|---|---|
| email | `qase+{QASE_RUN_ID}@example.com` | `qase+1774915200-a3f19c@example.com` |
| display name | `QASE Test {QASE_RUN_ID}` | `QASE Test 1774915200-a3f19c` |
| password | `Qase-{QASE_RUN_ID}!` | `Qase-1774915200-a3f19c!` |
| phone | `555-0100` (reserved, non-dialable) | `555-0100` |
| org/team name | `qase-{QASE_RUN_ID}` | `qase-1774915200-a3f19c` |

"Deterministic per run" means **reproducible from the recorded token**, not predictable in advance. The token is recorded in the flow evidence header and in the Test Data Ledger; given the token, every derived value is recomputable. That is the property that matters for audit and cleanup.

The run token is deliberately **decoupled from the session id**: the session id is stable per worktree (so state and the daemon are reusable), while the run token changes every run (so write flows never collide). Conflating them would break one or the other.

### Test Data Ledger

Every flow evidence document ends with:

| Kind | Identity / value | Created at step | Cleanup |
|---|---|---|---|
| user | `qase+1774915200-a3f19c@example.com` | Step 3 | none — no cleanup hook detected |
| org | `qase-1774915200-a3f19c` | Step 5 | `POST /test/reset` (hook recorded by qa-init) |

An empty ledger is stated as "no records created (read-only flow)" rather than omitted, so a reader can tell the difference between "created nothing" and "did not track".

### Authentication

Two paths, primary and verified-fallback, because `--restore` is on the quarantine list:

**Primary (pending flag verification).** Authenticate once under `$S`, then restore on later runs. If `agent-browser --help` confirms the flags at apply time, they are global and precede the subcommand:

```bash
agent-browser --session "$S" --restore open https://app.example.com/dashboard
```

`agent-browser session info --json` reports "daemon, launch, and **restore** diagnostics" and `AGENT_BROWSER_NAMESPACE` is documented as the "namespace for daemon sockets and **restore state**", so restore state demonstrably exists in 0.32.2 — but the flag spelling is **not** in the captured reference and MUST NOT be written into a skill until verified.

**Verified fallback (no unverified flags).** Every command below appears in the reference:

```bash
# a) replay a supplied token before the first navigation
agent-browser --session "$S" cookies set session_id "$TOKEN" --url https://app.example.com
agent-browser --session "$S" storage local set authToken "$TOKEN"
agent-browser --session "$S" open https://app.example.com/dashboard

# b) HTTP Basic
agent-browser --session "$S" set credentials "$USER" "$PASS"

# c) header-based auth, scoped to the origin
agent-browser --session "$S" open api.example.com --headers '{"Authorization": "Bearer '"$TOKEN"'"}'

# d) last resort — re-run the login flow as flow step 0
```

**Verification after restore.** Whatever path is used, authentication is confirmed by observation, never assumed:

```bash
agent-browser --session "$S" get url --json     # did we land on the protected page or bounce to /login?
agent-browser --session "$S" is visible "<authenticated-only selector>"
```

A restore that silently failed and left the browser on the login page would turn every subsequent step into a false FAIL. Confirming state before the first real step is what prevents that class of false BLOCKER.

**Credential policy.** Unchanged from `skills/qa-browser/SKILL.md:355-356`: never enter real credentials; when auth is required and no credentials were provided, report a NOTE and test only public pages.

### Daemon lifecycle

| Event | Action |
|---|---|
| first command of a review | `open` launches Chrome and starts the daemon for `$S` |
| between commands | daemon persists — commands chain with `&&` in one shell call, and state survives across separate calls |
| health probe | `agent-browser --session "$S" session info --json` |
| connection/socket error | reconnect branch of Sequence Diagram 2: probe, relaunch, re-establish auth, retry the step **once**, mark INCONCLUSIVE on the second failure |
| stale socket/pid/version sidecar files | `agent-browser doctor` auto-cleans them; a preflight re-run is the recovery path |
| end of the last flow | `agent-browser --session "$S" close` |
| **never** | `agent-browser close --all` — it closes **all active sessions**, including other agents' concurrent runs |

**Invariant (risk R8).** Backend loss is a testing-environment fault, never an application defect. It produces INCONCLUSIVE and a flow-level WARNING, never FAIL and never a BLOCKER. Under ADR-A a daemon timeout misread as a flow failure would be a veto-bearing false positive — this invariant is what stops that.

### What sessions do NOT isolate

Stated plainly in the contract so nobody mistakes it for cleanup: `--session` isolates cookies, localStorage, sessionStorage, IndexedDB, and tabs. It does **not** isolate server-side database state. A named session does not undo a created record. That is exactly why unique identities are mandatory rather than optional.

---

## Command Correctness Discipline

Three command errors have already been caught in this change. This section is the mechanism that prevents a fourth.

### Allowlist — verified in `agent-browser-command-reference.md`

Only these forms may be written into a skill file by the apply phase.

| Purpose | Verified form |
|---|---|
| launch, no navigation | `agent-browser --session "$S" open` |
| launch + navigate | `agent-browser --session "$S" open <url>` |
| origin-scoped headers | `agent-browser --session "$S" open <url> --headers '{"Authorization":"Bearer ..."}'` |
| settle | `agent-browser --session "$S" wait --load networkidle` (also `load`, `domcontentloaded`) |
| settle on route / text / selector / predicate | `wait --url "**/dashboard"` · `wait --text "Welcome back"` · `wait "#result"` · `wait --fn "<expr>"` |
| act | `click "<sel>"` · `click @e7` · `fill "<sel>" "<text>"` · `press "<key>"` · `type` · `check` · `select` · `scroll` |
| semantic act | `find role button click --name "Sign In"` · `find label "Email" fill "<v>"` · `find testid "login-form" click` |
| observe | `get url` · `get title` · `get text "<sel>"` · `get value "<sel>"` · `get attr "<sel>" href` · `get count "<sel>"` · `get box "<sel>"` · `get styles "<sel>"` |
| state check | `is visible "<sel>"` · `is enabled "<sel>"` · `is checked "<sel>"` |
| structure | `snapshot` · `snapshot -i` · `snapshot -i --urls` · `snapshot --compact --depth 5` · `snapshot -s "#main"` |
| capture | `screenshot <path>` · `screenshot --full <path>` · `screenshot --annotate <path>` · `--screenshot-dir <dir>` |
| diagnostics | `console` · `console --clear` · `errors` · `errors --clear` (all accept `--json`) |
| network observe | `network requests` · `--clear` · `--filter <p>` · `--type xhr,fetch` · `--method POST` · `--status 2xx` · `network request <id>` |
| network intercept | `network route "<glob>" --abort` · `network route "<glob>" --body '<json>'` · `network unroute [<glob>]` |
| HAR | `network har start` · `network har stop <path>` |
| video | `record start <path.webm> [url]` · `record stop` · `record restart <path.webm>` |
| emulation | `set viewport <w> <h> [scale]` · `set device "<name>"` · `set media dark` · `set media light reduced-motion` · `set offline on\|off` · `set credentials <u> <p>` · `set headers '<json>'` |
| storage | `cookies` · `cookies get` · `cookies set <n> <v> [--url --domain --path --httpOnly --secure --sameSite --expires]` · `cookies clear` · `storage local\|session [get\|set\|clear]` |
| visual regression | `diff screenshot --baseline <file> [-o <out>] [-t 0.1] [-s <sel>] [--full]` · `diff snapshot [-b <file>] [-s <sel>] [-c] [-d <n>]` · `diff url <u1> <u2>` |
| scripting | `eval "<simple expr>"` · `eval --stdin` (heredoc) · `eval -b <base64>` |
| session | `session id --scope worktree --prefix qase` · `session info --json` · `session list` |
| health | `doctor --json` · `doctor --offline --quick` |
| teardown | `close` |
| staging | `batch '["open"]' '["network","route","*","--abort","--resource-type","script"]' '["navigate","<url>"]'` |

Notes bound to specific traps:
- **Global flags precede the subcommand.** `agent-browser --session test open example.com` — verified verbatim.
- `wait networkidle` is invalid. `wait --load networkidle` is correct.
- `cookies get` **is** valid and is the default operation. The earlier "correction" claiming otherwise was itself wrong.
- `set media reduced-motion` alone is not a documented form; the documented forms pair a scheme with the motion flag.
- Complex JavaScript uses `eval --stdin` or `eval -b`; inline `eval` is for simple expressions only. This matters for axe-core injection and computed-style extraction.
- `--resource-type` on `network route` appears in a verified `open --help` example but is **absent** from `network --help`. Use only in the `batch` form shown, or verify it first.

### Quarantine — needed but NOT in the captured reference

Each entry has a designed fallback so the change never depends on an unverified string. Apply MUST run `agent-browser <cmd> --help` before writing any of these.

| Command / flag | Evidence it exists | Verified fallback used by this design |
|---|---|---|
| `agent-browser --version` | proposal preflight step 1 | **replaced**: presence via `command -v agent-browser`; version read from `doctor --json` |
| `--restore`, `--restore-save`, `--restore-check-url\|-text\|-fn` | `session info` shows "restore diagnostics"; `AGENT_BROWSER_NAMESPACE` is documented as namespacing "restore state" | cookie/storage replay, `set credentials`, `--headers`, or re-running login as step 0; plus post-restore state verification |
| `agent-browser vitals [url] [--json]` | proposal §5; exploration; the reference's "vitals" section actually captured **top-level help**, not `vitals --help` | if unverified, Core Web Vitals via `eval --stdin` with `PerformanceObserver` (the current Step 8 approach) |
| `agent-browser install`, `install --with-deps` | proposal §4 install hint | never executed by QASE regardless — surfaced as text for the user to run |
| `back`, `forward`, `reload` | exploration inventory; not in the captured top-level command list | `open <url>` to the previous URL |
| `--allowed-domains` as a global flag | captured only under `read`'s global options | existing safety rule "never leave the origin", enforced by the skill refusing off-origin navigation |
| `agent-browser batch` help | no `batch --help` captured; the exact invocation shape **is** shown verbatim in `open --help` | use only the shape shown in that example |
| `--enable react-devtools`, `--init-script`, `--headed` | listed under `open`'s global options (verified there) | in scope only for `open`; React DevTools integration is deferred anyway |

**Rule for apply.** A command that is neither on the allowlist nor cleared out of quarantine by a fresh `--help` MUST NOT appear in a skill file. `sdd-verify` enumerates every `agent-browser` string in the diff and checks it against this section (proposal success criterion 8).

---

## Error Handling and Degradation

| Condition | Detection | Response | Continue? |
|---|---|---|---|
| No Bash tool | executor tool set lacks Bash | preflight `runtime_available: false`, reason names the executor limit | runtime skills SKIP entirely |
| agent-browser absent | `command -v` exit != 0 | `runtime_available: false` + install hint (never executed) | SKIP |
| `doctor` exit 1, smoke passes | exit code + smoke result | `runtime_available: true`, failed checks recorded, degraded-confidence note | YES |
| `doctor` passes, smoke fails | smoke exit != 0 | `runtime_available: false` — the installed-but-broken case | SKIP |
| Preflight cache stale (> TTL) | `probed_at` + `ttl_hours` | treat as absent; instruct re-run of `/qa-init` | SKIP |
| Page unreachable at flow open | `open`/`wait` failure | BLOCKER "Application unreachable at {url}", Oracle Tier L4 (advisory) unless a spec covers availability | STOP the flow |
| Daemon lost mid-step | non-zero exit + connection error | probe `session info --json`, relaunch, re-auth, retry once; then INCONCLUSIVE | retry once, then abort flow as PARTIAL |
| `network unroute` fails after fault injection | non-zero exit | **abort the flow** — later steps would run against a contaminated network layer | NO |
| Selector not found | `click`/`fill` failure or `snapshot -i` miss | step INCONCLUSIVE with the attempted selector recorded; never FAIL (a stale selector is not a product defect) | YES |
| Element covered by another | agent-browser reports the covering element instead of misclicking | record the covering element as the observation; classify against the oracle | YES |
| `eval` blocked by CSP | script error | degrade to snapshot/computed-value-free analysis; INFO finding noting the degradation | YES (degraded) |
| No oracle at any tier | resolver returns UNGROUNDED | INCONCLUSIVE + INFO, with the absence note | YES |
| Production target + write flow | target classified as production | SKIPPED with reason; never silently omitted | YES (other flows) |
| Write flow with no cleanup hook | `detected_cleanup_hook: null` | proceed with unique identities; Test Data Ledger records the residue | YES |
| Screenshot write fails | non-zero exit | step keeps its evidence row; artifact cell records the failure; flow-level INFO | YES |

**Degradation principle.** Once the flow has opened successfully, no single command failure hard-fails the review. Failures become INCONCLUSIVE rows and INFO findings, and the report states reduced coverage. The one exception is a failed `unroute`, because continuing would produce evidence that is actively wrong — and wrong evidence is worse than no evidence under ADR-A.

---

## File Changes

| File | Action | Summary |
|---|---|---|
| `skills/_shared/qase/oracle-contract.md` | **Create** | L1-L4 model, citation rules, resolution algorithm, blocking matrix, anti-inflation rules |
| `skills/_shared/qase/severity-contract.md` | Modify | `## Oracle Tier and Verdict`; three-agent veto table with tier-scoped row; tier gate in verdict logic; runtime severity ceilings |
| `skills/_shared/qase/issue-format.md` | Modify | `Oracle Tier` + `Oracle Citation` in both runtime variants; `## Flow Evidence Format`; extended metadata envelope |
| `skills/_shared/qase/persistence-contract.md` | Modify | `## Runtime Preflight Cache` (schema, single writer, TTL, refusal rule); binary-artifact rule |
| `skills/_shared/qase/engram-convention.md` | Modify | flow-evidence naming block; preflight key; two new artifact types; markdown-only note |
| `skills/_shared/qase/openspec-convention.md` | Modify | preflight-cache, baselines, flow-evidence subtree, visual-diffs; baselines-outside-reviews rule |
| `skills/_shared/qase/routing-rules.md` | Modify | out-of-band table rewritten (backend, tiers, veto); preflight precondition; oracle-tier-aware routing |
| `skills/qa-browser/SKILL.md` | Modify | **primary target** — CLI migration, Step 9 flow engine, network interception, sessions, per-step diagnostics, oracle tiers, `veto_power: true` |
| `skills/qa-visual/SKILL.md` | Modify | CLI migration, `set viewport`, `set media`, baseline diff, oracle tiers, stays `veto_power: false` |
| `skills/qa-init/SKILL.md` | Modify | new Step 4 runtime preflight; Step 4 -> Step 5; Runtime Backend section in all three return blocks |
| `skills/qa-report/SKILL.md` | Modify | **not in the proposal's table** — Step 3 finding-scoped veto predicate, Step 4 sort, tier-aware dedup, metadata `veto-tiers` |
| `README.md` | Modify | remove Chrome DevTools MCP as a prerequisite; describe the agent-browser + Bash requirement |
| `.atl/skill-registry.md` | Regenerate | lines 92 and 101 currently say "via Chrome DevTools MCP" |

No changes to `scripts/install.sh`, `scripts/install_test.sh`, or `scripts/lint_skills.sh`. The linter discovers skills dynamically via `skills/qa-*/`, so nothing needs registration. Every touched skill keeps its frontmatter delimiters, `name`/`description`/`license`, the four required sections (`## Purpose`, `## Execution and Persistence Contract`, `## What to Do`, `## Rules`), and its `persistence-contract.md` reference.

---

## Rollback Design

All changes are Markdown: one new file, ten modified `.md` files, plus `README.md` and the regenerated registry. No binaries, no schema migrations, no persisted format that outlives a review.

### Full revert

```bash
# 1. revert the change's commit range
git revert <first-sha>..<last-sha>          # or: git revert -m 1 <merge-sha>

# 2. prove the contracts still hold
bash scripts/lint_skills.sh                  # must exit 0
bash scripts/install_test.sh                 # must exit 0

# 3. remove the new file if the revert left it untracked
rm -f skills/_shared/qase/oracle-contract.md

# 4. regenerate the registry
gentle-ai skill-registry refresh --force

# 5. purge cross-run state introduced by this change
rm -f qaspec/preflight-cache.yaml
rm -rf qaspec/reviews/*/flow-evidence qaspec/reviews/*/visual-diffs
#   engram mode: delete the topic qa-init/{project}/preflight
#   engram mode: delete topics qase/{review-id}/flow-evidence/*

# 6. reinstate Chrome DevTools MCP as a prerequisite in README.md if it was removed
```

Markdown-only means no conflicts outside the touched files.

### Partial rollback — the likely case

The decisions are independently revertible by construction:

| Symptom | Revert | Cost | What keeps working |
|---|---|---|---|
| Veto too aggressive (ADR-A) | `veto_power: false` in `qa-browser` frontmatter + delete its `severity-contract.md` row + restore `qa-report` Step 3 to the two-agent form | ~4 lines, 3 files | flow evidence, oracle tiers, CLI migration, preflight |
| L3 too noisy (ADR-C) | in `oracle-contract.md`, cap `L3-inferred` at INFO, or disable pattern extraction so L3 means schema-only | 1 file | everything else |
| Write flows causing trouble (ADR-D) | set write flows refused-by-default in `qa-browser` | 1 file | read-only flows keep producing evidence |
| One agent-browser command misbehaving | correct or remove the command in place | 1 line | no rebuild, no reinstall — skills are instructions, not code |
| Preflight producing false negatives | delete the cache file/topic and re-run `/qa-init`, or reduce `ttl_hours` | data-only | everything else |

### Residue that survives a revert

| Residue | Where | Removal |
|---|---|---|
| preflight cache | `qaspec/preflight-cache.yaml` or engram `qa-init/{project}/preflight` | step 5 above — the only cross-run state this change introduces |
| flow evidence + binaries | `qaspec/reviews/*/flow-evidence/` (openspec) or temp dir (engram/none) | step 5; temp artifacts expire with the OS temp policy |
| visual baselines | `qaspec/baselines/` | delete if visual regression is abandoned; harmless otherwise |
| **records created in the target application by write flows** | the target app's database | **not removable by reverting QASE** — this is why the Test Data Ledger is mandatory; it is the record a human uses to clean up manually |

The last row is the only non-rollbackable side effect in the change, and it is bounded by the opt-in and production-refusal rules of ADR-D.

---

## Open Questions

- [ ] Should a `qa-browser` L1 BLOCKER outrank a `qa-security` BLOCKER in report ordering, or are all veto-bearing findings peers? (Recommendation: peers. Introducing a precedence order among veto holders adds a ranking rule with no verdict consequence — the verdict is already a disjunction.)
- [ ] Should `L2` require the test to be executed *in this review*, or is a CI result from the current commit acceptable? (Recommendation: executed in this review, per proposal assumption 4. Accepting CI output introduces a staleness question the first slice should not carry.)
- [ ] Should the flow evidence document be written incrementally per step, or once at flow end? (Recommendation: once at flow end in the first slice — incremental writes need partial-file recovery semantics on abort. Revisit if long flows prove lossy on daemon loss.)
- [ ] When `qa-visual` runs in engram mode, baseline diffing is unavailable. Should `qa-visual` request openspec mode for baseline work, or accept the limitation? (Recommendation: accept and state it; the orchestrator owns mode selection and a skill demanding a mode inverts that control.)
