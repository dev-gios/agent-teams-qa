# Tasks: runtime-proof-e2e

**Change**: `runtime-proof-e2e`
**Phase**: tasks
**Spec sources**: oracle-contract, runtime-preflight, flow-evidence, runtime-veto, browser-backend-migration
**Verification commands**: `bash scripts/lint_skills.sh` · `bash scripts/install_test.sh`

---

## Phase 1: Infrastructure (New Shared Contract and Shared-Contract Edits)

All Phase 1 tasks are sequential by dependency — the oracle contract must exist before any contract that
references it can be edited. Within the group of five shared-contract edits (1.2–1.6) there are no
inter-dependencies among themselves, so they may be executed in parallel once 1.1 is complete.

### [x] 1.1 Create `skills/_shared/qase/oracle-contract.md` (NEW FILE)

**Spec**: oracle-contract/spec.md — all requirements
**Design**: Contract Threading Map §1; Oracle Resolution Algorithm; Blocking Matrix; ADR-C

Create the file with the following sections in order. No `agent-browser` command may appear in this file
(boundary B2).

- `## Purpose` — "An expectation without a stated source is an opinion; an expectation with a cited source
  is evidence." Explain that this file is the single source of truth for tier semantics (boundary B3).
- `## The Four Tiers` — table: Tier | Name | Source | Available-When | Citation Requirement | Max Severity
  | Veto-Bearing. Rows: L1, L2, L3-schema, L3-inferred, L4. Max severity column: L1=BLOCKER, L2=BLOCKER,
  L3-schema=BLOCKER, L3-inferred=WARNING, L4=WARNING. Veto-bearing column: L1–L3-schema=yes (via
  qa-browser gate), L3-inferred=no, L4=no.
- `## Tier Population` — how each tier is gathered: L1 glob
  `openspec/changes/*/specs/**/*.md`, L2 execute the test runner and read its output (not "tests exist"),
  L3-schema scan for OpenAPI/Swagger/JSON Schema/Zod/Pydantic/class-validator/Prisma/GraphQL SDL, L3-inferred
  scan validation regexes and error-message literals, L4 named standards (WCAG SC id, HTTP semantics, CWV
  metric name + threshold, Nielsen heuristic number).
- `## Citation Requirements` — restate ADR-C rules verbatim and mechanically:
  - L1: spec file path + scenario/heading title quoted verbatim.
  - L2: test file name + test case name/description + observed runner output line (test must have been
    EXECUTED in this review).
  - L3-schema: `path:line` + the literal contract text verbatim. Missing any component → automatic
    downgrade to L3-inferred.
  - L3-inferred: ≥ 2 independent signals each with its own `path:line` + literal. Two signals from the
    same expression are ONE signal. < 2 → downgrade to L4.
  - L4: a NAMED standard (WCAG SC id, RFC section, CWV metric name + threshold, Nielsen heuristic number).
    No named standard → UNGROUNDED.
- `## Resolution Algorithm` — reproduce the 7-step walk from design verbatim (CANDIDATE FILTER →
  STRICT DESCENDING WALK → TIE-BREAK → CLAIM VALIDATION → DOWNGRADE → ABSENCE DECLARATION →
  UNGROUNDED). Include the claim-validation table.
- `## Degradation and Absence` — downgrade table (transitive, re-validated at each new tier); mandatory
  absence note on any result below L3-schema naming each higher tier consulted and why unavailable;
  "no code contract found for this path" note for the L4 case; "L1 unavailable: no openspec/ directory"
  and "L2 unavailable: no test runner detected" notes for the universality case.
- `## Blocking Matrix` — verbatim table stating which tiers may produce BLOCKER:
  L1=may, L2=may, L3-schema=may (requires citation), L3-inferred=must not (WARNING cap),
  L4=must not (advisory only). This table MUST appear verbatim in this file per
  oracle-contract/spec.md §"Blocking matrix governs which tiers may produce BLOCKER".
- `## Anti-Inflation Rules` — uncited L3-schema auto-downgrades to L3-inferred; single-signal L3-inferred
  auto-downgrades to L4; UNGROUNDED never produces FAIL, only INCONCLUSIVE at INFO ceiling; a runtime
  finding with no Oracle Tier field is treated as UNGROUNDED and capped at INFO.

---

### [x] 1.2 Edit `skills/_shared/qase/severity-contract.md`

**Spec**: oracle-contract/spec.md §"Blocking matrix"; runtime-veto/spec.md — all requirements
**Design**: Contract Threading Map §2; Veto Gate Design; verdict logic pseudocode

Insertions in line-number order (against the file as it exists before this edit):

- After the severity table (line 11), before `## Veto Power` (line 13): insert NEW section
  `## Oracle Tier and Verdict`:
  - Reference `oracle-contract.md` (satisfies §"All five other shared contracts reference oracle-contract.md").
  - State the severity ceilings: L4 never produces BLOCKER; L3-inferred caps at WARNING; L1, L2, L3-schema
    may produce BLOCKER.
  - State: a runtime finding with no Oracle Tier field is treated as UNGROUNDED and capped at INFO.
- Line 15 (the "Two specialists" sentence): change to "**Three** specialists have **veto power** — one
  of them conditionally".
- Veto table (lines 17–20): add row:
  `| qa-browser | BLOCKERs carrying Oracle Tier L1, L2, or L3-schema only. Findings at L3-inferred or L4 NEVER carry veto and NEVER produce BLOCKER under the qa-browser veto rule. |`
  This row satisfies runtime-veto/spec.md §"severity-contract.md veto table contains a row for qa-browser".
- Line 22 (non-veto sentence): extend to name `qa-visual` explicitly and to state that `qa-browser`
  findings outside the tier gate are non-veto.
- Verdict logic block (lines 26–39): insert the tier gate BEFORE the veto branch. Reproduce the
  two-gate pseudocode from design §"Verdict logic after the change" verbatim:
  Gate 1 (tier ceiling enforcement) → Gate 2 (veto-bearing predicate). The veto predicate MUST name
  the finding-level condition, not agent-level alone (R11 resolution).
- `## Severity Assignment Guidelines` (line 41): add `### Runtime findings` subsection restating the
  ceilings: L4 advisory (WARNING max), L3-inferred WARNING max, L3-schema/L2/L1 may reach BLOCKER.

**Sync invariant (V2)**: the qa-browser row in this veto table and `veto_power: true` in
`skills/qa-browser/SKILL.md` MUST be committed together per runtime-veto/spec.md §"Frontmatter and veto
table are always in sync". Plan these as a single apply unit.

---

### [x] 1.3 Edit `skills/_shared/qase/issue-format.md`

**Spec**: oracle-contract/spec.md §"Oracle Tier in the Issue Format"; flow-evidence/spec.md §"Flow
Evidence Document Structure"
**Design**: Contract Threading Map §3

Insertions in document order:

- Browser Testing Variant: after `**Category**:` field (line 59), add:
  `**Oracle Tier**: L1 | L2 | L3-schema | L3-inferred | L4`
- Browser Testing Variant: after `#### Evidence` (lines 70–71), add required subsection
  `#### Oracle Citation` — `path:line` plus verbatim literal, or the Oracle Absence note if no
  L3-schema source was found.
- Browser Testing Variant "Key differences" bullets: add a bullet for the Oracle Tier field and the
  citation requirement.
- Visual Testing Variant: after `**Category**:` field (line 94), add the same `**Oracle Tier**` line.
- Visual Testing Variant: after `#### Evidence` (lines 105–106), add the same `#### Oracle Citation`
  subsection with a note that `qa-visual` findings are predominantly L4 and therefore advisory.
- Visual Testing Variant "Key differences" bullets: note that `qa-visual` findings are predominantly
  L4 and therefore advisory.
- After the Visual Testing Variant (before `## Grouping`): insert NEW section `## Flow Evidence Format`
  containing:
  - The per-step evidence table (Action / Observed / Expected / Oracle Tier / Status / Artifact) with
    the exact structure from flow-evidence/spec.md §"Flow evidence document structure is complete and
    parseable".
  - The flow evidence document header block (`## Flow Evidence: {flow-name}`, `**Started at**`,
    `**App URL**`, `**Session**`, `**Oracle sources consulted**`).
  - The Flow Summary table (Steps executed / Passed/Failed / BLOCKERs/WARNINGs / Video evidence /
    Network log).
  - The Test Data Ledger format (Identity Type / Value / Created At) with the rule that a read-only
    flow records `—` rather than omitting the section.
  - The Status value contract: `PASS`, `FAIL — BLOCKER`, `FAIL — WARNING` (never bare `FAIL`),
    `INCONCLUSIVE`. This satisfies flow-evidence/spec.md §"FAIL status records the severity".
- Metadata Envelope (lines 152–164): add:
  - `- **oracle-tier-breakdown**: { L1: {n}, L2: {n}, L3-schema: {n}, L3-inferred: {n}, L4: {n} }`
  - `- **flow-evidence**: {path | topic_key | none}`
  - `- **runtime-available**: true | false`
  These satisfy oracle-contract/spec.md §"Metadata envelope carries oracle_tier_breakdown".

---

### [x] 1.4 Edit `skills/_shared/qase/persistence-contract.md`

**Spec**: runtime-preflight/spec.md §"Preflight Cache Schema and Storage"
**Design**: Contract Threading Map §4; Preflight cache schema

Insertions:

- After `## Behavior Per Mode` table (line 48), before `## Common Rules` (line 50): insert NEW section
  `## Runtime Preflight Cache` containing:
  - The YAML schema verbatim from runtime-preflight/spec.md §"Preflight cache written in openspec mode":
    `preflight.agent_browser`, `preflight.doctor_result`, `preflight.chrome_binary`,
    `preflight.smoke_test`, `preflight.smoke_test_error`, `preflight.runtime_available`,
    `preflight.unavailable_reason`, `preflight.probed_at`, `detected_start_hints[]`.
  - Add `detection_mechanism` field per runtime-preflight/spec.md §"Preflight cache includes the
    detection mechanism used": one of `"doctor"`, `"chrome-probe-fallback"`, or `"bash-unavailable"`.
  - Single-writer rule: `qa-init` is the ONLY writer of this cache. `qa-browser` and `qa-visual` read
    it and MUST NOT write to it.
  - TTL/freshness rule: a cache entry older than `ttl_hours: 24` is treated as absent.
  - Refusal rule: when `runtime_available` is not `true`, `qa-browser` and `qa-visual` return
    `status: skipped` with `verdict_contribution: CLEAN`, a single INFO finding with the cached reason,
    and zero runtime findings. Fabricating findings from static reading is prohibited.
  - Add reference to `oracle-contract.md` (satisfies §"All five other shared contracts reference
    oracle-contract.md").
- `## Common Rules` (lines 50–56): add rule: binary artifacts (screenshots, `.webm`, `.har`) are
  NEVER stored in engram. In `engram` and `none` modes they are written to a run-scoped temp dir
  (`${TMPDIR:-/tmp}/qase/{review-id}/{flow-slug}/...`) and referenced by absolute path with an
  explicit `(ephemeral)` marker. This satisfies "engram mode writes no project files".

---

### [x] 1.5 Edit `skills/_shared/qase/engram-convention.md`

**Spec**: oracle-contract/spec.md §"All five other shared contracts reference oracle-contract.md";
flow-evidence/spec.md §"Flow evidence written in engram mode"
**Design**: Contract Threading Map §5

Insertions:

- After `### Review Artifacts` block (line 15): insert NEW `### Flow Evidence (per-flow)` naming block:
  ```
  title:     qase/{review-id}/flow-evidence/{flow-slug}
  topic_key: qase/{review-id}/flow-evidence/{flow-slug}
  type:      architecture
  project:   {project}
  scope:     project
  ```
- `### Project Init` block (lines 19–25): add the preflight cache key:
  ```
  title:     qa-init/{project-name}/preflight
  topic_key: qa-init/{project-name}/preflight
  type:      architecture
  ```
  Annotate as project-scoped, long-lived artifact (24h TTL per persistence-contract.md).
- Artifact Types table (lines 39–52): add two rows:
  - `| flow-evidence | qa-browser | Per-flow step-by-step executed evidence document |`
  - `| preflight-cache | qa-init | Runtime backend capability cache (single writer: qa-init) |`
- After the Artifact Types table: add NOTE: "Engram stores markdown only. Binary artifact PATHS are
  recorded (ephemeral marker); binary artifact bytes are not stored. See persistence-contract.md."
- Anywhere appropriate (suggest top of file or Purpose section): add reference to `oracle-contract.md`.

---

### [x] 1.6 Edit `skills/_shared/qase/openspec-convention.md`

**Spec**: runtime-preflight/spec.md §"Preflight cache written in openspec mode";
flow-evidence/spec.md §"Flow evidence written in openspec mode"; browser-backend-migration/spec.md
(baseline/visual-diff paths)
**Design**: Contract Threading Map §6; Evidence Artifact Layout

Insertions:

- Directory Structure (lines 5–25): add the following entries after the existing `reviews/` subtree:
  ```
  ├── preflight-cache.yaml          <- NEW, written by qa-init only
  ├── baselines/                    <- NEW, persists ACROSS reviews
  │   └── {page-slug}/
  │       ├── 1440x900.png
  │       ├── 768x1024.png
  │       └── 375x812.png
  ```
  And extend the `{review-id}/` subtree:
  ```
  │       ├── visual-diffs/                       <- NEW, diff output (per review)
  │       │   └── {page-slug}-{viewport}.png
  │       └── flow-evidence/                      <- NEW
  │           ├── {flow-slug}.md
  │           └── {flow-slug}/
  │               ├── screenshots/step-01.png ... step-NN.png
  │               ├── console/step-01.json    ... step-NN.json
  │               ├── errors/step-01.json     ... step-NN.json
  │               ├── network/step-01.json    ... step-NN.json
  │               ├── har/{flow-slug}.har          (deep / on request)
  │               └── recordings/{flow-slug}.webm  (deep / on request)
  ```
- Artifact File Paths table (lines 30–42): add/extend:
  - `qa-init` also creates `qaspec/preflight-cache.yaml`
  - `qa-browser` also creates `qaspec/reviews/{review-id}/flow-evidence/{flow-slug}.md` and its
    artifact subtree; screenshots are referenced by relative path from the review directory
    (e.g., `flow-evidence/{flow-slug}/screenshots/step-01.png`).
  - `qa-visual` also creates `qaspec/reviews/{review-id}/visual-diffs/` and reads/writes
    `qaspec/baselines/`
- Writing Rules (lines 64–69): add:
  - Visual baselines persist across reviews and MUST live at `qaspec/baselines/`, never inside a
    `reviews/{review-id}/` directory. A baseline inside a review folder cannot be diffed against by
    the next review (same reasoning as feedback files).
  - `{flow-slug}` is kebab-case slug of the flow name; step index `NN` is zero-padded, one-based,
    matching the evidence row numbering.
- Anywhere appropriate: add reference to `oracle-contract.md`.

---

### [x] 1.7 Edit `skills/_shared/qase/routing-rules.md`

**Spec**: oracle-contract/spec.md §"All five other shared contracts reference oracle-contract.md";
runtime-preflight/spec.md §"Subsequent qa-browser invocation reads the preflight cache"
**Design**: Contract Threading Map §7

Insertions:

- Out-of-Band Specialists table (lines 98–101): rewrite both rows:
  - Drop "Chrome DevTools" from both descriptions; name the agent-browser CLI as the backend.
  - Add column **Oracle Tiers**: `qa-browser` = L1–L4; `qa-visual` = predominantly L4.
  - Add column **Veto**: `qa-browser` = tier-gated (L1/L2/L3-schema BLOCKERs only); `qa-visual` = none.
  This satisfies browser-backend-migration/spec.md §"Zero 'Chrome DevTools MCP' string references".
- Bullets at lines 103–107: add: "Out-of-band runtime specialists require `runtime_available: true` in
  the preflight cache. When the cache is absent, stale (> TTL), or `runtime_available: false`, they
  return `status: skipped` with the cached reason and produce zero runtime findings." This satisfies
  runtime-preflight/spec.md §"Subsequent qa-browser invocation reads the preflight cache".
- After those bullets: insert NEW section `## Oracle-Tier-Aware Routing` — a runtime specialist's
  findings enter consensus with their tier attached; `qa-report` sorts and gates on tier, not on
  agent name alone. Reference `oracle-contract.md`.
- Anywhere appropriate: add reference to `oracle-contract.md`.

---

## Phase 2: Core Implementation (Skill-File Edits)

Tasks 2.1–2.5 may proceed in parallel once Phase 1 is complete (each edits a separate file).
Task 2.5 (`qa-report`) depends on 2.1 (`qa-browser`) in semantic terms but is editorially independent;
run in parallel but verify consistency during Phase 3.

**Command correctness pre-condition for all Phase 2 tasks**: every `agent-browser` command string
written into a skill file MUST appear verbatim (subcommand + flag form) in
`openspec/changes/runtime-proof-e2e/agent-browser-command-reference.md`. Commands on the quarantine
list (design §"Quarantine") MUST be verified with `agent-browser <cmd> --help` before use. No
quarantined command may be written into a skill file without that verification step being recorded
in the apply-progress artifact.

---

### [x] 2.1 Edit `skills/qa-browser/SKILL.md` — Frontmatter, Description, and Contract (precondition for V1/V2 sync)

**Spec**: runtime-veto/spec.md §"qa-browser SKILL.md frontmatter declares veto_power: true";
browser-backend-migration/spec.md §"MCP core tools profile explicitly excluded"
**Design**: ADR-A; Sync invariant V1; Design §"Skill files" table

This task and task 1.2's qa-browser veto-table row MUST be committed atomically (V1+V2 sync
invariant from design):

- Frontmatter line 12: change `veto_power: false` to `veto_power: true`.
- Description lines 3–6: drop "via Chrome DevTools MCP"; replace with "connects to a running
  application via the agent-browser CLI, drives a real Chrome session through Bash, and finds
  runtime issues invisible to static analysis."
- Add explicit statement after the description: "The agent-browser MCP `core` tools profile is NOT
  a supported backend. The MCP `core` profile is a curated subset and lacks network interception,
  full session management, and debug capabilities required by QASE. Skills invoke the agent-browser
  CLI via Bash."
- `## Execution and Persistence Contract`: add a line referencing `oracle-contract.md` and state
  the `flow-evidence` artifact type (topic_key pattern `qase/{review-id}/flow-evidence/{flow-slug}`).

---

### [x] 2.2 Edit `skills/qa-browser/SKILL.md` — Steps 1–8 (MCP Migration + Oracle Tiers)

**Spec**: browser-backend-migration/spec.md — all command-mapping requirements
**Design**: Design §"Skill files" table; Allowlist table

Rewrite Steps 1–8 to replace every MCP tool call with the verified CLI equivalent. Every finding
gains an Oracle Tier. All commands MUST come from the allowlist or be cleared out of quarantine.

- **Step 1 → "Establish Runtime Backend"**:
  - Read preflight cache (B1): if `runtime_available != true`, SKIP entire skill with `status: skipped`
    and `verdict_contribution: CLEAN`; include the cached `unavailable_reason`. Zero runtime findings.
  - Derive session: `S="$(agent-browser session id --scope worktree --prefix qase)"`.
  - `agent-browser --session "$S" open <url>` (replaces `navigate_page(url)`).
  - `agent-browser --session "$S" wait --load networkidle` (replaces `wait_for("load")`; bare
    `wait networkidle` is invalid per spec).
  - `agent-browser --session "$S" snapshot -i` (replaces `take_snapshot()`).
  - `agent-browser --session "$S" screenshot <path>` (replaces `take_screenshot()`).
  - `agent-browser --session "$S" console` (replaces `list_console_messages()`).
  - `agent-browser --session "$S" network requests` (replaces `list_network_requests()`).
  - Error handling: unreachable URL → BLOCKER at L4 unless spec covers availability.
- **Step 2 — Console Error Audit**: replace `list_console_messages(types: [...])` with
  `agent-browser --session "$S" console --json`; replace `get_console_message(id)` with reading
  the JSON output. Oracle Tier: L4 (console errors are heuristic unless a spec scenario covers them).
- **Step 3 — Network Health Audit**: replace `list_network_requests()` with
  `agent-browser --session "$S" network requests --json`; replace `get_network_request(id)` with
  `agent-browser --session "$S" network request <requestId>`. Oracle Tier: L4 for HTTP semantics.
- **Step 4 — Accessibility Audit**: replace `evaluate_script()` injection with
  `agent-browser --session "$S" eval --stdin` (heredoc form for complex scripts). Replace
  `wait_for("selector", ...)` with `agent-browser --session "$S" wait "<selector>"`. Oracle Tier: L4
  (WCAG SC citations required per blocking matrix — L4 advisory, WARNING max).
- **Step 5 — Interactive Element Testing**: replace `click(selector)` with
  `agent-browser --session "$S" click "<sel>"` or `find role button click --name "..."`;
  replace `fill_form(selector, {})` with `agent-browser --session "$S" fill "<sel>" "<value>"`;
  replace `press_key("Enter")` with `agent-browser --session "$S" press "Enter"`.
  Replace `wait_for("load")` with `agent-browser --session "$S" wait --load networkidle`.
  Oracle Tier: L4 unless a spec or test covers the interaction path.
- **Step 6 — Navigation Audit**: replace `navigate_page(href)` with
  `agent-browser --session "$S" open <href>`; replace `wait_for("load")` with
  `agent-browser --session "$S" wait --load networkidle`. Oracle Tier: L4.
- **Step 7 — Responsive Audit**: replace `resize_page(width, height)` with
  `agent-browser --session "$S" set viewport <width> <height>` (replaces `resize_page`);
  replace `wait_for("load")` with `agent-browser --session "$S" wait --load networkidle`;
  replace `evaluate_script()` with `agent-browser --session "$S" eval --stdin` (heredoc for
  complex scripts). Oracle Tier: L4.
- **Step 8 — Performance Audit**: `vitals` is on the quarantine list. If verified at apply time
  via `agent-browser vitals --help`, use `agent-browser --session "$S" vitals --json`. If
  unverified, fall back to `eval --stdin` with `PerformanceObserver` (the current Step 8 approach).
  Replace `performance_start_trace()` / `performance_stop_trace()` / `performance_analyze_insight()`
  — these MCP tool calls must not remain. Oracle Tier: L4 (CWV thresholds from Web Vitals spec).

---

### [x] 2.3 Edit `skills/qa-browser/SKILL.md` — Step 9 (Flow Engine)

**Spec**: flow-evidence/spec.md — all requirements; browser-backend-migration/spec.md §"Session ID
derived stably"; runtime-veto/spec.md (veto-bearing predicate applies to flow-evidence findings)
**Design**: Sequence Diagram 2; State and Session Management; Error Handling table

This is the primary extension point. Rewrite Step 9 from its 20-line stub into the full flow engine.
Reproduce the per-step loop exactly. All commands from the allowlist.

**F0 — Precondition**: read preflight cache; if `runtime_available != true`, skip.

**F1 — Oracle Sourcing** (once per flow, before any browser action):
- L1: glob `openspec/changes/*/specs/**/*.md`, parse Given/When/Then scenarios.
- L2: if `qa-init` recorded a test command, EXECUTE it and read the output.
- L3: schema scan then pattern scan.
- L4: always available.

**F2 — Session + Run Setup**:
- `S="$(agent-browser session id --scope worktree --prefix qase)"`.
- `QASE_RUN_ID={epoch-seconds}-{6 lowercase hex}`.
- Write flow evidence header and Test Data Ledger skeleton.

**F3 — Flow Open**:
- `agent-browser --session "$S" open <url>`.
- `agent-browser --session "$S" wait --load networkidle`.
- Deep/on-request only: `agent-browser --session "$S" network har start`.
- Deep/on-request only: `agent-browser --session "$S" record start ./<evid>/recordings/<slug>.webm`.

**Per-step loop (S1–S11)**:

- **S1 Clear buffers** (mandatory before each step N ≥ 2; acceptable but not required for step 1):
  - `agent-browser --session "$S" console --clear`.
  - `agent-browser --session "$S" errors --clear`.
  - `agent-browser --session "$S" network requests --clear`.
  These satisfy flow-evidence/spec.md §"Console buffer cleared before each step",
  §"Error buffer cleared before each step", §"Network requests cleared and attributed per step".

- **S2 Optional fault injection** (only when the step declares one):
  - `agent-browser --session "$S" network route "{url-pattern}" --abort` for abort.
  - `agent-browser --session "$S" network route "{url-pattern}" --body '{json}'` for mock.
  This satisfies flow-evidence/spec.md §"Network route aborted for a forced-failure step".

- **S3 Act**: ONE of the following per step:
  - `agent-browser --session "$S" find role button click --name "Sign In"`.
  - `agent-browser --session "$S" click "<sel>"` or `click @e7`.
  - `agent-browser --session "$S" fill "<sel>" "qase+$QASE_RUN_ID@example.com"` (unique identity
    mandatory for write-flow fields per ADR-D; `qase+{QASE_RUN_ID}@example.com` template).
  - `agent-browser --session "$S" press "Enter"`.
  - `agent-browser --session "$S" type`, `check`, `select`, `scroll` as appropriate.

- **S4 Settle** (narrowest that applies):
  - `agent-browser --session "$S" wait --url "**/dashboard"`.
  - `agent-browser --session "$S" wait --text "Welcome back"`.
  - `agent-browser --session "$S" wait "<selector>"`.
  - `agent-browser --session "$S" wait --load networkidle`.
  - `agent-browser --session "$S" wait --fn "<expr>"`.

- **S5 Observe**:
  - `agent-browser --session "$S" get url`, `get title`, `get text "<sel>"`,
    `is visible "<sel>"`, `snapshot -i`.

- **S6 Harvest per-step diagnostics**:
  - `agent-browser --session "$S" console --json` → `console/step-NN.json`.
  - `agent-browser --session "$S" errors --json` → `errors/step-NN.json`.
  - `agent-browser --session "$S" network requests --json` → `network/step-NN.json`.
  - For requests with status ≥ 400 (standard and deep): `agent-browser --session "$S" network
    request <id>`.
  This satisfies flow-evidence/spec.md §"Failed network request attributed to the correct step".

- **S7 Capture artifact** (every step, always — per proposal success criterion 13):
  - `agent-browser --session "$S" screenshot ./<evid>/screenshots/step-NN.png`.
  - Deep: `screenshot --full <path>`. On finding pointing at element: `screenshot --annotate <path>`.

- **S8 Resolve expectation**: run oracle resolution algorithm from oracle-contract.md (L1→L2→L3-
  schema→L3-inferred→L4), validate the tier claim, downgrade if it fails.

- **S9 Classify**: `PASS | FAIL — BLOCKER | FAIL — WARNING | INCONCLUSIVE | SKIPPED`. Severity
  capped by oracle-tier blocking matrix. `FAIL` bare is invalid per issue-format.md.

- **S10 Teardown of step scope** (runs even on FAIL or INCONCLUSIVE):
  - If a route was installed in S2: `agent-browser --session "$S" network unroute "{url-pattern}"`.
  - If `network unroute` exits non-zero → abort the flow immediately. Later steps would run against
    a contaminated network layer; their evidence would be unreliable. This satisfies flow-evidence
    spec §"Forced-failure finding severity is L4 when no spec covers the error path" (unroute
    failure terminates, not classifies as an app defect).

- **S11 Emit evidence row**: write the completed row to the flow evidence document with all six
  required fields (Action, Observed, Expected, Oracle Tier, Status, Artifact).

**Daemon reconnection branch** (on any of S1–S7 that exits non-zero with a connection/daemon error):
- `agent-browser --session "$S" session info --json`.
- If daemon dead: relaunch with `agent-browser --session "$S" open <url>`, re-establish auth state,
  retry the current step ONCE.
- Retry succeeds: continue, annotate the row "backend reconnected mid-step".
- Retry fails: step = INCONCLUSIVE, abort flow as PARTIAL, flow-level WARNING
  "runtime backend lost". NEVER report daemon loss as an application defect or produce FAIL.

**F4 — Flow Teardown** (after all steps):
- `agent-browser --session "$S" network unroute` (belt-and-suspenders — removes all routes).
- `agent-browser --session "$S" record stop` (if recording was started).
- `agent-browser --session "$S" network har stop ./<evid>/har/<slug>.har` (if HAR was started).
- Invoke `detected_cleanup_hook` if recorded by `qa-init` — otherwise do nothing.
- Do NOT `close` until after the last flow; later flows reuse the session.
- After the last flow: `agent-browser --session "$S" close`.

**F5 — Flow Summary + Test Data Ledger + Persist**:
- Produce the Flow Summary table (Steps executed / Passed/Failed / BLOCKERs/WARNINGs / Video
  evidence / Network log) per flow-evidence/spec.md §"Flow summary produced after all steps execute".
- Produce the Test Data Ledger: every identity and record created; if read-only flow, write `—`
  (not omit). Note whether a cleanup hook was invoked and its result.
- Persist per flow-evidence/spec.md §"Flow evidence written in openspec mode" and §"Flow evidence
  written in engram mode". Engram: `qase/{review-id}/flow-evidence/{flow-slug}`.

**Also in Step 9**: document the write-flow and safety rules:
- Production write flows refused and reported as SKIPPED.
- Write flows opt-in only — never discover and exercise a form autonomously.
- Unique identities mandatory for any write-flow field (QASE_RUN_ID template).
- Never `close --all`.
This satisfies ADR-D and extends the existing safety rules.

---

### [x] 2.4 Edit `skills/qa-browser/SKILL.md` — Report Format, Depth Controls, and Safety Rules

**Spec**: flow-evidence/spec.md §"qa-report can parse flow evidence to extract findings";
oracle-contract/spec.md §"Metadata envelope carries oracle_tier_breakdown"
**Design**: Volume control table; Evidence Artifact Layout

- Update the Report Format to extend the metadata envelope with:
  - `oracle_tier_breakdown: { L1: {n}, L2: {n}, L3-schema: {n}, L3-inferred: {n}, L4: {n} }` (per
    oracle-contract/spec.md).
  - `flow-evidence: {path | topic_key | none}` and `runtime-available: true | false`.
- Extend Depth Controls table to cover the new evidence artifacts:

  | Level | Artifact Scope |
  |-------|---------------|
  | concise | per-step screenshot (required); per-step console/errors JSON; network summary counts only; no HAR; no recording |
  | standard | all of above + full network JSON; per-step network JSON; `--annotate` only when a finding points at an element |
  | deep | all of above + `--full` screenshots; `network request <id>` detail for status ≥ 400; HAR; WebM recording |

- Safety Rules: add:
  - Production write flows refused (SKIPPED with reason).
  - Write flows opt-in per flow.
  - Unique identities mandatory for write flows.
  - Never `close --all`.

---

### [x] 2.5 Edit `skills/qa-report/SKILL.md` — Tier-Gated Veto (R11 Resolution)

**Spec**: runtime-veto/spec.md §"qa-report Consensus Behavior with Three Veto Holders";
runtime-veto/spec.md §"qa-report specialist summary table includes qa-browser as a veto holder"
**Design**: Veto Gate Design §"R11 resolved"; sync invariant V4

This task resolves Risk R11 (design confirmed: no arity assumption to break). The edits are surgical.

- **Step 3 "Apply Veto Logic"** (lines 69–90): replace the current two-agent inline pseudocode with
  the two-gate model from design:
  - Gate 1 (tier ceiling, per finding, re-enforced here — defense in depth):
    if `finding.agent IN {qa-browser, qa-visual}` apply the tier ceilings from oracle-contract.md.
    A BLOCKER arriving at a capped tier is downgraded, not honoured; record `tier-gate-violation`.
  - Gate 2 (veto-bearing predicate, per finding):
    ```
    veto_bearing = finding.severity == BLOCKER AND (
          finding.agent IN {qa-security, qa-architect}
       OR (finding.agent == qa-browser AND finding.oracle_tier IN {L1, L2, L3-schema})
    )
    ```
  - Verdict branch: unchanged in shape (any BLOCKER → REJECT; veto-bearing → REJECT (VETO));
    updated to use the `veto_bearing` predicate.
  This satisfies V4 (Step 3 pseudocode names three agents, not two).

- **Step 2 "Deduplicate"** — tier-aware merge extension: when merging findings that carry Oracle
  Tiers, keep the strongest tier ONLY IF its citation survives the merge; otherwise keep the weakest
  cited tier. A merge must never manufacture blocking power that neither input had.

- **Step 4 "Group and Rank"** sort order (lines 96–104): change "Veto agent findings first
  (security, architect)" to "Veto-**bearing** findings first" so a `qa-browser` L1 BLOCKER sorts
  with security and architect BLOCKERs, while a `qa-browser` L4 WARNING does not.

- **Specialists Consulted table** in the report format: add `qa-browser` row. The `Veto` column
  MUST indicate `yes (tier-gated: L1/L2/L3-schema)`. `qa-visual` MUST remain `no`. This satisfies
  runtime-veto/spec.md §"qa-report specialist summary table includes qa-browser as a veto holder".

- **Step 5 / Report metadata**: extend metadata to include:
  - `veto-tiers: [{tier per veto-bearing finding}]` alongside `veto-agents`.
  - `oracle_tier_breakdown` field in the consensus summary.

- **Step 6 REJECT (VETO) text**: extend to name the tier so a reader can see why the evidence was
  authoritative ("qa-browser veto active — Oracle Tier {tier} — consensus override not permitted").

---

### [x] 2.6 Edit `skills/qa-init/SKILL.md` — Step 4: Runtime Preflight (Browser Backend)

**Spec**: runtime-preflight/spec.md — all requirements
**Design**: Sequence Diagram 1; Preflight outcome truth table; Preflight cache schema

Insert a new **Step 4: Runtime Preflight (Browser Backend)** between the current Step 3 and the
current Step 4 "Return Summary" (which renumbers to Step 5). The step executes as the LAST qa-init
step before the summary, satisfying runtime-preflight/spec.md §"Runtime preflight runs as the last
qa-init step".

**P0 — Bash availability check** (FIRST action in this step):
- Attempt `printf 'qase-bash-ok\n'` (or equivalent probe).
- If Bash unavailable: record `bash_available: false`, `runtime_available: false`,
  `unavailable_reason: "bash-unavailable"`. Surface note: "Runtime preflight skipped — no Bash tool
  available in this executor". Jump directly to P6 (persist). Do NOT attempt any agent-browser
  command. This satisfies runtime-preflight/spec.md §"Bash unavailability recorded as a distinct
  reason".

**P1 — Presence probe** (Bash available):
- `command -v agent-browser`.
- Not found: record `agent_browser.available: false`, `runtime_available: false`,
  `unavailable_reason: "agent-browser-not-installed"`. Surface install hint text (do NOT execute):
  `npm i -g agent-browser && agent-browser install`; on Linux hosts `agent-browser install
  --with-deps` may be required. Jump to P6.
- Note: `--version` is on the quarantine list. If verified at apply time via
  `agent-browser --version --help`, use it and record the version string in `agent_browser.version`.
  If unverified, fall back to `command -v` for detection and extract version from `doctor --json`
  output. This satisfies runtime-preflight/spec.md §"agent-browser detected by version command"
  using the verified-fallback path.

**P2 — Doctor check** (primary diagnostic):
- `agent-browser doctor --json`.
- Exit 0: record `doctor_result: passed`. Proceed to P3.
- Exit 1: record `doctor_result: failed` + failure detail from JSON. Fall back to P2b.
- Output unparseable: record `doctor_result: parse-error`. Fall back to P2b.
- **P2b fallback** — multi-name Chrome probe in order: `chromium`, `google-chrome-stable`,
  `google-chrome`, `chrome`. Stop at first hit. Record `chrome_binary.name` and
  `detection_mechanism: "chrome-probe-fallback"`. NEVER probe only a single name (false-negative
  risk per R4). If none found: record `chrome_binary.available: false`,
  `unavailable_reason: "no-chrome-binary"`, jump to P6.
  This satisfies runtime-preflight/spec.md §"Chrome binary found under a non-default name"
  and §"No Chrome binary found under any probed name".

**P3 — Smoke connection test** (the final authority):
- `S="$(agent-browser session id --scope worktree --prefix qase)"`.
- `agent-browser --session "$S" open` (no URL — launches, stays on about:blank).
- `agent-browser --session "$S" get url --json` → verify returns `{"url":"about:blank"}`.
- `agent-browser --session "$S" close`.
- All succeed: record `smoke_test: passed`, `runtime_available: true`.
- Any fail: record `smoke_test: failed`, `runtime_available: false`,
  `unavailable_reason: "smoke-test-failed"`, capture error in `smoke_test_error`.
  This is the installed-but-broken case the preflight exists to make loud.
  Satisfies runtime-preflight/spec.md §"Smoke test passes" and §"Smoke test fails despite doctor
  passing".

**P4 — Start-command hints** (SUGGEST, NEVER EXECUTE):
- Read `package.json` scripts.dev/start/serve; `Makefile` run/serve/dev targets; `Procfile` web:;
  `docker-compose.yml` service ports; `go.mod`/`main.go` port flag; `README` "Getting Started";
  `.env.example PORT=`.
- Record each as `{ command, source, likely_port }` under `detected_start_hints[]`.
- If none found: `detected_start_hints: []`, note in summary.
- NEVER execute any detected command.
  Satisfies runtime-preflight/spec.md §"App Start Command Detection".

**P5 — Cleanup-hook detection** (opportunistic):
- Look for a test-reset endpoint or script.
- Record as `detected_cleanup_hook: { kind, value }` or `null`.
- QASE will not invent cleanup, run migrations, or truncate tables.

**P6 — Persist cache**:
- `openspec` → write `qaspec/preflight-cache.yaml` with the full schema from persistence-contract.md.
- `engram` → `mem_save` with `topic_key: "qa-init/{project}/preflight"`.
- `none` → return inline only, note that cache was not persisted.
- Include `detection_mechanism` field: `"doctor"`, `"chrome-probe-fallback"`, or `"bash-unavailable"`.
  Satisfies runtime-preflight/spec.md §"Preflight cache includes the detection mechanism used".

**Extend all three return blocks** (lines 116–182, engram / openspec / none) to include a
`### Runtime Backend` section reporting: `runtime_available`, `unavailable_reason` (if any),
`detection_mechanism`, agent-browser version (if detected), and `detected_start_hints` (as a
suggestion list, never a command to run).

---

### [x] 2.7 Edit `skills/qa-visual/SKILL.md` — Preflight Gate, CLI Migration, and Oracle Tiers

**Spec**: browser-backend-migration/spec.md — command-mapping requirements (resize_page → set
viewport; emulate → set media); runtime-preflight/spec.md §"Subsequent qa-browser invocation reads
the preflight cache" (applies equally to qa-visual)
**Design**: Design §"Skill files" table (qa-visual rows); Evidence Artifact Layout (baselines/
visual-diffs); ADR-E (qa-visual reads cache, does not write it)

- **Step 1** — replace the Chrome DevTools MCP availability gate ("Verify Chrome DevTools MCP tools
  are available") with the **preflight-cache** gate:
  - Read the preflight cache from `qaspec/preflight-cache.yaml` (openspec) or
    `qa-init/{project}/preflight` (engram).
  - If cache absent/stale or `runtime_available: false`: return `status: skipped`,
    `verdict_contribution: CLEAN`, one INFO finding with the cached reason. Zero runtime findings.
  - If `runtime_available: true`: proceed.
  - Derive session: `S="$(agent-browser session id --scope worktree --prefix qase)"`.
  - Replace `navigate_page(url)` with `agent-browser --session "$S" open <url>`.
  - Replace `wait_for("load")` with `agent-browser --session "$S" wait --load networkidle`.
  - Replace `take_screenshot()` with `agent-browser --session "$S" screenshot <path>`.
  - Replace `take_snapshot()` with `agent-browser --session "$S" snapshot`.

- **Steps 2–5** — replace `evaluate_script()` with
  `agent-browser --session "$S" eval --stdin` (heredoc for complex scripts). Note: each eval call
  for Steps 2–5 should batch all needed checks into a single script to minimize round-trips
  (existing Rule retained).

- **Step 6 (Responsive Viewport Sweep)** — replace `resize_page(width, height)` with
  `agent-browser --session "$S" set viewport <width> <height>` (verified CLI form).
  Replace `wait_for("load")` with `agent-browser --session "$S" wait --load networkidle`.
  Replace reset line `resize_page(1440, 900)` with
  `agent-browser --session "$S" set viewport 1440 900`.

- **Step 8 (Animation Audit)** — deep-mode emulation: replace
  `emulate({ reducedMotion: "reduce" })` with `agent-browser --session "$S" set media light
  reduced-motion` (verified CLI form). Replace reset `emulate({ reducedMotion: "" })` with
  `agent-browser --session "$S" set media dark` (or the appropriate default scheme).

- **New step before Step 9 "Apply Dismissed Patterns"**: add baseline-regression step:
  - `agent-browser --session "$S" diff screenshot --baseline <file>` (verified per proposal R7
    resolution; command exists in agent-browser@0.32.2).
  - In `openspec` mode: baseline file is `qaspec/baselines/{page-slug}/{viewport}.png`; write
    diff output to `qaspec/reviews/{review-id}/visual-diffs/{page-slug}-{viewport}.png`.
  - In `engram` mode: baseline diffing is unavailable (engram stores markdown, not image bytes).
    State this as a limitation explicitly: "Visual baseline diff skipped in engram mode — engram
    stores markdown only. Use openspec mode for baseline regression." Do NOT silently drop the step.

- **Every finding** gains an `**Oracle Tier**` field. `qa-visual` findings are predominantly L4
  (contrast ratios, spacing, motion heuristics); state the named WCAG SC or named standard as the
  citation per oracle-contract.md §"L4: a NAMED standard".

- **Metadata envelope**: add `oracle_tier_breakdown`, `flow-evidence: —`, `runtime-available: true`
  fields per issue-format.md extended envelope.

- **Safety Rules**: replace the exhaustive "Allowed MCP tools" list with the equivalent CLI-only
  list; remove all MCP tool names. Update depth-controls table to replace "Approximate MCP calls"
  row with "Approximate CLI calls".

---

## Phase 3: Peripheral Updates (README, Registry, Linter Pass)

Tasks 3.1 and 3.2 are independent and may run in parallel. Task 3.3 runs after 3.1 and 3.2.

---

### [x] 3.1 Edit `README.md`

**Spec**: browser-backend-migration/spec.md §"Zero 'Chrome DevTools MCP' string references in
affected files and registry"
**Design**: File Changes table (README.md row)

- Remove every mention of "Chrome DevTools MCP" as a prerequisite.
- Replace with the agent-browser + Bash requirement: "Runtime browser testing requires
  `agent-browser` CLI (`npm i -g agent-browser && agent-browser install`) and a Bash tool available
  to the executor. Run `/qa-init` to confirm runtime availability."
- Update the runtime-specialist section to describe agent-browser CLI as the backend.

---

### [x] 3.2 Regenerate `.atl/skill-registry.md`

**Spec**: browser-backend-migration/spec.md §"Skill-Registry Entry Updated"
**Design**: File Changes table (.atl/skill-registry.md row)

- The `qa-browser` row (currently line 92) describes the backend as "via Chrome DevTools MCP".
  Update to describe the agent-browser CLI.
- The `qa-visual` row (currently line 101) describes the backend as "via Chrome DevTools MCP".
  Update to describe the agent-browser CLI.
- Regenerate the registry fully if the registry file has a generation mechanism; otherwise edit the
  two rows in place.
- Verify: `rg -ni "chrome devtools mcp" .atl/skill-registry.md` must return zero matches.

---

### [x] 3.3 Run Linter Pass and Verify All Touched Skills

**Spec**: proposal §"Contract integrity", success criteria 1 and 2
**Design**: File Changes table; linter check from `scripts/lint_skills.sh`

- Run `bash scripts/lint_skills.sh`.
- Expected: ALL PASSED; zero FAIL entries.
- For each touched SKILL.md (`qa-init`, `qa-browser`, `qa-visual`, `qa-report`), verify:
  - Frontmatter delimiters `---` present at line 1 and as the second occurrence.
  - Fields `name`, `description`, `license` present in frontmatter.
  - Sections `## Purpose`, `## Execution and Persistence Contract`, `## What to Do`, `## Rules`
    present.
  - Reference to `persistence-contract.md` present.
- Run `bash scripts/install_test.sh`.
- Expected: exits 0.

---

## Phase 4: Verification

Tasks 4.1–4.5 are independent mechanical checks; run them in parallel where tooling allows.
Tasks 4.6 and 4.7 depend on all Phase 2–3 work being complete.

---

### [x] 4.1 Verify Zero MCP Tool References

**Spec**: browser-backend-migration/spec.md §"Zero MCP tool references in affected skill files"

Run:
```
rg -n "navigate_page|take_snapshot|take_screenshot|evaluate_script|wait_for|resize_page|list_console_messages|list_network_requests|get_network_request|get_console_message|performance_start_trace|performance_stop_trace|performance_analyze_insight|emulate\(" skills/
```
Expected: zero matches. Any match is a CRITICAL failure.

---

### [x] 4.2 Verify Zero "Chrome DevTools MCP" References

**Spec**: browser-backend-migration/spec.md §"Zero 'Chrome DevTools MCP' string references"

Run:
```
rg -ni "chrome devtools mcp" skills/ README.md .atl/skill-registry.md
```
Expected: zero matches.

---

### [x] 4.3 Verify Veto Count

**Spec**: runtime-veto/spec.md §"qa-browser SKILL.md frontmatter declares veto_power: true";
proposal success criterion 3

Run:
```
rg -n "veto_power: true" skills/
```
Expected: exactly three matches — `qa-security`, `qa-architect`, `qa-browser`. Any other count is
a failing verification.

---

### [x] 4.4 Verify wait --load Correctness

**Spec**: browser-backend-migration/spec.md §"wait --load networkidle is the only valid
wait-for-load form"

Run:
```
rg -n "wait networkidle" skills/
```
Expected: zero matches. Every load-state wait must use `wait --load {state}`.

---

### [x] 4.5 Verify qa-browser Veto Scope in severity-contract.md

**Spec**: runtime-veto/spec.md §"severity-contract.md veto table contains a row for qa-browser";
design sync invariant V2

Manually inspect `skills/_shared/qase/severity-contract.md`:
- A `qa-browser` row exists in the veto table.
- That row's Veto Scope column contains the phrases "L1, L2, or L3-schema" and "L3-inferred or L4
  NEVER carry veto".
- The verdict logic block contains Gate 1 (tier ceiling) preceding Gate 2 (veto predicate).
- `veto_power: true` in `skills/qa-browser/SKILL.md` and the qa-browser veto table row are
  both present (V1+V2 sync).

---

### [x] 4.6 Verify Oracle Contract Threading (All Five Shared Contracts)

**Spec**: oracle-contract/spec.md §"All five other shared contracts reference oracle-contract.md"

Check that each of the following files contains a reference to `oracle-contract.md`:
- `skills/_shared/qase/persistence-contract.md`
- `skills/_shared/qase/engram-convention.md`
- `skills/_shared/qase/openspec-convention.md`
- `skills/_shared/qase/routing-rules.md`
- `skills/_shared/qase/severity-contract.md`

Run:
```
rg -l "oracle-contract\.md" skills/_shared/qase/
```
Expected: all five files appear in the output.

---

### [x] 4.7 Verify Global-Flag Ordering in All Touched Skill Files

**Spec**: browser-backend-migration/spec.md §"Global flags precede the subcommand in all
session-bearing commands"

Run:
```
rg -n "agent-browser [^-].*--session" skills/qa-browser/SKILL.md skills/qa-visual/SKILL.md skills/qa-init/SKILL.md
```
Expected: zero matches. Every `--session` occurrence MUST follow the pattern
`agent-browser --session "$S" <subcommand>`, never `agent-browser <subcommand> --session`.

---

### [x] 4.8 Verify oracle-contract.md Blocking Matrix is Verbatim

**Spec**: oracle-contract/spec.md §"Blocking matrix governs which tiers may produce BLOCKER" —
"this table MUST appear verbatim in oracle-contract.md"

Manually verify that `skills/_shared/qase/oracle-contract.md` contains a blocking matrix table with
rows for L1, L2, L3-schema, L3-inferred, and L4 and the correct may/must-not assertions.

---

## Phase Summary

| Phase | Tasks | Parallelism |
|-------|-------|-------------|
| 1 — Infrastructure | 1.1–1.7 | 1.1 first; 1.2–1.7 in parallel after 1.1 |
| 2 — Implementation | 2.1–2.7 | All in parallel; 2.1 and 1.2 must be committed atomically |
| 3 — Peripheral | 3.1–3.3 | 3.1 and 3.2 in parallel; 3.3 after 3.1 and 3.2 |
| 4 — Verification | 4.1–4.8 | 4.1–4.7 in parallel; 4.8 manual check |

Total tasks: **25** (7 infrastructure + 7 implementation + 3 peripheral + 8 verification).

Note: the original design estimated 22 tasks (with Phase 4 = 5 tasks: 4.1–4.5). During the tasks
phase, Phase 4 was expanded to 8 tasks (4.1–4.8) adding 4.6 (oracle contract threading), 4.7
(global-flag ordering), and 4.8 (blocking matrix verbatim). The total is 25, not 22. The
"apply-progress reported 22" discrepancy (W5) reflects this: the progress artifact was written
against the original 22-task plan; Phase 4 tasks 4.6–4.8 were executed and confirmed passing but
were counted under the remediation batch, not the original task count.

Critical single-commit constraint: task 2.1 (`veto_power: true` in frontmatter) and the qa-browser
veto row from task 1.2 MUST land in the same git commit (design sync invariant V1+V2).

---

## Review Workload Forecast

**Estimated changed lines** (per-file breakdown):

| File | Action | Estimated Changed Lines |
|------|--------|------------------------|
| `skills/_shared/qase/oracle-contract.md` | Create (new) | ~120 |
| `skills/_shared/qase/severity-contract.md` | Modify | ~55 |
| `skills/_shared/qase/issue-format.md` | Modify | ~60 |
| `skills/_shared/qase/persistence-contract.md` | Modify | ~40 |
| `skills/_shared/qase/engram-convention.md` | Modify | ~30 |
| `skills/_shared/qase/openspec-convention.md` | Modify | ~35 |
| `skills/_shared/qase/routing-rules.md` | Modify | ~25 |
| `skills/qa-browser/SKILL.md` | Modify (heavy) | ~290 |
| `skills/qa-visual/SKILL.md` | Modify | ~65 |
| `skills/qa-init/SKILL.md` | Modify | ~80 |
| `skills/qa-report/SKILL.md` | Modify | ~35 |
| `README.md` | Modify | ~15 |
| `.atl/skill-registry.md` | Modify (2 rows) | ~6 |

**Estimated total changed lines**: ~856

**400-line budget risk**: High (estimated ~856 changed lines; more than twice the budget).

**Chained PRs recommended**: Yes

**Decision needed before apply**: Yes — the orchestrator must choose a PR-splitting strategy before
`sdd-apply` begins.

---

### Proposed Slice Boundaries

Each slice is independently verifiable, independently revertible, and carries its own linter gate.

**Slice 1 — Shared Contract Foundation**
Tasks: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7 (all Phase 1)
Files: `oracle-contract.md` (new), `severity-contract.md`, `issue-format.md`,
`persistence-contract.md`, `engram-convention.md`, `openspec-convention.md`, `routing-rules.md`
Estimated changed lines: ~365
Start: 1.1 is the first task; the remaining six may proceed in parallel.
Finish: all seven tasks complete; all five shared contracts reference `oracle-contract.md`.
Verify: `rg -l "oracle-contract\.md" skills/_shared/qase/` returns all five contract files.
`bash scripts/lint_skills.sh` passes (no skill file is touched in this slice; linter scope is
`skills/qa-*/SKILL.md`, which this slice does not touch).
`bash scripts/install_test.sh` passes.
Rollback: `git revert <slice-1-sha>`; delete `oracle-contract.md` if left untracked.

**Slice 2 — Runtime Preflight and qa-init**
Tasks: 2.6
Files: `skills/qa-init/SKILL.md`
Estimated changed lines: ~80
Dependency: Slice 1 merged (qa-init references persistence-contract.md for the cache schema).
Start: reads the updated `persistence-contract.md` for schema; writes Step 4 into qa-init.
Finish: Step 4 inserted; all three return blocks extended with Runtime Backend section.
Verify: `bash scripts/lint_skills.sh` passes for qa-init (all required sections present;
`persistence-contract.md` reference still present).
`agent-browser doctor --json` and smoke-test commands only come from the verified allowlist.
Rollback: `git revert <slice-2-sha>`.

**Slice 3 — qa-browser (CLI Migration + Flow Engine + Veto)**
Tasks: 2.1, 2.2, 2.3, 2.4 (and the veto-table row from 1.2 is the one line that MUST be included
in this commit to satisfy V1+V2 sync — apply the veto-table edit from 1.2 atomically here if 1.2
was not already committed with Slice 1, or verify V1+V2 are both in Slice 1; the cleanest path is
to include the qa-browser veto row in Slice 1 and the frontmatter change here)
Files: `skills/qa-browser/SKILL.md`, and the single qa-browser veto-row line in
`severity-contract.md` if not yet committed.
Estimated changed lines: ~290 (qa-browser) + the severity-contract row if deferred = ~295
Dependency: Slices 1 and 2 merged.
Start: 2.1 frontmatter change; then 2.2, 2.3, 2.4 in sequence (same file).
Finish: zero MCP tool references in qa-browser; veto_power: true; Step 9 flow engine complete;
depth controls updated.
Verify:
- `rg -n "veto_power: true" skills/` returns exactly 3 matches.
- `rg -n "navigate_page|take_snapshot|..." skills/qa-browser/SKILL.md` returns zero matches.
- `rg -n "wait networkidle" skills/qa-browser/SKILL.md` returns zero matches.
- `rg -n "agent-browser [^-].*--session" skills/qa-browser/SKILL.md` returns zero matches.
- `bash scripts/lint_skills.sh` passes for qa-browser.
Rollback: `git revert <slice-3-sha>`; also revert the veto-row line in severity-contract.md if
it was included here.

**Slice 4 — qa-visual, qa-report, README, Registry**
Tasks: 2.5, 2.7, 3.1, 3.2, 3.3, and all Phase 4 verification tasks
Files: `skills/qa-visual/SKILL.md`, `skills/qa-report/SKILL.md`, `README.md`,
`.atl/skill-registry.md`
Estimated changed lines: ~65 + ~35 + ~15 + ~6 = ~121
Dependency: Slices 1–3 merged.
Start: 2.5 (qa-report), 2.7 (qa-visual), 3.1 (README), 3.2 (registry) in parallel; 3.3 linter
pass after those four.
Finish: zero Chrome DevTools MCP references anywhere; oracle contract threaded end to end; all
verification tasks passing.
Verify: all Phase 4 tasks (4.1–4.8) pass.
`bash scripts/lint_skills.sh` passes for all skills.
`bash scripts/install_test.sh` passes.
Rollback: `git revert <slice-4-sha>`.
