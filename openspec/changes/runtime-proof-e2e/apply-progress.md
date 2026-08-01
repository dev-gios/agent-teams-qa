# Apply Progress: runtime-proof-e2e

**Change**: `runtime-proof-e2e`
**Artifact store**: openspec
**Delivery strategy**: single-pr, size:exception approved (~856 estimated changed lines)
**Apply batch**: 4 of 4 (third remediation batch — BLOCKER1, BLOCKER2, W3, W4-L2-oracle, W5-session, W6-gate1, S7-LCP fixes)
**Status**: COMPLETE — all 25 tasks done + 9 first-remediation fixes + 5 second-remediation fixes + 7 third-remediation fixes

---

## Task Completion

### Phase 1: Infrastructure

- [x] 1.1 Created `skills/_shared/qase/oracle-contract.md` (new file, ~205 lines)
  - Sections: Purpose, The Four Tiers, Tier Population, Citation Requirements, Resolution Algorithm,
    Degradation and Absence, Blocking Matrix, Anti-Inflation Rules.
  - Blocking matrix is verbatim per oracle-contract/spec.md requirement.
  - Zero agent-browser commands in file (boundary B2 satisfied).
  - Single source of truth for tier semantics (boundary B3 satisfied).

- [x] 1.2 Edited `skills/_shared/qase/severity-contract.md`
  - Added `## Oracle Tier and Verdict` section before `## Veto Power`.
  - Changed "Two specialists" to "Three specialists have veto power — one of them conditionally".
  - Added qa-browser row to veto table (L1/L2/L3-schema only, never L3-inferred/L4). V2 satisfied.
  - Extended non-veto sentence to name qa-visual explicitly and qa-browser outside tier gate.
  - Replaced verdict logic with two-gate pseudocode (Gate 1: tier ceiling, Gate 2: veto predicate). R11 resolved.
  - Added `### Runtime findings` subsection to `## Severity Assignment Guidelines`.

- [x] 1.3 Edited `skills/_shared/qase/issue-format.md`
  - Added `**Oracle Tier**` field to both Browser and Visual Testing Variants (after `**Category**:`).
  - Added `#### Oracle Citation` subsection to both variants.
  - Added `## Flow Evidence Format` section with: per-step evidence table, flow document header block,
    Flow Summary table, Test Data Ledger format, Status value contract (PASS / FAIL — BLOCKER /
    FAIL — WARNING / INCONCLUSIVE; bare FAIL is never valid).
  - Extended Metadata Envelope with `oracle_tier_breakdown`, `flow-evidence`, `runtime-available` fields.
  - **REMEDIATION (W2)**: Changed `oracle-tier-breakdown` → `oracle_tier_breakdown` (underscore, spec-mandated form) in the metadata envelope and the prose reference.

- [x] 1.4 Edited `skills/_shared/qase/persistence-contract.md`
  - Added `## Runtime Preflight Cache` section with full YAML schema including `detection_mechanism` field.
  - Added single-writer rule (qa-init only), TTL/freshness rule (24h), refusal rule (status: skipped).
  - Added binary artifact rule to `## Common Rules` (binary bytes never stored in engram).
  - Added reference to `oracle-contract.md`.

- [x] 1.5 Edited `skills/_shared/qase/engram-convention.md`
  - Added reference to oracle-contract.md at top.
  - Added `### Flow Evidence (per-flow)` naming block.
  - Added preflight cache key to `### Project Init` block.
  - Added `flow-evidence` and `preflight-cache` rows to Artifact Types table.
  - Added NOTE about engram storing markdown only (binary bytes not stored).

- [x] 1.6 Edited `skills/_shared/qase/openspec-convention.md`
  - Added reference to oracle-contract.md at top.
  - Updated Directory Structure: added `preflight-cache.yaml`, `baselines/`, `visual-diffs/`,
    `flow-evidence/` subtree (full binary artifact layout).
  - Updated Artifact File Paths table.
  - Added Writing Rules for baselines (must live at `qaspec/baselines/`, never inside review dirs),
    visual-diffs, and flow-slug naming convention.

- [x] 1.7 Edited `skills/_shared/qase/routing-rules.md`
  - Added reference to oracle-contract.md.
  - Rewrote Out-of-Band Specialists table with Backend / Oracle Tiers / Veto columns.
  - Added preflight precondition bullet (status: skipped when cache absent/stale/runtime_available false).
  - Added `## Oracle-Tier-Aware Routing` section.

### Phase 2: Core Implementation

- [x] 2.1 Edited `skills/qa-browser/SKILL.md` — frontmatter `veto_power: true` + description
  - Changed `veto_power: false` to `veto_power: true`. V1 satisfied (with V2 from 1.2).
  - Updated description to remove Chrome DevTools MCP reference; added MCP exclusion statement.
  - Added oracle-contract.md reference and flow-evidence artifact type to Execution and Persistence Contract.

- [x] 2.2 Edited `skills/qa-browser/SKILL.md` — Steps 1–8 CLI migration + Oracle Tiers
  - Complete rewrite of Steps 1–8; all MCP tool calls replaced with CLI equivalents.
  - All commands from the verified allowlist; quarantined commands verified via --help before use.
  - Session derived as `S="$(agent-browser session id --scope worktree --prefix qase)"`.
  - `wait --load networkidle` used throughout.
  - Every finding carries Oracle Tier; WARNING cap at L4 and L3-inferred enforced.
  - `agent-browser --session "$S" vitals --json` verified via help output; used in Step 8.
  - `--version` flag verified to work; used as primary version probe in P1 (qa-init).

- [x] 2.2-REMEDIATION (C1 + C2 + C5):
  - **C2**: Step 1 unreachable-URL handling changed from BLOCKER to WARNING at L4 (matching qa-visual:74).
    Executed output: `{"overflow":false,"scrollWidth":1280,"viewportWidth":1280}` exit=0
  - **C1 Step 4**: axe-core injection rewritten as async IIFE `(async () => { ... })()` with `s.id = 'axe-core-script'` set.
    Removed broken `wait "#axe-core-script"` line (C5). The IIFE awaits `s.onload` internally.
    Executed output: axe.run() returned violations=4, passes=1, inapplicable=83 exit=0
  - **C1 Step 7**: responsive overflow script changed from `return {...};` to bare object expression `({...})`.
    Executed output: `{"overflow":false,"scrollWidth":1280,"viewportWidth":1280}` exit=0
  - **C1 Step 8**: vitals fallback changed from `return {...}` with async PerformanceObserver
    (which blocks indefinitely on already-loaded pages) to synchronous `getEntriesByType()` calls.
    Executed output: `{"cls":0,"fcp":null,"lcp":null}` exit=0 (null is correct on about:blank)

- [x] 2.2-REMEDIATION (W2): `oracle-tier-breakdown` → `oracle_tier_breakdown` in qa-browser metadata envelope.

- [x] 2.2-REMEDIATION (W3): Rewrote `wait networkidle` prohibition rule to not contain the literal invalid form.
    `rg -n "wait networkidle" skills/` → exit=1 (zero matches confirmed).

- [x] 2.2-REMEDIATION (W6): Added `cookies get/set/clear` command block to Step 5 (Interactive Element Testing).
    The cookies scenario from browser-backend-migration/spec.md is now implemented. `agent-browser cookies --help` confirmed.

- [x] 2.3 Edited `skills/qa-browser/SKILL.md` — Step 9 Flow Engine
  - Full per-step loop: F0 precondition → F1 oracle sourcing → F2 session+run setup → F3 flow open →
    S1–S11 per-step loop → F4 teardown → F5 summary+persist.
  - S1 buffer isolation (console/errors/network --clear before each step).
  - S2 optional fault injection with network route/unroute.
  - S3–S11: act, settle, observe, harvest, capture, resolve, classify, teardown, emit evidence row.
  - Daemon reconnection branch implemented.
  - QASE_RUN_ID template: `{epoch-seconds}-{6 lowercase hex}`.
  - Write-flow safety rules documented: production write flows refused, opt-in only, unique identities,
    never `close --all`.
  - `close --all` explicitly prohibited.
  - `unroute` failure aborts flow (contaminated network layer reasoning documented).

- [x] 2.4 Edited `skills/qa-browser/SKILL.md` — Report Format, Depth Controls, Safety Rules
  - Added `oracle_tier_breakdown`, `flow-evidence`, `runtime-available` to metadata envelope.
  - Updated Depth Controls table: concise/standard/deep artifact scope defined for new evidence types.
  - Safety Rules extended: write-flow rules, production refusal, never `close --all`.

- [x] 2.5 Edited `skills/qa-report/SKILL.md` — Tier-gated veto (R11 resolution)
  - Step 2: tier-aware merge extension (strongest tier survives only if citation survives).
  - Step 3: replaced two-agent pseudocode with two-gate model naming three agents (V4 satisfied).
  - Step 4: sort order updated to "veto-bearing findings first".
  - Specialists Consulted table: added qa-browser row (veto: yes tier-gated) and qa-visual row (veto: no).
  - Metadata block: added `veto-tiers` and `oracle_tier_breakdown` fields.

- [x] 2.5-REMEDIATION (W1): Updated qa-report Purpose (line 16) and VETO report template (line 165) to name
  qa-browser as the third veto holder. Previously only qa-security and qa-architect were mentioned in prose.

- [x] 2.6 Edited `skills/qa-init/SKILL.md` — Step 4: Runtime Preflight
  - Inserted new `### Step 4: Runtime Preflight (Browser Backend)` before old Step 4 (renumbered to Step 5).
  - P0: Bash availability check (probe → `bash_available: false` path if unavailable).
  - P1: presence probe via `command -v agent-browser`; `--version` used as primary version probe
    (verified to work); `doctor --json` as fallback for version extraction.
  - P2: `agent-browser doctor --json`; P2b Chrome fallback probe (chromium / google-chrome-stable /
    google-chrome / chrome in order; never single-name-only per R4).
  - P3: smoke test (`open`, `get url --json`, `close`); `runtime_available: true` only if all three pass.
  - P4: start-command hints (SUGGEST, NEVER EXECUTE).
  - P5: cleanup-hook detection (opportunistic).
  - P6: persist cache with `detection_mechanism` field.
  - All three return blocks (engram/openspec/none) extended with `### Runtime Backend` section.

- [x] 2.6-REMEDIATION (C4): Fixed P3 smoke test assertion.
  - Old (broken): "`get url --json` returns `{"url":"about:blank"}`"
  - New (correct): "JSON from `get url --json` contains `data.url == "about:blank"`"
  - Actual output confirmed: `{"success":true,"data":{...,"url":"about:blank"},"error":null}` exit=0
  - The url field is nested under `data`, not at the top level.

- [x] 2.7 Edited `skills/qa-visual/SKILL.md` — Preflight gate + CLI migration + Oracle Tiers
  - Step 1: replaced MCP availability gate with preflight-cache gate; all MCP calls → CLI equivalents.
  - Steps 2–5: `evaluate_script()` → `agent-browser --session "$S" eval --stdin` (heredoc form).
  - Step 6: `resize_page()` → `set viewport <w> <h>`; `wait_for("load")` → `wait --load networkidle`.
  - Step 8: `emulate()` → `set media light reduced-motion` / `set media dark`.
  - New Step 8b: `diff screenshot --baseline` in openspec mode only; engram limitation explicitly stated.
  - Every finding carries Oracle Tier (predominantly L4); WARNING cap enforced.
  - Metadata envelope extended. Safety Rules: replaced MCP tools list with CLI equivalents.
  - One stray `resize_page` reference in error handling text fixed during 4.1 verification sweep.

- [x] 2.7-REMEDIATION (C3): Reconciled five per-step BLOCKER instructions with the L4 WARNING cap at line 720:
  - Step 2 (design system): BLOCKER → WARNING for critical inconsistencies
  - Step 4 (color/contrast): BLOCKER × 2 → WARNING × 2 for sub-threshold contrast ratios
  - Step 6 (responsive): BLOCKER → WARNING for navigation/content unreachable at viewport
  - Step 7 (cross-viewport): BLOCKER → WARNING for navigation disappearing at any viewport
  - Each changed instruction includes the normative note: "(Oracle Tier L4 — BLOCKER is NOT permitted; WARNING is the L4 ceiling)"

- [x] 2.7-REMEDIATION (W2): `oracle-tier-breakdown` → `oracle_tier_breakdown` in qa-visual metadata envelope.

- [x] 2.7-REMEDIATION (W3): Rewrote `wait networkidle` prohibition rule to not contain the literal invalid form.

### Phase 3: Peripheral Updates

- [x] 3.1 Edited `README.md`
  - Removed all "Chrome DevTools MCP" references (tagline, runtime specialists section, commands
    table, Sub-Agents table, directory tree diagram, and the full "Runtime Prerequisites" section).
  - Updated tagline to reference agent-browser CLI + Bash instead of Chrome DevTools MCP.
  - Updated runtime specialists table: added Veto column, described agent-browser CLI as backend.
  - Updated commands table: added `[flows]` arg to `/qa-browser`, updated descriptions.
  - Updated veto power sentence to include qa-browser tier-gated mention.
  - Replaced "Runtime Prerequisites" section with agent-browser + Bash setup instructions.
  - Updated directory tree lines for qa-browser and qa-visual.

- [x] 3.2 Updated `.atl/skill-registry.md`
  - Updated qa-browser row (line 92): removed "Chrome DevTools MCP"; added agent-browser CLI description,
    tier-gated veto mention, flow execution, `/qa-init` prerequisite.
  - Updated qa-visual row (line 101): removed "Chrome DevTools MCP"; added agent-browser CLI description,
    no-veto note, `/qa-init` prerequisite.

- [x] 3.3 Ran linter pass
  - `bash scripts/lint_skills.sh`: 108 PASS, 0 FAIL — ALL PASSED (remediation batch).
  - `bash scripts/install_test.sh`: 12 PASS, 0 FAIL — ALL PASSED (remediation batch).

### Phase 4: Verification

- [x] 4.1 Zero MCP tool references: found 1 stray `resize_page` in qa-visual error handling text;
  fixed immediately. Re-run confirmed zero matches.
- [x] 4.2 Zero "Chrome DevTools MCP" references: found 2 in README directory tree; fixed. Zero matches.
- [x] 4.3 Veto count: exactly 3 matches — qa-security, qa-browser, qa-architect.
- [x] 4.4 No bare `wait networkidle`: **REMEDIATION** — rewrote prohibition text in qa-browser:500 and
  qa-visual:729 to not contain the literal invalid form. `rg -n "wait networkidle" skills/` → exit=1.
- [x] 4.5 qa-browser veto scope: L1/L2/L3-schema confirmed; "L3-inferred or L4 NEVER carry veto" present.
  V1+V2 sync confirmed (both frontmatter and table present together).
- [x] 4.6 Oracle contract threading: 6 files reference oracle-contract.md (all 5 shared contracts +
  oracle-contract.md itself is self-referential in the routing-rules check; all required files pass).
- [x] 4.7 Global-flag ordering: zero matches for bad ordering pattern.
- [x] 4.8 Blocking matrix verbatim: L1/L2/L3-schema = May; L3-inferred/L4/UNGROUNDED = Must NOT.

---

---

## Second Remediation Batch (W4, W5, W7, S1–S6)

### FIX 1 — axe-core onerror handler (highest priority)

- **What**: Replaced bare `new Promise(r => s.onload = r)` with a promise that has both `s.onload` (resolve) and `s.onerror` (reject), wrapped in `Promise.race` with a 10s timeout.
- **Where**: `skills/qa-browser/SKILL.md` Step 4 eval block
- **Also added**: `IF axeAvailable == false` instruction — accessibility audit MUST be recorded as SKIPPED with the reason surfaced; must NOT be reported as "no violations found".
- **Executed evidence**:
  - Success path (real CDN, https://example.com): `{"axeAvailable":true,"passes":13,"violations":2}` exit=0 (elapsed ~0.43s)
  - Failure path (`https://invalid.invalid/axe.min.js`): `{"axeAvailable":false,"reason":"axe-core unreachable at https://invalid.invalid/axe.min.js"}` exit=0 — **elapsed ~0.009s** versus previous hanging 15s before kill

### FIX 2 — W4: Steps 2–8 oracle resolution chain (not hardcoded L4)

- **What**: All seven steps (2–8) now instruct "run the resolution algorithm (oracle-contract.md L1→L2→L3-schema→L3-inferred→L4)" and explain *why* L4 is the default outcome for that step — with concrete examples of when L1/L2/L3 might apply instead.
- **Where**: `skills/qa-browser/SKILL.md` Steps 2, 3, 4, 5, 6, 7, 8
- **Verified**: `rg -n "run the resolution algorithm" skills/qa-browser/SKILL.md` → 7 matches (lines 94, 114, 171, 199, 233, 264, 312)
- **Note**: Where L4 genuinely is the only correct tier (WCAG heuristics, RFC 7231 semantics, CWV thresholds), kept L4 as the default outcome with explanation of why L1–L3 are absent.

### FIX 3 — W5: Task count mismatch resolved

- **What**: Updated tasks.md footer from "Total tasks: 22" to "Total tasks: 25" with an explanatory note.
- **Evidence**: tasks.md has 25 `[x]` task headers (1.1–1.7=7, 2.1–2.7=7, 3.1–3.3=3, 4.1–4.8=8). All 25 are verified complete. The "22" in the footer was a stale count from before Phase 4 expanded from 5 to 8 tasks. Tasks 4.6–4.8 (oracle threading, global-flag ordering, blocking matrix verbatim) were executed in batch 1 and confirmed passing; they were just not counted in the original total.
- **Where**: `openspec/changes/runtime-proof-e2e/tasks.md` line 873 (footer)

### FIX 4 — W7: vitals verified by execution; S5: CWV rendering fixed

- **Real vitals output** (executed live against https://example.com):
  ```
  {"success":true,"data":{"cls":{"entries":[],"score":0.0},"fcp":92.0,
   "hydratedComponents":[],"hydration":null,"inp":null,
   "lcp":{"element":"p","size":12461,"startTime":92,"url":null},
   "ttfb":65.3,"url":"https://example.com/"},"error":null}
  vitals exit=0
  ```
- **What changed**: Replaced "(verified via `agent-browser vitals --help`: falls through to top-level help, confirming vitals [url] [--json] is valid)" with the real output shape and field documentation.
- **S5 fix**: CWV table in Report Format now renders `data.lcp.startTime` (not `{value}s`), `data.cls.score` (not the object), `data.fcp`, `data.inp`. Added note: "lcp and cls are OBJECTS, not scalars" — the C4 failure class doesn't bite here.
- **Step 8 thresholds**: updated to use the real field paths (e.g., "LCP: Good < 2500ms (data.lcp.startTime)").
- **Where**: `skills/qa-browser/SKILL.md` Step 8 and Core Web Vitals report table

### FIX 5 — S1–S6 suggestions

- **S2 (severity-contract:117 "choose HIGHER" conflict)**: Added explicit carve-out: the "choose HIGHER" rule does NOT apply to runtime findings; the Oracle Tier ceiling is absolute. Added to `skills/_shared/qase/severity-contract.md`.
- **S3 (citation correctness)**: Added a comment block to qa-report Gate 1 noting that citation presence is gated, correctness is not — and referencing oracle-contract.md §Anti-Inflation Rule 5 as the human-reviewer backstop. `skills/qa-report/SKILL.md`.
- **S4 (stale-cache branch wording)**: Split the single `cache absent, stale, or runtime_available != true` branch into three distinct cases in both `qa-browser` and `qa-visual`. Stale case now uses the mandated wording: "runtime_available: unknown — preflight cache stale, re-run /qa-init". `skills/qa-browser/SKILL.md`, `skills/qa-visual/SKILL.md`.
- **S5 (CWV object shape)**: Addressed under FIX 4 above.
- **S6 (qa-visual eval --stdin canonical example)**: Added `### eval --stdin Canonical Form (applies to Steps 2–5)` section to `skills/qa-visual/SKILL.md` with both bare-expression and async-IIFE forms, and the explicit "return at top level is a syntax error" warning. `skills/qa-visual/SKILL.md`.
- **S1 (scroll in command-reference)**: Already done in previous batch (apply-progress deviation #10).

## Deviations and Notes

1. **qa-report in scope (approved deviation)**: The proposal table does not list qa-report, but the
   design confirmed its Step 3 duplicates the two-agent veto pseudocode inline. With qa-browser as a
   third tier-gated veto holder, that inline copy must be reconciled. Applied as approved deviation.

2. **`--version` flag verified**: The quarantine list flag `--version` was verified via direct invocation
   (`agent-browser --version` returns `agent-browser 0.32.2`). Used as primary version probe in qa-init
   P1; `doctor --json` retained as fallback only.

3. **`vitals` sub-command verified by execution**: `agent-browser vitals --json` executed live against
   `example.com`, exit 0. The previous apply recorded "verified via help" (insufficient); this batch
   records live execution.

4. **`diff screenshot --baseline` in openspec mode only**: This command was verified to exist in
   agent-browser@0.32.2. Implemented in qa-visual Step 8b. Engram limitation stated explicitly: "Visual
   baseline diff skipped in engram mode — engram stores markdown only."

5. **One stray `resize_page` in qa-visual error handling**: Found during 4.1 verification sweep. The text
   read "resize_page failure" in the Step 6 error handling block. Fixed to "`set viewport` failure"
   before the 4.1 check passed.

6. **Two stray "Chrome DevTools MCP" references in README directory tree**: Found during 4.2 sweep.
   Lines 632–633 contained comments in the file tree diagram. Fixed in the same pass.

7. **C1 vitals fallback redesigned**: The original `return {...}` form with `PerformanceObserver` was
   broken on two counts: `return` is a syntax error at top level in eval, AND async observers that
   listen for `largest-contentful-paint` never fire on already-loaded pages (they'd block the eval
   indefinitely). Fixed to synchronous `performance.getEntriesByType()` calls wrapped in a bare
   object expression. Executed: `{"cls":0,"fcp":null,"lcp":null}` exit=0.

8. **C5 fix merged into C1 Step 4 fix**: The broken `wait "#axe-core-script"` line (C5) was caused by the
   injection script never setting `s.id`. The IIFE rewrite sets `s.id = 'axe-core-script'` and awaits
   `onload` internally, making the external wait line both redundant and removable. Both C1 Step 4 and
   C5 are resolved by the same IIFE rewrite.

9. **W6 implemented**: `cookies get/set/clear` commands added to Step 5 (Interactive Element Testing)
   with a Cookie management block, making the browser-backend-migration spec scenario concretely met.
   Verified: `agent-browser cookies --help` confirms the operations exist.

10. **scroll added to command-reference doc (S1)**: Added a dedicated `## agent-browser scroll` section
    sourced from `agent-browser scroll --help` output.

---

## Files Changed

| File | Action |
|------|--------|
| `skills/_shared/qase/oracle-contract.md` | Created (new file) |
| `skills/_shared/qase/severity-contract.md` | Modified (S2: "choose HIGHER" carve-out for runtime findings) |
| `skills/_shared/qase/issue-format.md` | Modified (W2 remediation: oracle_tier_breakdown) |
| `skills/_shared/qase/persistence-contract.md` | Modified |
| `skills/_shared/qase/engram-convention.md` | Modified |
| `skills/_shared/qase/openspec-convention.md` | Modified |
| `skills/_shared/qase/routing-rules.md` | Modified |
| `skills/qa-browser/SKILL.md` | Modified (C1/C2/C5/W2/W3/W6 + FIX1 onerror + FIX2 oracle chain + FIX4 vitals + S4 stale-cache) |
| `skills/qa-visual/SKILL.md` | Modified (C3/W2/W3 + S4 stale-cache wording + S6 eval --stdin canonical example) |
| `skills/qa-init/SKILL.md` | Modified (C4 remediation) |
| `skills/qa-report/SKILL.md` | Modified (W1 + S3 citation correctness note) |
| `README.md` | Modified |
| `.atl/skill-registry.md` | Modified (2 rows) |
| `openspec/changes/runtime-proof-e2e/tasks.md` | Updated (footer count corrected: 22→25, W5) |
| `openspec/changes/runtime-proof-e2e/apply-progress.md` | Updated (this file, batch 3) |
| `openspec/changes/runtime-proof-e2e/agent-browser-command-reference.md` | Modified (scroll section added) |

---

## Live Execution Evidence (first remediation batch)

| Test | Script / Command | Output | Exit |
|------|-----------------|--------|------|
| C4 verify | `agent-browser --session "$S" get url --json` | `{"success":true,"data":{...,"url":"about:blank"},"error":null}` | 0 |
| C1/C5 Step 4 IIFE | async IIFE with `s.id`, `s.onload`, `axe.run()` | `violations=4, passes=1, inapplicable=83` | 0 |
| C1 Step 7 | bare object expression `({scrollWidth, viewportWidth, overflow})` | `{"overflow":false,"scrollWidth":1280,"viewportWidth":1280}` | 0 |
| C1 Step 8 | `getEntriesByType` bare object expression | `{"cls":0,"fcp":null,"lcp":null}` | 0 |
| W3 check | `rg -n "wait networkidle" skills/` | zero matches | 1 (rg exit for no matches) |
| Linter | `bash scripts/lint_skills.sh` | PASS: 108, FAIL: 0 | 0 |
| Install test | `bash scripts/install_test.sh` | PASS: 12, FAIL: 0 | 0 |

## Live Execution Evidence (second remediation batch)

| Test | Script / Command | Output | Exit |
|------|-----------------|--------|------|
| FIX1 axe onerror — old code hang | bare `onload` IIFE + invalid CDN, timeout 15s | killed at 15s, exit 124 | 124 |
| FIX1 axe onerror — new success path | new IIFE + onerror + valid CDN | `{"axeAvailable":true,"passes":13,"violations":2}` ~0.43s | 0 |
| FIX1 axe onerror — new failure path | new IIFE + onerror + invalid CDN `https://invalid.invalid/axe.min.js` | `{"axeAvailable":false,"reason":"axe-core unreachable at ..."}` elapsed 0.009s | 0 |
| FIX4 vitals live execution | `agent-browser --session "$S" vitals --json` against example.com | `{"data":{"cls":{"entries":[],"score":0.0},"fcp":92.0,"lcp":{"element":"p","size":12461,"startTime":92,"url":null},"ttfb":65.3,...}}` | 0 |
| W4 oracle chain | `rg -n "run the resolution algorithm" skills/qa-browser/SKILL.md` | 7 matches (lines 94,114,171,199,233,264,312) | 0 |
| W5 count | `grep -c "^### \[x\]" openspec/changes/runtime-proof-e2e/tasks.md` | 25 | 0 |
| Veto invariant | `rg -n "veto_power: true" skills/` | 3 matches (qa-security, qa-browser, qa-architect) | 0 |
| Linter | `bash scripts/lint_skills.sh` | PASS: 108, FAIL: 0 | 0 |
| Install test | `bash scripts/install_test.sh` | PASS: 12, FAIL: 0 | 0 |

---

## Third Remediation Batch (BLOCKER1, BLOCKER2, W3, W4-L2, W5-session, W6-gate1, S7-LCP)

### BLOCKER1 — Triple contradiction about qa-visual BLOCKERs

- **What**: Removed `HAS_BLOCKERS` from verdict computation (Step 10), report template (BLOCKERs section removed), and `verdict_contribution` enum. Added explicit qa-visual BLOCKER carve-out to `severity-contract.md`. Added Gate 1 static-specialist exclusion to both `severity-contract.md` and `qa-report/SKILL.md`.
- **Verdict step fix**: stray BLOCKER now gets downgraded to WARNING with "tier-gate-violation" note.
- **Report template**: `#### BLOCKERs` section removed; comment added explaining its intentional absence.
- **Enum fix**: `"CLEAN" | "HAS_WARNINGS"` only — `HAS_BLOCKERS` absent with inline explanation.
- **Metadata fix**: `blockers: 0 (qa-visual MUST NOT produce BLOCKERs; always 0)`.
- **Status thresholds**: changed from 3-state to 2-state; third state (BROKEN/FAILING) noted as qa-report territory only.
- **Executed evidence**: `rg -n 'HAS_BLOCKERS' skills/qa-visual/SKILL.md` → 2 matches, both exclusionary

### BLOCKER2 — `<evid>` undefined

- **What**: Defined `FLOW_SLUG` (canonical kebab derivation from flow name) and `EVID` (`qaspec/reviews/${REVIEW_ID}/flow-evidence/${FLOW_SLUG}`) in F2 Session + Run Setup.
- **Session fix (W5)**: Changed `S="$(agent-browser session id ...)"` to `S="${S:-$(...)}"` with explanation: reuses auth session established in Step 1; fresh derivation loses auth cookies.
- **F3 fix**: `record start` now uses `"${EVID}/recordings/${FLOW_SLUG}.webm"`.
- **S7 fix**: screenshot now uses `"${EVID}/screenshots/step-NN.png"`.
- **F4 fix**: HAR stop now uses `"${EVID}/har/${FLOW_SLUG}.har"`.
- **Executed evidence**: `rg -c '<evid>' skills/qa-browser/SKILL.md` → exit=1 (zero matches)

### W3 — `{page-slug}` derivation algorithm

- **What**: Added `## Slug Derivation Algorithms` section to `skills/_shared/qase/openspec-convention.md` with canonical 6-step deterministic algorithms for both `{page-slug}` (from URL) and `{flow-slug}` (from flow name). Covers the root-path special case (`"root"`).
- **qa-visual ref**: Added inline algorithm summary in Step 8b where `{page-slug}` is first used.
- **qa-browser ref**: F2 now references `openspec-convention.md §Slug Derivation Algorithms` for `FLOW_SLUG`.

### RESOLVED (set media dark reset) — measured evidence + post-reset guard

- **What**: Replaced assertion comment with measured evidence; added a post-reset guard after `set media dark`.
- **Evidence embedded**: "Measured evidence: `set media dark` without `reduced-motion` clears the override — confirmed by live execution."
- **Post-reset guard**: eval `window.matchMedia('(prefers-reduced-motion: reduce)').matches` after reset. If `true` → report INFO "Reduced-motion emulation reset failed" and SKIP animation-duration check.

### W4-L2-oracle — L2 sourcing happens ONCE at Step 1b

- **What**: Added `### Step 1b: Global Oracle Sourcing` immediately after Step 1. L2 is executed exactly once here. Steps 2-8 now say "apply the resolution algorithm using the pre-computed oracle set from Step 1b. DO NOT execute L2 again."
- **Executed evidence**: `rg -n 'apply the resolution algorithm' skills/qa-browser/SKILL.md` → 7 matches (steps 2-8)

### W6-gate1 — Gate 1 static specialist exclusion

- **What**: Added to `severity-contract.md` Gate 1 pseudocode: "Gate 1 applies ONLY to runtime specialists: qa-browser and qa-visual. Static specialists carry NO Oracle Tier and MUST NOT have one inferred. Gate 1 is a NO-OP for static specialist findings."
- **qa-report mirror**: Same exclusion added to qa-report Step 3 Gate 1 comment.

### S7-LCP — LCP fallback null semantics documented

- **Executed evidence**: eval on about:blank after `wait --load networkidle` → `{"cls":0,"fcp":null,"lcp":null}` exit=0.
- **What**: Added `IMPORTANT — LCP fallback null semantics` block. Null MUST be reported as "LCP unavailable via fallback". NEVER report as "Good" or passing.

## Live Execution Evidence (third remediation batch)

| Test | Script / Command | Output | Exit |
|------|-----------------|--------|------|
| S7-LCP null | eval on about:blank after load | `{"cls":0,"fcp":null,"lcp":null}` | 0 |
| BLOCKER1 HAS_BLOCKERS | `rg -n 'HAS_BLOCKERS' skills/qa-visual/SKILL.md` | 2 matches (both exclusionary) | 0 |
| BLOCKER2 evid | `rg -c '<evid>' skills/qa-browser/SKILL.md` | exit=1 (zero matches) | 1 |
| W4-L2-oracle | `rg -n 'apply the resolution algorithm' skills/qa-browser/SKILL.md` | 7 matches (steps 2-8) | 0 |
| Veto invariant | `rg -n 'veto_power: true' skills/` | 3 matches (qa-security, qa-browser, qa-architect) | 0 |
| qa-browser line count | `wc -l skills/qa-browser/SKILL.md` | 663 (above ~600 extraction trigger — reported explicitly) | 0 |
| Linter | `bash scripts/lint_skills.sh` | PASS: 108, FAIL: 0 | 0 |
| Install test | `bash scripts/install_test.sh` | PASS: 12, FAIL: 0 | 0 |

## Updated Files (third remediation batch)

| File | Lines Before | Lines After |
|------|-------------|-------------|
| `skills/qa-browser/SKILL.md` | 595 | 663 |
| `skills/qa-visual/SKILL.md` | 771 | 803 |
| `skills/qa-report/SKILL.md` | 315 | 318 |
| `skills/_shared/qase/severity-contract.md` | 123 | 131 |
| `skills/_shared/qase/openspec-convention.md` | 128 | 164 |
