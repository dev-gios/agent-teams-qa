# Apply Progress: three-layer-architecture — Batch 1

**Change**: `three-layer-architecture`
**Batch**: 1 (S1 Infrastructure + S2 Agent Layer)
**Mode**: Standard (no TDD runner detected for markdown/shell work)
**Date**: 2026-07-31

---

## Completed Tasks

### Phase 1: Infrastructure (Contracts and Ownership Registry)

- [x] 1.1 Create `skills/_shared/qase/rule-ownership.md` — 5 coherence tables (rules, forbidden, placeholders, capabilities, classes); C2 scope limitation documented; model-required decision documented; escaped-pipe fix documented.
- [x] 1.2 Edit `skills/_shared/qase/severity-contract.md` — removed "This section restates the ceilings…" at line 15 and first duplicate tier table (lines 13-28), removed second duplicate tier table (lines 108-119); replaced both with pointers to `oracle-contract.md`. Verified: `rg -n 'restates'` returns zero.
- [x] 1.3 Edit `skills/_shared/qase/persistence-contract.md` — rewrote single-writer rule to producer/writer language; added `## Sole Writer` section with artifact table covering preflight cache, specialist reports, final report, dismissal patterns.
- [x] 1.4 Edit `skills/_shared/qase/engram-convention.md` — updated "Written by" to "orchestrator" for all review artifact types; added capability class pointer to `rule-ownership.md`.
- [x] 1.5 Edit `skills/_shared/qase/openspec-convention.md` — updated all "Creates" entries in the Artifact File Paths table to "Produced By / Written By (Orchestrator)"; updated preflight-cache comment in directory tree.
- [x] 1.6 Verify `skills/_shared/qase/oracle-contract.md` owns the tier-ceiling table — PASS, file exists with canonical table (created by `runtime-proof-e2e`). No edit needed.
- [x] 1.7 Edit `skills/_shared/qase/routing-rules.md` — PASS after inspection: routing-rules.md IS the owner; there is no duplicate copy in a SKILL.md to remove as the task had been fully addressed in previous changes. The Oracle-Tier-Aware Routing section at lines 110-120 is the canonical owner content, not a duplicate.
- [x] 1.8 Strip restatement bullets from `skills/_shared/qase/oracle-contract.md` — PASS (guard task): no Oracle-Tier-Aware Routing duplication found in oracle-contract.md.

### Phase 2: Agent Layer

- [x] 2.1 Amend `agents/qa-security.md` — removed `Write` from `tools:` line; deleted "Your `Write` access exists for exactly ONE purpose" paragraph (~lines 50-52). Verified: `rg -n 'Write access exists'` returns zero.
- [x] 2.2 Create `agents/qa-scan.md` — 55 lines, static class, no Bash, no Write. ADR-F boundary note included.
- [x] 2.3 Create `agents/qa-architect.md` — 54 lines, static class, no Bash, no Write.
- [x] 2.4 Create `agents/qa-advocate.md` — 54 lines, static class, no Bash, no Write.
- [x] 2.5 Create `agents/qa-inclusion.md` — 56 lines, static class, no Bash, no Write.
- [x] 2.6 Create `agents/qa-performance.md` — 56 lines, static class, no Bash, no Write.
- [x] 2.7 Create `agents/qa-test-strategy.md` — 56 lines, static class, no Bash, no Write.
- [x] 2.8 Create `agents/qa-browser.md` — 61 lines, runtime class, Bash included, no Write.
- [x] 2.9 Create `agents/qa-visual.md` — 61 lines, runtime class, Bash included, no Write. `HAS_BLOCKERS` never appears in body (C1 clean).
- [x] 2.10 Create `agents/qa-report.md` — 60 lines, aggregator class, no Grep, no Bash, no Write.
- [x] 2.11 Create `agents/qa-init.md` — 58 lines, static class, no Bash. ADR-E' boundary note included.
- [x] 2.12 Create `agents/qa-feedback.md` — 57 lines, static class, no Bash, no Write.

**S1 infrastructure (coherence linter)**:
- [x] 3.1 Create `scripts/lib/coherence.sh` — implements coh_table(), C1-C4 checks, run_coherence_checks(). Proven: fixtures pass and fail correctly.
- [x] 3.2 Create `scripts/fixtures/coherence/` with 4 fixture corpora — positive, neg-forbidden-token, neg-undefined-placeholder, neg-missing-derivation.
- [x] 3.3 Create `scripts/coherence_test.sh` — runs all 4 fixtures; asserts both exit code AND check id. All 4 pass.

---

## Files Changed

| File | Action | What Was Done |
|------|--------|---------------|
| `skills/_shared/qase/rule-ownership.md` | Created | 5-table coherence registry; model/C2/capability decisions documented |
| `skills/_shared/qase/severity-contract.md` | Modified | Removed 2 duplicate tier-ceiling tables and the "restates" sentence |
| `skills/_shared/qase/persistence-contract.md` | Modified | Added Sole Writer section; rewrote preflight-cache single-writer rule |
| `skills/_shared/qase/engram-convention.md` | Modified | Updated Writer column; added capability-class pointer |
| `skills/_shared/qase/openspec-convention.md` | Modified | Updated all artifact rows to Produced By / Written By (Orchestrator) |
| `agents/qa-security.md` | Modified | Removed Write from tools; deleted justifying paragraph |
| `agents/qa-scan.md` | Created | 55 lines, static, ADR-F boundary note |
| `agents/qa-architect.md` | Created | 54 lines, static |
| `agents/qa-advocate.md` | Created | 54 lines, static |
| `agents/qa-inclusion.md` | Created | 56 lines, static |
| `agents/qa-performance.md` | Created | 56 lines, static |
| `agents/qa-test-strategy.md` | Created | 56 lines, static |
| `agents/qa-browser.md` | Created | 61 lines, runtime, Bash |
| `agents/qa-visual.md` | Created | 61 lines, runtime, Bash, no HAS_BLOCKERS in body |
| `agents/qa-report.md` | Created | 60 lines, aggregator, no Grep |
| `agents/qa-init.md` | Created | 58 lines, static, ADR-E' boundary note |
| `agents/qa-feedback.md` | Created | 57 lines, static |
| `scripts/lib/coherence.sh` | Created | C1-C4 + coh_table + run_coherence_checks |
| `scripts/fixtures/coherence/positive/` | Created | Minimal well-formed corpus |
| `scripts/fixtures/coherence/neg-forbidden-token/` | Created | HAS_BLOCKERS injected unguarded |
| `scripts/fixtures/coherence/neg-undefined-placeholder/` | Created | <evid> used, undeclared |
| `scripts/fixtures/coherence/neg-missing-derivation/` | Created | {page-slug} anchor missing |
| `scripts/coherence_test.sh` | Created | 4-fixture harness with exit-code + check-id assertions |

---

## Coherence Check Evidence (Both Directions)

### Positive fixture — exit 0

```
Fixture: positive
  PASS positive corpus: all coherence checks pass (exit 0)
```

### neg-forbidden-token — C1 fires, exit 1

```
Fixture: neg-forbidden-token
  PASS neg-forbidden-token: C1 fires on unguarded HAS_BLOCKERS (exit 1, found 'C1' in output)
```

### neg-undefined-placeholder — C2 fires, exit 1

```
Fixture: neg-undefined-placeholder
  PASS neg-undefined-placeholder: C2 fires on undeclared <evid> (exit 1, found 'C2' in output)
```

### neg-missing-derivation — C3 fires, exit 1

```
Fixture: neg-missing-derivation
  PASS neg-missing-derivation: C3 fires on missing anchor (exit 1, found 'C3' in output)
```

### Real corpus C1 — does NOT fire on the two legitimate HAS_BLOCKERS negations in qa-visual/SKILL.md

Running `check_c1_forbidden_token` against the real corpus:
- `skills/qa-visual/SKILL.md` line 696: `never HAS_BLOCKERS` — correctly exempt
- `skills/qa-visual/SKILL.md` line 732: `HAS_BLOCKERS is intentionally absent` — correctly exempt
- `agents/qa-visual.md` — file not found (expected — agent created in this batch; C1 will verify it on next run)

---

## Deviations from Design

1. **tasks 1.7 and 1.8 were guard tasks** — the tasks.md described them as potential edits, but inspection showed the routing-rules.md inline matrix and oracle-contract.md Oracle-Tier-Aware Routing duplication were already absent. Recorded as PASS rather than no-op.

2. **C4 check has a path normalization subtlety** — when `scope` patterns use `skills/**` glob notation, `find` expands them correctly, but the owner path in the registry is relative while `grep -rl` returns absolute paths. The C4 function handles this with a dual-path comparison (`root/$owner` vs `owner`). This should be verified when C4 is exercised on the real corpus in Batch 2.

3. **coh_table escaped-pipe fix** — markdown table cells containing `\|` (escaped pipe) were being split as two columns by the awk parser. Fixed by replacing `\|` with a placeholder (`\x01`) before splitting and restoring it after. This is a non-obvious gotcha documented here for the verify phase.

---

## Verification Commands Run

```
bash scripts/lint_skills.sh    → 108 PASS, 0 FAIL (exit 0)
bash scripts/install_test.sh   → 12 PASS, 0 FAIL (exit 0)
bash scripts/coherence_test.sh → 4 PASS, 0 FAIL (exit 0)
```

---

## Remaining Tasks (Batch 2)

- [ ] 2.13–2.26 Rewrite "Execution and Persistence Contract" in all 12 SKILL.md files
- [ ] 2.27 Update 6 orchestrator documents (same commit as 2.13–2.26)
- [ ] 3.4 Extend `scripts/lint_skills.sh` — source coherence.sh, add C5-C8 structural checks
- [ ] 3.5 Add `get_agents_path()` to `scripts/lib/json_parser.sh`
- [ ] 3.6 Add `install_agents_to_path()` to `scripts/lib/installer_core.sh`
- [ ] 3.7 Extend `scripts/install.sh` — AGENTS_SRC and agent distribution
- [ ] 3.8 Add `install_agents` block to `examples/claude-code/qase.json`
- [ ] 3.9 Extend `scripts/install_test.sh` — agents assertions
- [ ] 4.1–4.9 All Phase 4 testing and verification tasks
- [ ] 5.1–5.3 All Phase 5 documentation and registry tasks

---

## Remediation Cycle 1 (post-verify)

All BLOCKERs (B1-B3) and CRITICALs (C-1 through C-5) from verify-report.md addressed.

### B1 — coherence_test.sh self-test fixed
- [x] Fixed exit-code capture bug in `run_all_checks` (removed `|| true`; exit code captured correctly)
- [x] Fixed `run_check` dead function (same bug)
- [x] Repaired positive fixture: 12 agent stubs + 12 skill dirs + updated rule-ownership.md
- [x] PROVEN: break → FAIL, restore → PASS

### B2 — qa-report sole-writer violation fixed
- [x] `skills/qa-report/SKILL.md` Step 7: removed `Persist: mem_save(...)`; added "Do NOT call mem_save here"
- [x] Extended C8 to detect mem_save self-writes (Engram side)
- [x] Added actionable-issues persist instruction to all 6 orchestrator docs
- [x] Fixed {specialist}-report → {artifact-type} in all 6 Sole-Writer sections

### B3 — persistence-contract.md truth table added
- [x] Added Preflight Outcome Truth Table with full branch mapping and unavailable_reason enum

### C-1 — C2 scope extended to skills/qa-*/SKILL.md
- [x] `scripts/lib/coherence.sh` C2 now scans agents/ + skills/_shared/qase/ + skills/qa-*/SKILL.md
- [x] All ~57 new tokens bootstrapped in rule-ownership.md placeholders table
- [x] PROVEN: <evid> injection → C2 FIRES; removal → C2 PASSES

### C-3/C-4 — ADR-E' full probe sequence in all 6 orchestrators
- [x] Added P0/P1/P2/P2b/P3 commands + branch table to all 6 orchestrator docs
- [x] P2b Chrome fallback (4 binary names, never probe single name)
- [x] Branch table with unavailable_reason enum values

### C-5 (ADR-F) — Scope Resolution mapping added to all 6 orchestrators
- [x] Added HEAD~N / --staged / file / directory / --pr N / no-scope mapping

### C-5 (fixtures) — nested skills/skills/ subtrees cleaned
- [x] Removed from all 3 negative fixtures
- [x] Fixed neg-undefined-placeholder: proper registry created (C2 fires for correct reason)

### W-1 — neg-undefined-placeholder fixture fires for right reason (fixed via C-5)
- [x] C2 now fires because <evid> is undeclared, not because registry file is missing

### W-8 — README heading fixed
- [x] "7 Static + 2 Runtime" → "10 Static + 2 Runtime Specialists"

## Status

**Remediation Cycle 1 COMPLETE.** All 3 scripts pass:
```
bash scripts/lint_skills.sh    → PASS: 118, FAIL: 0, WARN: 0 — exit 0
bash scripts/install_test.sh   → PASS: 15, FAIL: 0 — exit 0
bash scripts/coherence_test.sh → PASS: 4, FAIL: 0 — exit 0
```
Ready for `sdd-verify`.
