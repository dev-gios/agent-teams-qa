# Oracle Contract (shared across all QASE skills)

> "An expectation without a stated source is an opinion; an expectation with a cited source is evidence."

This file is the **single source of truth** for Oracle Tier semantics in QASE. All five other shared contracts reference this file. No other file may redefine tier meanings or severity ceilings independently of this one (boundary B3).

No `agent-browser` command appears in this file. Browser commands belong in the runtime specialist skill files only (boundary B2).

---

## Purpose

QASE findings claim an expected outcome for each step. The Oracle Tier is the mechanism that answers: *where did this expectation come from, and how much authority does that source carry?*

Without a stated source, a finding is an opinion. With a cited source at a verified tier, it is evidence — checkable by any reviewer, not just the author. The tier is not self-declared; it is a property of the citation. If the citation cannot be verified, the tier degrades. This is what prevents tier inflation from restoring the "confident opinion" failure mode in new clothes.

---

## The Four Tiers

| Tier | Name | Source Kind | Available When | Citation Requirement | Max Severity | Veto-Bearing |
|------|------|-------------|----------------|----------------------|--------------|--------------|
| **L1** | Spec | SDD spec scenario in `openspec/changes/*/specs/**/*.md` | An `openspec/` directory exists with spec files | Spec file path + scenario/heading title quoted verbatim | BLOCKER | Yes (via qa-browser gate) |
| **L2** | Test | Project test suite, executed in this review, output read | A test runner was detected by `qa-init` and executed in this review | Test file name + test case name/description + the observed runner output line | BLOCKER | Yes (via qa-browser gate) |
| **L3-schema** | Code contract (schema) | OpenAPI/Swagger, JSON Schema, Zod, Pydantic, class-validator, Prisma schema, GraphQL SDL | Schema files are present and parseable | `path:line` + the literal contract text verbatim | BLOCKER | Yes (via qa-browser gate) |
| **L3-inferred** | Code contract (inferred) | Validation regexes, error-message string literals, redirect targets, guard clauses | Source code is readable | `path:line` + verbatim literal for **each** of ≥ 2 independent signals | WARNING (cap) | No |
| **L4** | Named standard | WCAG SC id, RFC section, HTTP semantics, CWV metric name + threshold, Nielsen heuristic number | Always | A named standard — e.g., `WCAG 2.1 SC 1.4.3`, `RFC 7231 §6.5.4`, `LCP < 2.5 s` | WARNING (cap) | No |

**L1 unavailable note**: when no `openspec/` directory exists, L1 is unavailable. Stated as: "L1 unavailable: no openspec/ directory."

**L2 unavailable note**: when no test runner was detected by `qa-init`, L2 is unavailable. Stated as: "L2 unavailable: no test runner detected." A test suite that *exists* but was not *executed in this review* does not satisfy L2.

---

## Tier Population

Each tier is populated by a distinct mechanism. The mechanism determines whether the tier is available for a given step.

**L1 — Spec**: glob `openspec/changes/*/specs/**/*.md`. Parse Given/When/Then scenarios and heading titles. A tier-L1 claim must map to a specific scenario or heading that states an expected outcome for the exact action or path under test.

**L2 — Test**: execute the test runner command recorded by `qa-init` in this review session, then read its output. "Tests exist" is not L2; "tests were run and their output was read" is L2. A test name + an observed pass/fail line from the output is the minimum citation.

**L3-schema**: scan for schema definition files — OpenAPI/Swagger (`.yaml`, `.json` with `openapi:` or `swagger:` keys), JSON Schema (`$schema:` key), Zod (`z.object`, `z.string`, etc.), Pydantic (`class ... (BaseModel)`), class-validator (`@IsEmail()`, `@IsString()`, etc.), Prisma (`schema.prisma`), GraphQL SDL (`.graphql`, `.gql`). A citation requires locating the specific field or rule at a `path:line` and quoting the literal text.

**L3-inferred**: scan for validation regexes, error-message string literals, redirect targets, and guard clauses in handler/component code. A citation requires ≥ 2 independent signals — two separately-locatable expressions that agree on the constraint. Two parts of the same expression (a regex and its inline message on the same line) are **one** signal, not two.

**L4**: always available. The source is a named standard with a specific identifier: WCAG SC id (e.g., `WCAG 2.1 SC 1.4.3`), RFC section (e.g., `RFC 7231 §6.5.4`), CWV metric name and threshold (e.g., `LCP < 2.5 s`), Nielsen heuristic number (e.g., `Nielsen Heuristic #1`). An unnamed best-practice observation with no identifiable standard is UNGROUNDED.

---

## Citation Requirements

These rules are mechanical, not advisory. Missing any component triggers an automatic downgrade.

**L1**: spec file path + scenario/heading title quoted verbatim.
- Example: `openspec/changes/auth-flow/specs/login/spec.md` — *"Given a valid email and password, When the user submits the login form, Then they are redirected to /dashboard"*
- Missing the spec path → downgrade to L2.
- Missing the verbatim title → downgrade to L2.

**L2**: test file name + test case name/description + the observed runner output line (the test MUST have been EXECUTED in this review).
- Example: `src/__tests__/auth.test.ts` — *"redirects to /dashboard after valid login"* — `PASS src/__tests__/auth.test.ts > redirects to /dashboard after valid login`
- Test not executed → downgrade to L3-schema.
- Output line missing → downgrade to L3-schema.

**L3-schema**: `path:line` + the literal contract text verbatim. Missing **any** component → automatic downgrade to L3-inferred (not to L3-schema with a note — actual downgrade).
- Example: `src/schemas/auth.ts:14` — `z.string().email({ message: "Invalid email address" })`
- Missing path → L3-inferred.
- Missing line number → L3-inferred.
- Missing verbatim literal → L3-inferred.

**L3-inferred**: ≥ 2 independent signals, each with its own `path:line` + verbatim literal. Two signals from the same expression are ONE signal. < 2 independent signals → downgrade to L4.
- Example signal 1: `src/routes/auth.ts:41` — `if (!/^[^@]+@[^@]+$/.test(email))`
- Example signal 2: `src/routes/auth.ts:42` — `return res.status(400).json({ error: "Invalid email address" })`
- Single signal → L4.
- Both signals on the same line → single signal → L4.

**L4**: a NAMED standard with a specific identifier. A general statement like "this is a best practice" without a named standard → UNGROUNDED.
- Valid: `WCAG 2.1 SC 1.4.3 — Contrast (Minimum)`
- Valid: `Web Vitals — LCP threshold 2.5 s (Good)`
- Invalid: "this follows accessibility guidelines" (no named standard) → UNGROUNDED

---

## Resolution Algorithm

Deterministic, per step, evaluated after the observation is captured (after the act-and-observe phase). Two runs of the same flow against the same repo state MUST select the same tier.

```
INPUT:  step (action, intent), observed state, candidate oracle set from F1
OUTPUT: (tier, expectation, citation[], absence_note?) — always populated

1. CANDIDATE FILTER
   A tier is a candidate only if it yields a STEP-SPECIFIC expectation.
   "The source exists" is not sufficient — the source must state an expected
   outcome for this exact action or path. Sources that exist but say nothing
   specific about this step are not candidates.

2. STRICT DESCENDING WALK
   Try tiers in this fixed order; first match that passes claim validation wins:
     L1 → L2 → L3-schema → L3-inferred → L4
   No tier may be skipped. No tier may be tried out of order. If a tier yields
   no step-specific expectation, record why (feeds step 6) and continue.

3. TIE-BREAK WITHIN A TIER (determinism requirement)
   When multiple candidates exist at the same tier:
     a. Most specific match first (exact route/path > prefix > glob)
     b. Then shortest file path
     c. Then lexicographic file path
   Stated so two runs cannot disagree on which source wins.

4. CLAIM VALIDATION — applied to the selected tier:

   | Tier         | Required to hold the claim                                        |
   |--------------|-------------------------------------------------------------------|
   | L1           | spec file path + scenario/heading title quoted verbatim           |
   | L2           | test command EXECUTED in this review + test name + the observed   |
   |              | runner output line                                                |
   | L3-schema    | path:line + the literal contract text, verbatim                   |
   | L3-inferred  | >= 2 independent signals, each with its own path:line + literal   |
   | L4           | a NAMED standard (WCAG SC id, RFC section, CWV metric name +      |
   |              | threshold, Nielsen heuristic number)                              |

5. DOWNGRADE — transitive and re-validated at the new tier
     L1 without citation        → L2 (re-enter step 4 at L2)
     L2 without executed output → L3-schema (re-enter step 4 at L3-schema)
     L3-schema without citation → L3-inferred (re-enter step 4 at L3-inferred)
     L3-inferred with < 2 signals → L4 (re-enter step 4 at L4)
     L4 without a named standard  → UNGROUNDED
   A downgraded finding NEVER retains the higher tier's blocking power.

6. ABSENCE DECLARATION — mandatory whenever the result is below L3-schema
   The evidence row carries an Oracle Absence note naming each higher tier
   consulted and why it was unavailable:
     "L1 unavailable: no openspec/ directory"
     "L2 unavailable: qa-init recorded no test command"
     "L3-schema unavailable: no schema file declares this field"
   Silent degradation is how a weak oracle gets mistaken for a strong one.

7. UNGROUNDED — every tier exhausted without a named standard at L4:
     status   = INCONCLUSIVE (never FAIL)
     severity = INFO ceiling (never WARNING, never BLOCKER)
     row text = "no oracle available for this step: {consulted tiers and why}"
   The step is still recorded with action, observed, and artifact. An
   unverifiable step is reported as unverifiable — not as a pass, not as a defect.
```

---

## Degradation and Absence

Downgrades are **transitive**: a demoted tier must satisfy the requirements of the new tier, or it degrades again.

| From | Reason | Degrades to | Re-validates |
|------|--------|-------------|--------------|
| L1 | Citation incomplete | L2 | Must now satisfy L2 citation rule |
| L2 | Test not executed in this review | L3-schema | Must now satisfy L3-schema citation rule |
| L3-schema | Missing path, line, or verbatim literal | L3-inferred | Must now satisfy L3-inferred corroboration rule |
| L3-inferred | Fewer than 2 independent signals | L4 | Must name a recognized standard |
| L4 | No named standard | UNGROUNDED | — |

**Mandatory absence note**: any result below L3-schema carries an explicit note naming each higher tier consulted and why it was unavailable. A finding that reaches L4 must state why L1, L2, and L3-schema were all absent.

**No code contract case**: when a step produces a finding with no L3-schema or higher source, the note reads: "no code contract found for this path — L3-schema unavailable."

**Universality case notes**:
- "L1 unavailable: no openspec/ directory" — when the project has no SDD spec.
- "L2 unavailable: no test runner detected" — when `qa-init` recorded no executable test command.

---

## Blocking Matrix

This table governs which tiers may produce `BLOCKER`. It is normative; any finding that claims BLOCKER at a capped tier is malformed and MUST be downgraded by the enforcement gate in `qa-report`.

| Tier | May produce BLOCKER? | Notes |
|------|----------------------|-------|
| L1 | **May** | Citation required. Missing citation → downgrade to L2, reassess. |
| L2 | **May** | Test must have been executed in this review. |
| L3-schema | **May** | Citation (`path:line` + verbatim literal) required. Missing citation → automatic downgrade to L3-inferred → BLOCKER not permitted. |
| L3-inferred | **Must NOT** | Cap at WARNING. A BLOCKER arriving at L3-inferred is malformed and MUST be downgraded to WARNING. |
| L4 | **Must NOT** | Advisory only. Cap at WARNING. A BLOCKER arriving at L4 is malformed and MUST be downgraded to WARNING. |
| UNGROUNDED | **Must NOT** | Cap at INFO (INCONCLUSIVE). |

**Runtime finding with no Oracle Tier field**: treated as UNGROUNDED and capped at INFO. A missing tier field is never a benign omission — it is evidence that oracle resolution did not run.

---

## Anti-Inflation Rules

These rules are the mechanical safeguards against the "confident opinion" failure mode.

1. **Uncited L3-schema auto-downgrades to L3-inferred.** A claim of `L3-schema` without a `path:line` + verbatim literal is processed as `L3-inferred` — it does not receive a note or a warning, it simply IS L3-inferred. The author's label is overridden by the citation check.

2. **Single-signal L3-inferred auto-downgrades to L4.** A pattern-derived claim with only one `path:line` signal is processed as L4, regardless of how compelling the single signal appears.

3. **UNGROUNDED never produces FAIL.** When no tier can be established, the status is `INCONCLUSIVE` and the severity ceiling is `INFO`. UNGROUNDED steps are not defects; they are measurement gaps.

4. **A runtime finding with no Oracle Tier field is treated as UNGROUNDED and capped at INFO.** No silent promotion; the tier must be stated explicitly.

5. **Tier is a checkable claim, not a self-declaration.** Any reviewer may open the cited `path:line` and confirm the verbatim literal. If they cannot confirm it, the tier is invalid and degrades. The oracle is only as strong as its citation.
