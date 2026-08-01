# Apply Progress: runtime-routing — PR 1 (Phases 1–2)

**Change**: `runtime-routing`
**PR scope**: PR 1 — Phases 1 and 2 only (tasks 1.1–2.9)
**Mode**: Standard (no strict TDD applicable to markdown skill files)
**Delivery**: stacked-to-main; branch `feat/GS-runtime-routing`

---

## Completed Tasks

### Phase 1: Infrastructure (Contracts and Ownership Registry)

- [x] **1.1** Edit `skills/_shared/qase/routing-rules.md`: deleted `## Out-of-Band Specialists` section; added `## Runtime Recommendation` with trigger table (ui→browser+visual, api→browser, auth→browser, business→no, others→no), the `runtime_recommendation` manifest block (all 5 keys), and the no-auto-start literal `MUST NOT execute detected_start_hints[].command`. Verified: `rg -n 'Out-of-Band' skills/_shared/qase/routing-rules.md` → 0 matches.

- [x] **1.2** Edit `skills/_shared/qase/severity-contract.md`: added `UNVERIFIED` to `verdict_contribution` enum with full description; appended `### Runtime Coverage Suffix` section under Verdict Logic with `runtime_suffix()` pseudocode, `rendered_verdict` formula, and `(STATIC ONLY)` ownership note. Verified: `rg -c 'UNVERIFIED' skills/_shared/qase/severity-contract.md` = 2.

- [x] **1.3** Edit `skills/_shared/qase/persistence-contract.md`: rewrote the refusal rule to make `verdict_contribution` launch-context-dependent (UNVERIFIED when `launched_under_recommendation: true`, CLEAN otherwise, R5 containment noted); appended `## Review-Scoped Runtime Coverage` section with 9-value `runtime_unverified_reason` enum. Preflight schema, truth table, and `unavailable_reason` enum untouched. Byte-identity verified: `diff /tmp/before_truth_table /tmp/after_truth_table` → empty.

- [x] **1.4** Edit `skills/_shared/qase/rule-ownership.md`: added `<!-- coherence:table required -->` section with 4 rows (orch-no-auto-start, orch-url-flag, orch-url-precedence, orch-runtime-step, each pinned to all 6 orchestrator doc paths, min_count: 1); added `{runtime_suffix}` as `class: derived` (owner `severity-contract.md`, anchor `### Runtime Coverage Suffix`); added `{triggering-categories}` and `{runtime-reason}` as `class: descriptive`. (Note: `no-auto-start` and `static-only-qualifier` rows were pre-existing in the rules table from prior setup.)

### Phase 2: Core Implementation (Skills and Agent Envelopes)

- [x] **2.1** Edit `skills/qa-scan/SKILL.md`: added Step 4b "Produce Runtime Recommendation" between Step 4 and Step 5, with trigger evaluation logic, `runtime_recommendation` block template, and no-availability-assertion constraint; updated Step 7 envelope to include `runtime_recommendation` block. Verified: `rg -n 'runtime_recommendation' skills/qa-scan/SKILL.md` ≥ 1.

- [x] **2.2** Edit `skills/qa-report/SKILL.md`: added Step 3b "Coverage Resolution" (between Step 3 and Step 4) with three-branch algorithm (not-required/verified/unverified); changed Step 6 verdict template line to `### Verdict: {verdict}{runtime_suffix}`; added `### Unverified Coverage` section template (emitted only when `runtime_coverage == unverified`); added `runtime_coverage` and `runtime_unverified_reason` metadata keys. Verified: template present with both tokens.

- [x] **2.3** Edit `skills/qa-browser/SKILL.md`: all 3 refusal branches updated to emit `verdict_contribution: UNVERIFIED (if launched_under_recommendation: true) | CLEAN (otherwise)`. The 3 fabrication guards "Do NOT fabricate findings from static reading" preserved. Verified: `rg -c 'Do NOT fabricate findings from static reading' skills/qa-browser/SKILL.md` == 3; no bare `verdict_contribution: CLEAN` in refusal branches.

- [x] **2.4** Edit `skills/qa-visual/SKILL.md`: same change as 2.3 — 3 refusal branches updated, CLEAN→UNVERIFIED under recommendation, 3 fabrication guards preserved. Verified: `rg -c 'Do NOT fabricate findings from static reading' skills/qa-visual/SKILL.md` == 3.

- [x] **2.5** Edit `skills/qa-init/SKILL.md`: added optional `runtime.base_url` field description in Step 4; added `runtime` block YAML schema example; added `runtime.base_url` to Step 5 summary output in all three mode branches. `SUGGEST ONLY — never run these` remains byte-identical at its own line. Verified: `rg -n 'runtime.base_url' skills/qa-init/SKILL.md` ≥ 1.

- [x] **2.6** Edit `agents/qa-scan.md`: added `runtime_recommendation` forwarded advisory block to result contract. Verified: `rg -n 'runtime_recommendation' agents/qa-scan.md` ≥ 1.

- [x] **2.7** Edit `agents/qa-browser.md`: added `UNVERIFIED` to `verdict_contribution` result-contract enum. Verified: `rg -n 'UNVERIFIED' agents/qa-browser.md` ≥ 1.

- [x] **2.8** Edit `agents/qa-visual.md`: added `UNVERIFIED` to `verdict_contribution` result-contract enum. Verified: `rg -n 'UNVERIFIED' agents/qa-visual.md` ≥ 1.

- [x] **2.9** Edit `agents/qa-report.md`: added `runtime_coverage` (enum: verified/not-required/unverified) and `runtime_unverified_reason` to result contract. Verified: `rg -n 'runtime_coverage' agents/qa-report.md` ≥ 1.

---

## Files Changed

| File | Action | Description |
|------|--------|-------------|
| `skills/_shared/qase/routing-rules.md` | Modified | Replaced Out-of-Band section with Runtime Recommendation section, trigger table, manifest block, and no-auto-start literal |
| `skills/_shared/qase/severity-contract.md` | Modified | Added UNVERIFIED to verdict_contribution enum; appended Runtime Coverage Suffix section |
| `skills/_shared/qase/persistence-contract.md` | Modified | Rewrote refusal rule (launch-context-dependent); appended Review-Scoped Runtime Coverage section with 9-value enum |
| `skills/_shared/qase/rule-ownership.md` | Modified | Added `required` table (4 rows); added `{runtime_suffix}` derived placeholder and 2 descriptive placeholders |
| `skills/qa-scan/SKILL.md` | Modified | Added Step 4b (Runtime Recommendation); updated return envelope |
| `skills/qa-report/SKILL.md` | Modified | Added Step 3b (Coverage Resolution); two-token verdict template; Unverified Coverage section; 2 metadata keys |
| `skills/qa-browser/SKILL.md` | Modified | 3 refusal branches updated: UNVERIFIED under recommendation, CLEAN otherwise |
| `skills/qa-visual/SKILL.md` | Modified | Same as qa-browser |
| `skills/qa-init/SKILL.md` | Modified | Optional `runtime.base_url` in project context schema and Step 5 summaries |
| `agents/qa-scan.md` | Modified | Added `runtime_recommendation` forwarded field to result contract |
| `agents/qa-browser.md` | Modified | Added `UNVERIFIED` to verdict_contribution enum |
| `agents/qa-visual.md` | Modified | Added `UNVERIFIED` to verdict_contribution enum |
| `agents/qa-report.md` | Modified | Added `runtime_coverage` and `runtime_unverified_reason` to result contract |

---

## Verification Evidence

```
bash scripts/lint_skills.sh   → PASS: 121, FAIL: 0
bash scripts/install_test.sh  → PASS: 20, FAIL: 0
bash scripts/coherence_test.sh → PASS: 4, FAIL: 0

rg -c 'UNVERIFIED' agents/
  agents/qa-visual.md:1
  agents/qa-browser.md:1
  agents/qa-scan.md:1
  (exactly 3 intended agents — qa-report gets UNVERIFIED in Phase 4/C10e)

Byte-identity proof (truth table):
  diff /tmp/before_truth_table /tmp/after_truth_table → empty (PASS)

Coherence can-fail proof:
  Removed qa-advocate from positive fixture → FAILED
  Restored qa-advocate → PASSED

Orchestrator documents untouched:
  git diff --name-only HEAD -- examples/ → (no output)
```

---

## Remaining Tasks (PR 2)

- [ ] **3.1–3.6** Phase 3: Integration (Orchestrator Documents) — E1–E6 edits to all 6 examples
- [ ] **4.1–4.4** Phase 4: Tooling (C9/C10 coherence checks + fixtures)
- [ ] **5.1–5.5** Phase 5: Testing and Verification
- [ ] **6.1–6.3** Phase 6: Documentation and Registry

---

## Deviations from Design

None — implementation matches design for Phases 1–2.

## PR 1 Inertness

PR 1 is genuinely inert: no orchestrator document (examples/) was modified. All 13 files changed are contracts (skills/_shared/qase/), skills (skills/qa-*/), or agent envelopes (agents/). The orchestrator reads none of these files directly — it reads the orchestrator documents in examples/. Until Phase 3 lands, no orchestrator behaviour changes.

## Status

13/27 tasks complete (tasks 1.1–2.9). Ready for verify on PR 1, then PR 2 implements Phases 3–6.
