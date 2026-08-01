# Apply Progress: runtime-routing — Final Remediation — COMPLETE

**Change**: `runtime-routing`
**PR scope**: Final remediation of Y1-Y6 from final-confirmation-pass verify report
**Branch**: `feat/GS-runtime-routing-orchestrator` (uncommitted — per user constraint)
**Mode**: Standard (no strict TDD applicable to markdown/JSON/bash skill files)
**Date**: 2026-08-01

---

## Previous Batches

### PR 1 (Phases 1–2) — COMPLETE (committed in `a058d8f`)
- [x] 1.1 through 2.9 — complete

### PR 2 (Phases 3–6) — COMPLETE
- [x] 3.1 through 6.3 — complete (27/27 tasks)

### Remediation Cycle 1 — COMPLETE
- [x] X1–X8 all closed (8 CRITICALs, 4 WARNINGs)
- Verified by Final Confirmation Pass: 6/8 CRITICALs confirmed; X4 (partial), X8 (mechanism) open

---

## Final Remediation: Y1–Y6

### Y1 — X4 CLOSED: Step 8 envelope now returns `runtime_coverage` + `runtime_unverified_reason`

**Status**: FIXED

Files changed:
- `skills/qa-report/SKILL.md`: Added `runtime_coverage` and `runtime_unverified_reason` to Step 8 Return Report structured envelope
- `skills/qa-report/SKILL.md`: Made Step 3b fail-closed: absent `runtime_recommendation` block → `unverified` (not `not-required`)
- `skills/qa-report/SKILL.md`: Updated Rules section to mandate both fields in the envelope

Verification: `awk 'NR>=293' skills/qa-report/SKILL.md | grep runtime` → finds `runtime_coverage:` and `runtime_unverified_reason:` in envelope

### Y2 — X8 mechanism FIXED: C12 derives orchestrator set from `examples/*/qase.json`

**Status**: FIXED

Files changed:
- `scripts/lib/coherence.sh`: Added `check_c12_orchestrator_set_parity()` — derives orchestrator file list from `qase.json orchestrator.source` fields and asserts the required table covers all of them. A new unpinned orchestrator fails C12.
- `scripts/coherence_test.sh`: Added Fixture 9 `neg-unpinned-orchestrator` → C12 fires
- `scripts/fixtures/coherence/neg-unpinned-orchestrator/`: New negative fixture with `new-tool` unpinned orchestrator
- `scripts/fixtures/coherence/positive/examples/claude-code/qase.json`: New — provides orchestrator.source for C12
- `scripts/fixtures/coherence/positive/examples/opencode/qase.json`: New — provides orchestrator.source for C12

Mutation proof: delete `examples/opencode/opencode.json` from all required rows → `FAIL C12: orchestrator 'examples/opencode/opencode.json' ... NOT pinned`, exit 1 ✓

### Y3 — Semantic core protected: C11 pins Step 3b ELSE → unverified

**Status**: FIXED

Files changed:
- `scripts/lib/coherence.sh`: Added `check_c11_coverage_resolution_mapping()` — asserts Step 3b ELSE resolves to `unverified` (not `verified`), and Step 8 envelope declares both runtime fields
- `scripts/coherence_test.sh`: Added Fixture 8 `neg-step3b-else-verified` → C11 fires
- `scripts/fixtures/coherence/neg-step3b-else-verified/`: New negative fixture with ELSE flipped to `verified`
- `scripts/fixtures/coherence/positive/skills/qa-report/SKILL.md`: Updated to include Step 3b and Step 8 blocks for C11 to pass on positive fixture

Mutation proof: flip ELSE from `→ unverified` to `→ verified` in `skills/qa-report/SKILL.md` → `FAIL C11a: Step 3b ELSE branch does not resolve to unverified` (×2), exit 1 ✓

### Y4 — `severity-contract.md:94` prose fixed to scope restriction correctly

**Status**: FIXED

Files changed:
- `skills/_shared/qase/severity-contract.md`: Replaced "It MUST NOT be restated elsewhere" with scoped version: restricts to `skills/` and `agents/`, explicitly states orchestrator documents under `examples/` MUST restate it in the `{runtime_suffix}` resolution block

### Y5 — `--url` added to opencode.json SCOPE SYNTAX + `/qa-review` command entry; pinned in C9

**Status**: FIXED

Files changed:
- `examples/opencode/opencode.json`: Added `| --url <url>  | Base URL for runtime verification (modifier) |` row to SCOPE SYNTAX table
- `examples/opencode/opencode.json`: Updated `/qa-review [scope]` → `/qa-review [scope] [--url <url>]` in QASE COMMANDS
- `skills/_shared/qase/rule-ownership.md`: Added `orch-url-scope-syntax` row pinning `Base URL for runtime verification` in all 7 orchestrator docs (min_count: 1)

Mutation proof: remove SCOPE SYNTAX `--url` row from opencode.json → `FAIL C9 orch-url-scope-syntax: required literal 'Base URL for runtime verification' missing`, exit 1 ✓

### Y6 — `test_skills_only_install` real-source test (no longer a tautology)

**Status**: FIXED

Files changed:
- `scripts/install_test.sh`: Rewrote `test_skills_only_install()` to install from real `$REPO_DIR/skills` instead of synthetic fixture. Now asserts: (a) same skill count as real source, (b) installed `qa-report/SKILL.md` contains `runtime_coverage`, (c) installed `qa-report/SKILL.md` contains `runtime_unverified_reason`. New assertion (c) would fail if someone removed `runtime_unverified_reason` from the real skill.

---

## Verification Output

```
lint_skills.sh:   PASS 125/0  (was 123/0 — +C11, +C12)
install_test.sh:  PASS 23/0   (was 22/0 — +runtime_unverified_reason assertion)
coherence_test.sh: PASS 9/9   (was 7/7 — +C11 neg-step3b-else-verified, +C12 neg-unpinned-orchestrator)

Preflight truth table byte-identity vs a058d8f: BYTE-IDENTICAL (diff empty)

Parity matrix (all 7 orchestrators):
  --url (SCOPE table):      y/y/y/y/y/y/y
  /qa-review --url entry:   y/y/y/y/y/y/y
  STATIC ONLY:              y/y/y/y/y/y/y
  {runtime_suffix}:         y/y/y/y/y/y/y
  Step 2b:                  y/y/y/y/y/y/y
  never starts app:         y/y/y/y/y/y/y
```

### Failure proofs (new checks only):

**Y3 — C11 FAIL (flip ELSE→verified):**
```
FAIL C11a: Step 3b ELSE branch does not resolve to unverified in …/skills/qa-report/SKILL.md — flip protection failed
FAIL C11a: Step 3b ELSE branch resolves to 'verified' — must be 'unverified'. This is the semantic core of runtime-routing
exit 1
```

**Y2 — C12 FAIL (unpin opencode.json):**
```
FAIL C12: orchestrator 'examples/opencode/opencode.json' (from qase.json) is NOT pinned in the required table — add it to all required rows
exit 1
```

**Y5 — C9 FAIL (strip SCOPE SYNTAX --url row from opencode.json):**
```
FAIL C9 orch-url-scope-syntax: required literal 'Base URL for runtime verification' missing from …/examples/opencode/opencode.json (found 0, need 1)
exit 1
```

---

## Files Changed (Final Remediation)

- `skills/qa-report/SKILL.md` — Step 8 envelope + Step 3b fail-closed + Rules
- `skills/_shared/qase/severity-contract.md` — Scoped the (STATIC ONLY) restriction prose
- `skills/_shared/qase/rule-ownership.md` — Added `orch-url-scope-syntax` required row
- `examples/opencode/opencode.json` — SCOPE SYNTAX `--url` row + `/qa-review --url` entry
- `scripts/lib/coherence.sh` — C11 + C12 functions; C12 derives set from qase.json
- `scripts/coherence_test.sh` — Fixtures 8 (neg-step3b-else-verified) + 9 (neg-unpinned-orchestrator)
- `scripts/install_test.sh` — Real-source criterion-13 test + runtime_unverified_reason assertion
- `scripts/fixtures/coherence/positive/skills/qa-report/SKILL.md` — Step 3b + Step 8 blocks
- `scripts/fixtures/coherence/positive/examples/claude-code/qase.json` — New (C12 positive)
- `scripts/fixtures/coherence/positive/examples/opencode/qase.json` — New (C12 positive)
- `scripts/fixtures/coherence/neg-step3b-else-verified/` — New negative fixture for C11
- `scripts/fixtures/coherence/neg-unpinned-orchestrator/` — New negative fixture for C12

## Status: COMPLETE — Y1–Y6 all resolved
