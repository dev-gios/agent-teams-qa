# Tasks: runtime-routing

**Change**: `runtime-routing`
**Phase**: tasks
**Spec sources**: runtime-recommendation, url-resolution, runtime-coverage-verdict, page-level-scope
**Verification commands**: `bash scripts/lint_skills.sh` · `bash scripts/install_test.sh` · `bash scripts/coherence_test.sh`
**Delivery**: separate branch per change; user preference is for manageable diffs.

---

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~760–940 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (contracts + skills + agents) → PR 2 (orchestrator docs + tooling + docs/registry) |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Per-File Estimate

| File / Group | Action | Est. Lines |
|---|---|---|
| `skills/_shared/qase/routing-rules.md` | Modify: delete Out-of-Band section, add Runtime Recommendation + trigger table + manifest block + no-auto-start literal | ~+80 / −30 net ~+50 |
| `skills/_shared/qase/severity-contract.md` | Modify: UNVERIFIED enum entry + `### Runtime Coverage Suffix` section | ~+30 |
| `skills/_shared/qase/persistence-contract.md` | Modify: append `## Review-Scoped Runtime Coverage` section + reword refusal | ~+40 |
| `skills/_shared/qase/rule-ownership.md` | Modify: +2 rules rows, new `required` table (4 rows), +3 placeholder rows | ~+25 |
| `skills/qa-scan/SKILL.md` | Modify: Step 4b + manifest block + envelope update | ~+40 |
| `skills/qa-report/SKILL.md` | Modify: Step 3b + two-token verdict line + Unverified Coverage section + 2 metadata keys | ~+60 |
| `skills/qa-browser/SKILL.md` | Modify: 3 refusal branches CLEAN → UNVERIFIED | ~+12 |
| `skills/qa-visual/SKILL.md` | Modify: 3 refusal branches CLEAN → UNVERIFIED | ~+12 |
| `skills/qa-init/SKILL.md` | Modify: optional `runtime.base_url` in project context + Step 5 summary | ~+15 |
| `agents/qa-scan.md` | Modify: result-contract enum (runtime_recommendation) | ~+8 |
| `agents/qa-browser.md` | Modify: result-contract enum (UNVERIFIED) | ~+6 |
| `agents/qa-visual.md` | Modify: result-contract enum (UNVERIFIED) | ~+6 |
| `agents/qa-report.md` | Modify: result-contract enums (runtime_coverage, runtime_unverified_reason) | ~+8 |
| `examples/claude-code/CLAUDE.md` | Modify: E1–E6 (6 edit sites) | ~+50 |
| `examples/vscode/copilot-instructions.md` | Modify: E1–E6 | ~+50 |
| `examples/cursor/.cursorrules` | Modify: E1–E6 | ~+50 |
| `examples/gemini-cli/GEMINI.md` | Modify: E1–E6 | ~+50 |
| `examples/codex/agents.md` | Modify: E1–E6 | ~+50 |
| `examples/antigravity/qase-orchestrator.md` | Modify: E1–E6 | ~+50 |
| `scripts/lib/coherence.sh` | Modify: add `check_c9_required_literal`, `check_c10_unverified_not_clean`, wire into `run_coherence_checks` | ~+90 |
| `scripts/coherence_test.sh` | Modify: 3 new fixture assertions | ~+45 |
| `scripts/fixtures/coherence/neg-missing-required-literal/` | Create: C9 negative fixture (one orchestrator doc missing the no-auto-start line) | ~+20 |
| `scripts/fixtures/coherence/neg-empty-required-table/` | Create: C9 negative fixture (required table absent) | ~+15 |
| `scripts/fixtures/coherence/neg-unverified-as-clean/` | Create: C10b + C10d negative fixture | ~+20 |
| `scripts/install_test.sh` | Modify: criterion-13 assertion (skills-only install exits 0, qa-report contains runtime_coverage) | ~+20 |
| `README.md` | Modify: `--url` flag, runtime routing description | ~+20 |
| `.atl/skill-registry.md` | Modify/regenerate: runtime-routing entries | ~+15 |

**Estimated total changed lines**: ~760–940 (well above the 400-line budget).

### Suggested Work Units

| Unit | Goal | PR | Base | Notes |
|------|------|----|------|-------|
| PR 1 | Contracts + skills + agent envelopes | PR 1 | main | All of Phase 1 + Phase 2; self-contained; linter passes on delivery |
| PR 2 | Orchestrator docs + tooling + docs/registry | PR 2 | PR 1 branch | Phase 3 + Phase 4 + Phase 5; depends on Phase 1 contracts being present |

---

## Phase 1: Infrastructure (Contracts and Ownership Registry)

Tasks 1.1–1.4 may proceed in parallel. All must complete before Phase 2 begins.

- [x] **1.1** Edit `skills/_shared/qase/routing-rules.md`: delete `## Out-of-Band Specialists` section (criterion 1); add `## Runtime Recommendation` with the trigger table (`ui`→browser+visual, `api`→browser, `auth`→browser, `business`→no explicit non-trigger, rest→no), the `runtime_recommendation` manifest block (keys: `recommended`, `reason`, `triggering_categories`, `specialists`, `candidate_targets`), and the single-source no-auto-start literal. Verify: `rg -n 'Out-of-Band' skills/_shared/qase/routing-rules.md` → 0 matches.

- [x] **1.2** Edit `skills/_shared/qase/severity-contract.md`: add `UNVERIFIED` to the `verdict_contribution` enum; append `### Runtime Coverage Suffix` section under Verdict Logic with the `runtime_suffix()` pseudocode and `rendered_verdict = base_verdict + runtime_suffix(...)`. Sole owner of `(STATIC ONLY)` literal. Verify: `rg -c 'UNVERIFIED' skills/_shared/qase/severity-contract.md` ≥ 1.

- [x] **1.3** Edit `skills/_shared/qase/persistence-contract.md`: append a new section `## Review-Scoped Runtime Coverage` with the 9-value `runtime_unverified_reason` enum (null + 4 value-copied preflight spellings + `preflight-cache-absent` + `preflight-cache-stale` + `no-url-resolved` + `user-declined`). Reword the refusal rule to make the contribution launch-context-dependent (UNVERIFIED only when `launched_under_recommendation: true`). The `## Runtime Preflight Cache` section, its truth table, and the `unavailable_reason` enum MUST NOT be touched. Verify byte-identity: run the `git show … | awk … | diff` command from design §B9 — diff MUST be empty.

- [x] **1.4** Edit `skills/_shared/qase/rule-ownership.md`: add 2 rows to the `rules` table (`no-auto-start` owned by `routing-rules.md` with `allow_count: 0`; `static-only-qualifier` owned by `severity-contract.md` with `allow_count: 0`); add a new `<!-- coherence:table required -->` section with 4 rows (orch-no-auto-start, orch-url-flag, orch-url-precedence, orch-runtime-step, each pinned to all 6 orchestrator doc paths, `min_count: 1`); add `{runtime_suffix}` as `class: derived` (owner `severity-contract.md`, anchor `### Runtime Coverage Suffix`) and `{triggering-categories}`, `{runtime-reason}` as `class: descriptive` to the `placeholders` table.

---

## Phase 2: Core Implementation (Skills and Agent Envelopes)

Tasks 2.1–2.9 may proceed in parallel after Phase 1 completes.

- [x] **2.1** Edit `skills/qa-scan/SKILL.md`: add Step 4b "Produce Runtime Recommendation" between the routing manifest step and the return step. The step evaluates detected categories against the trigger table (ui/api/auth trigger; business and others do not), emits the `runtime_recommendation` block with all 5 keys, and adds it to the return envelope. `qa-scan` MUST NOT assert `runtime_available` or resolve any URL. Verify: `rg -n 'runtime_recommendation' skills/qa-scan/SKILL.md` ≥ 1.

- [x] **2.2** Edit `skills/qa-report/SKILL.md`: add Step 3b "Coverage Resolution" (placed between Step 3 veto logic and Step 6 rendering) with the three-branch `runtime_coverage` algorithm (`not-required` / `verified` / `unverified`); change the Step 6 verdict template line to `### Verdict: {verdict}{runtime_suffix}` (two tokens); add the mandatory `### Unverified Coverage` report section template (triggering categories, specialists that did not run, reason, `/qa-browser <url>` closing command — emitted only when `runtime_coverage == unverified`); add metadata keys `runtime_coverage` and `runtime_unverified_reason`. Verify: `grep -qF '### Verdict: {verdict}{runtime_suffix}' skills/qa-report/SKILL.md`.

- [x] **2.3** Edit `skills/qa-browser/SKILL.md`: in all 3 refusal branches, change `verdict_contribution: CLEAN` to `verdict_contribution: UNVERIFIED` only when the context includes `launched_under_recommendation: true`; the standalone `/qa-browser <url>` refusal branch MUST keep `CLEAN` (R5 containment). The 3 occurrences of "Do NOT fabricate findings from static reading" MUST remain (C10c requires exactly 3). Verify: `rg -c 'Do NOT fabricate findings from static reading' skills/qa-browser/SKILL.md` == 3.

- [x] **2.4** Edit `skills/qa-visual/SKILL.md`: same change as 2.3 — 3 refusal branches, UNVERIFIED only under recommendation, 3 fabrication guards preserved. Verify: `rg -c 'Do NOT fabricate findings from static reading' skills/qa-visual/SKILL.md` == 3.

- [x] **2.5** Edit `skills/qa-init/SKILL.md`: add optional `runtime.base_url` field to the project context schema; amend Step 5 (context summary output) to include `runtime.base_url` when set. `SUGGEST ONLY — never run these` at line 158 MUST remain byte-identical. Verify: `rg -n 'runtime.base_url' skills/qa-init/SKILL.md` ≥ 1.

- [x] **2.6** Edit `agents/qa-scan.md`: add `runtime_recommendation` to the result-contract enum (the field the agent forwards, never emits as a verdict contribution). Verify: `rg -n 'runtime_recommendation' agents/qa-scan.md` ≥ 1.

- [x] **2.7** Edit `agents/qa-browser.md`: add `UNVERIFIED` to the `verdict_contribution` result-contract enum. Verify: `rg -n 'UNVERIFIED' agents/qa-browser.md` ≥ 1.

- [x] **2.8** Edit `agents/qa-visual.md`: add `UNVERIFIED` to the `verdict_contribution` result-contract enum. Verify: `rg -n 'UNVERIFIED' agents/qa-visual.md` ≥ 1.

- [x] **2.9** Edit `agents/qa-report.md`: add `runtime_coverage` (enum: verified/not-required/unverified) and `runtime_unverified_reason` to the result-contract. Verify: `rg -n 'runtime_coverage' agents/qa-report.md` ≥ 1.

---

## Phase 3: Integration (Orchestrator Documents)

Each orchestrator document is edited independently; task-per-document makes a partial landing visible. Apply E1–E6 to each file using that file's exact heading names, arrow conventions, and line anchors as documented in design §"Exactly What Changes". Do NOT normalize divergent conventions.

**TRAP**: Each file has different heading names, list lengths, and arrow conventions. CLAUDE.md uses `→`; cursor/.cursorrules, codex/agents.md, and vscode use `->`. CLAUDE.md section: `### Runtime Preflight Sequence (ADR-E')`; others: `### Runtime Preflight for qa-init (ADR-E')`. CLAUDE.md rules list ends at 9; others at 10. Do not homogenize.

- [x] **3.1** Edit `examples/claude-code/CLAUDE.md` (E1 Scope Syntax table row; E2 new `### Runtime URL Resolution (ADR-C)` section after ADR-F at line 177; E3 `Step 2b` in pipeline block at line 219; E4 two-token verdict heading + `**Runtime coverage**:` line at line 278; E5 Commands table `--url` + amend qa-browser row at line 52; E6 URL-scope note already present — verify it reads correctly).

- [x] **3.2** Edit `examples/vscode/copilot-instructions.md` (E1 at line 79; E2 after ADR-F at line 262; E3 at line 107; E4 at line 176; E5 at line 67; E6 add URL-scope note, ASCII `->` convention).

- [x] **3.3** Edit `examples/cursor/.cursorrules` (E1 at line 69; E2 after ADR-F at line 248; E3 at line 97; E4 at line 164; E5 at line 57; E6 add URL-scope note, ASCII `->` convention).

- [x] **3.4** Edit `examples/gemini-cli/GEMINI.md` (E1 at line 77; E2 after ADR-F at line 258; E3 at line 105; E4 at line 174; E5 at line 65; E6 add URL-scope note).

- [x] **3.5** Edit `examples/codex/agents.md` (E1 at line 77; E2 after ADR-F at line 258; E3 at line 105; E4 at line 174; E5 at line 65; E6 add URL-scope note, ASCII `->` convention).

- [x] **3.6** Edit `examples/antigravity/qase-orchestrator.md` (E1 at line 77; E2 after ADR-F at line 251; E3 at line 100; E4 at line 167; E5 at line 65; E6 add URL-scope note).

After 3.1–3.6: verify `rg -c 'Step 2b' examples/claude-code/CLAUDE.md examples/vscode/copilot-instructions.md examples/cursor/.cursorrules examples/gemini-cli/GEMINI.md examples/codex/agents.md examples/antigravity/qase-orchestrator.md` → all 6 show ≥ 1.

---

## Phase 4: Tooling (Coherence Enforcement)

Tasks 4.1 and 4.2 may proceed in parallel. Task 4.3 (fixtures) may also proceed in parallel. Task 4.4 (wiring) depends on 4.1 and 4.3.

- [x] **4.1** Edit `scripts/lib/coherence.sh`: add `check_c9_required_literal()` (mirrors C1's comma-split file loop with `grep -cF`; fails if `rows -eq 0` to prevent vacuous pass on reverted registry; reads the `required` table from `rule-ownership.md`); add `check_c10_unverified_not_clean()` with all 5 sub-assertions (a) equate-check, (b) refusal CLEAN, (c) 3 fabrication guards per runtime skill, (d) two-token template present + un-suffixed form absent, (e) R5 set containment = exactly {qa-browser, qa-report, qa-scan, qa-visual}); wire both into `run_coherence_checks()` after C8.

  **PROBE TRAP (from orchestrator)**: the reachability probe in Step 3 uses `agent-browser`, NOT `curl`. Key failure mode: `agent-browser --session "$S" open <url>` exits with code **1** on connection refused; however `agent-browser --session "$S" get url --json` returns `{"success":true,...}` even after a failed navigation. C9/C10 do NOT involve the probe directly, but any documentation or check that references probe behavior MUST key off the exit code of `open`, never off `success` in `get url --json`.

- [x] **4.2** Edit `scripts/install_test.sh`: add assertion for criterion 13 — a synthetic `qase.json` without `install_agents` block installs 12 skills, exits 0, and the installed `skills/qa-report/SKILL.md` contains the string `runtime_coverage`.

- [x] **4.3** Create 3 negative fixture directories under `scripts/fixtures/coherence/`:
  - `neg-missing-required-literal/` — one orchestrator doc stub that lacks the `orch-no-auto-start` literal, plus minimal `rule-ownership.md` `required` table. Running `check_c9_required_literal` MUST exit 1 with output containing `C9`.
  - `neg-empty-required-table/` — `rule-ownership.md` with a `required` table header but zero data rows. Running `check_c9_required_literal` MUST exit 1 with output containing `C9` (the `rows -eq 0` branch).
  - `neg-unverified-as-clean/` — `skills/qa-browser/SKILL.md` with `verdict_contribution: CLEAN` in a recommendation-scoped refusal branch AND `skills/qa-report/SKILL.md` with template line `### Verdict: {verdict}` (one token only). Running `check_c10_unverified_not_clean` MUST exit 1 with output containing `C10`.

- [x] **4.4** Edit `scripts/coherence_test.sh`: add 3 new fixture assertions after the existing 4, following the `assert_fail_with_check` pattern already present: (a) `neg-missing-required-literal` expects exit 1 + `C9`; (b) `neg-empty-required-table` expects exit 1 + `C9`; (c) `neg-unverified-as-clean` expects exit 1 + `C10`.

---

## Phase 5: Testing and Verification

Tasks 5.1–5.4 may run in parallel. Task 5.5 (system gate) runs last.

- [x] **5.1** Verify criterion 1: `rg -n 'Out-of-Band' skills/_shared/qase/routing-rules.md` → 0 matches.

- [x] **5.2** Verify criterion 2: trigger table in `routing-rules.md` contains exactly `ui`, `api`, `auth` as recommending categories; `business` appears with an explicit non-recommendation.

- [x] **5.3** Verify criterion 9 (byte-identity): run the `git show … | awk … | diff` command from `design.md §B9`. The diff MUST be empty. If any line changed in the preflight truth table or `unavailable_reason` enum, stop and fix task 1.3.

- [x] **5.4** Verify criteria 6 and 7: `rg -n 'verdict_contribution: CLEAN' skills/qa-browser/SKILL.md skills/qa-visual/SKILL.md` → 0 matches in recommendation-scoped branches; `rg -c 'Do NOT fabricate findings from static reading' skills/qa-browser/SKILL.md` == 3; same for `qa-visual/SKILL.md`.

- [x] **5.5** Run full gate: `bash scripts/lint_skills.sh && bash scripts/install_test.sh && bash scripts/coherence_test.sh` — all must exit 0. Any FAIL is a blocker.

---

## Phase 6: Documentation and Registry

Tasks 6.1 and 6.2 may proceed in parallel. Task 6.3 is the final gate.

- [x] **6.1** Edit `README.md`: add `--url` flag to the `/qa-review` command description; add a brief "Runtime Routing" section explaining the three-owner pipeline (recommend / decide / account) and noting that runtime specialists activate under a recommendation, not automatically.

- [x] **6.2** Regenerate `.atl/skill-registry.md`: update entries for `qa-scan`, `qa-report`, `qa-browser`, `qa-visual`, `qa-init` to reflect new capabilities; add note on the `--url` flag in the `/qa-review` command entry.

- [x] **6.3** Final linter + install-test gate (post-docs): `bash scripts/lint_skills.sh && bash scripts/install_test.sh && bash scripts/coherence_test.sh`. Both MUST exit 0 before the PR is marked ready.

---

## Phase Summary

| Phase | Tasks | Parallelism |
|---|---|---|
| 1 — Infrastructure | 1.1–1.4 | All 4 in parallel |
| 2 — Implementation | 2.1–2.9 | All 9 in parallel after Phase 1 |
| 3 — Integration | 3.1–3.6 | All 6 in parallel (one doc per task) |
| 4 — Tooling | 4.1–4.4 | 4.1–4.3 in parallel; 4.4 after 4.1 + 4.3 |
| 5 — Testing | 5.1–5.4 in parallel; 5.5 after all | |
| 6 — Docs/Registry | 6.1–6.2 in parallel; 6.3 after both | |

**Total tasks: 27** (4 infrastructure + 9 implementation + 6 integration + 4 tooling + 5 testing + 3 docs).

**PR 1 boundary**: Phases 1–2 (tasks 1.1–2.9). Self-contained; linter must pass.
**PR 2 boundary**: Phases 3–6 (tasks 3.1–6.3). Depends on PR 1 merged or on the PR 1 branch as base.

---

## Known Risks and Mitigations

| Risk | Task scope | Mitigation |
|---|---|---|
| **36 edit sites across 6 near-duplicate orchestrator docs** with divergent headings, arrow conventions, and rule-list lengths. A diff-and-paste approach will normalise conventions and break C9. | 3.1–3.6 | One task per document. Design §"Exactly What Changes" records exact anchor line numbers and naming traps per file. C9 fires after the edits are committed — it does not prevent a missed site, only surfaces it. |
| **`persistence-contract.md` preflight truth table** must remain byte-identical. Appending text above the table header shifts nothing, but an accidental whitespace edit inside the table body fails the diff check. | 1.3 | Task 1.3 targets only the APPEND operation. Task 5.3 is a dedicated byte-identity verification before any commit. |
| **`runtime_unverified_reason` scope pollution** — its new values (`no-url-resolved`, `user-declined`) must NOT enter the preflight `unavailable_reason` enum. | 1.3 | Explicitly stated in task 1.3. C10e does not check this directly; sdd-verify must run the criterion-9 diff check. |
| **Three-mechanism suffix (M1/M2/M3)** — implementing only one or two mechanisms leaves silent gaps. M1 is the template shape, M2 is the `{runtime_suffix}` derived-class registration (task 1.4), M3 is C10(d) (task 4.1). A task that covers only M1 has not implemented the decision. | 2.2, 1.4, 4.1 | Tasks 2.2 (M1), 1.4 (M2), and 4.1 (M3) are separate and all required. Task 5.5 runs C10(d) which is the M3 gate. |
| **Reachability probe tool** — design originally showed `curl`; orchestrator ruling settles on `agent-browser`. The trap is that `agent-browser get url --json` returns `success:true` even after a failed navigation. Any doc or check that references the probe must key off the exit code of `open`, not the `success` field. | 3.1–3.6, 4.1 | Recorded explicitly in task 4.1 and propagated via the E2 section in each orchestrator doc (tasks 3.1–3.6). |
| **C9 vacuous pass on reverted registry** — if the `required` table is removed but `check_c9` is still wired, the check reads 0 rows and exits 0. | 4.1 | The `rows -eq 0` branch in `check_c9_required_literal` must fail loudly. Mirrored in the `neg-empty-required-table` fixture (task 4.3). |
| **Criterion 12 deviation** — the linter cannot see a generated report; C10(d) asserts the template instead. | 4.1 | Deviation is documented in `design.md §C10`. The `neg-unverified-as-clean` fixture (task 4.3) proves C10(d) can fail. The deviation is accepted per the orchestrator's ruling ("accept the design's deviation"). |
| **Criterion 4 vs R5 tension** — per orchestrator ruling: R5 wins; `agents/qa-scan.md` does NOT get UNVERIFIED in its verdict-contribution enum. Task 2.6 adds `runtime_recommendation` to qa-scan (the field it forwards), not `UNVERIFIED`. C10(e) pins the set at exactly {qa-browser, qa-report, qa-visual} for emission, and qa-scan for forwarding. | 2.6, 4.1 | Task 2.6 scope is limited to `runtime_recommendation`; task 4.1 implements C10(e) with the four-agent set that includes qa-scan as the forwarder. |
