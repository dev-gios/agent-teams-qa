# runtime-coverage-verdict Specification

## Purpose

Define the three-mechanism coverage state that prevents a report from implying runtime
verification that never happened. Today `routing-rules.md:108` returns `verdict_contribution:
CLEAN` when a runtime specialist is skipped — making "found nothing" and "did not look"
indistinguishable. This spec closes that gap.

---

## Requirements

### Requirement: runtime_coverage Field

Every review MUST carry a `runtime_coverage` field set to exactly one of `verified`,
`not-required`, or `unverified`. This field is authoritative for the coverage state and
MUST be produced by `qa-report` from the specialist results it receives.

| Value | Meaning |
|---|---|
| `verified` | At least one runtime specialist ran and completed |
| `not-required` | No triggering category was detected by `qa-scan` |
| `unverified` | A triggering category was detected but no specialist ran |

#### Scenario: verified when a runtime specialist completes

- GIVEN a review where `qa-browser` ran and returned findings
- WHEN `qa-report` produces the final report
- THEN `runtime_coverage` MUST be `verified`
- AND the verdict string MUST NOT carry the `(STATIC ONLY)` qualifier

#### Scenario: not-required when no triggering category detected

- GIVEN a review where `qa-scan` detected only `test` and `config` categories
- WHEN `qa-report` produces the final report
- THEN `runtime_coverage` MUST be `not-required`
- AND no Unverified Coverage section MUST appear in the report

#### Scenario: unverified when runtime was recommended but did not run

- GIVEN a review where `qa-scan` recommended runtime
- AND the orchestrator could not resolve a URL
- WHEN `qa-report` produces the final report
- THEN `runtime_coverage` MUST be `unverified`
- AND the verdict string MUST carry the `(STATIC ONLY)` qualifier

---

### Requirement: UNVERIFIED Verdict Contribution

`UNVERIFIED` MUST be added to the `verdict_contribution` enum. A runtime specialist that
is skipped due to missing runtime or unresolved URL MUST return `verdict_contribution:
UNVERIFIED` instead of `verdict_contribution: CLEAN`.

`UNVERIFIED` carries **zero findings** — the refusal rule is unchanged. The only difference
is the token used, so `qa-report` can distinguish "looked and found nothing" from "did not
look". `UNVERIFIED` MUST NOT be used by static specialists; it is scoped to `qa-browser`,
`qa-visual`, and `qa-report`.

#### Scenario: Skipped runtime specialist returns UNVERIFIED

- GIVEN `qa-browser` is launched under a recommendation
- AND `runtime_available` is not `true` in the preflight cache
- WHEN `qa-browser` returns its result
- THEN `verdict_contribution` MUST be `UNVERIFIED`
- AND findings MUST be zero (no fabricated runtime findings)
- AND the refusal rule (Do NOT fabricate findings from static reading) remains enforced

#### Scenario: UNVERIFIED never produces a fabricated WARNING

- GIVEN a skipped runtime specialist returning `UNVERIFIED`
- WHEN `qa-report` processes the envelope
- THEN `qa-report` MUST NOT emit a WARNING finding derived from the skip
- AND the UNVERIFIED state MUST NOT raise the finding count
- AND a bare `REJECT` or `APPROVE WITH WARNINGS` MUST NOT result solely from the UNVERIFIED state

#### Scenario: CLEAN contribution still valid for non-recommended skips

- GIVEN a review where runtime was `not-required` (no triggering category)
- AND a runtime specialist was not launched
- WHEN `qa-report` aggregates contributions
- THEN no runtime specialist contribution appears in the report
- AND `runtime_coverage` MUST be `not-required`, not `unverified`

---

### Requirement: (STATIC ONLY) Verdict Qualifier

When `runtime_coverage == unverified`, the verdict string MUST be qualified. A bare `APPROVE`
or `APPROVE WITH WARNINGS` is structurally impossible when runtime was recommended but did not
run. `REJECT` is unqualified — it already understates nothing.

Qualified forms: `APPROVE (STATIC ONLY)` and `APPROVE WITH WARNINGS (STATIC ONLY)`.
`(STATIC ONLY)` is a registered single-source literal in `rule-ownership.md` owned by
`severity-contract.md`; it MUST NOT be restated in any other file.

The qualifier MUST NOT appear when `runtime_coverage` is `verified` or `not-required`.

#### Scenario: APPROVE verdict qualified when unverified

- GIVEN a review with `runtime_coverage: unverified`
- AND all static specialists returned CLEAN or WARNING
- WHEN `qa-report` emits the verdict
- THEN the verdict MUST be `APPROVE (STATIC ONLY)` or `APPROVE WITH WARNINGS (STATIC ONLY)`
- AND a bare `APPROVE` MUST NOT appear

#### Scenario: REJECT is not qualified

- GIVEN a review with `runtime_coverage: unverified`
- AND at least one specialist returned a BLOCKER
- WHEN `qa-report` emits the verdict
- THEN the verdict MUST be `REJECT` (unqualified)
- AND `(STATIC ONLY)` MUST NOT be appended

#### Scenario: STATIC ONLY absent when runtime verified

- GIVEN a review where `qa-browser` ran successfully
- WHEN `qa-report` emits the verdict
- THEN the verdict MUST NOT include `(STATIC ONLY)`

#### Scenario: Negative fixture — bare APPROVE with unverified coverage fails linter

- GIVEN a fixture report containing `verdict: APPROVE` (bare)
- AND `runtime_coverage: unverified` in the same report metadata
- WHEN `bash scripts/lint_skills.sh` validates the fixture
- THEN the linter MUST exit with a non-zero exit code
- AND the linter MUST emit an error identifying the bare APPROVE as a violation

---

### Requirement: Unverified Coverage Report Section

When `runtime_coverage == unverified`, `qa-report` MUST include a mandatory **Unverified
Coverage** section naming: the triggering categories, the specialists that did not run, the
machine reason (`runtime_unverified_reason`), and the exact command that closes the gap.

#### Scenario: Unverified Coverage section present when unverified

- GIVEN a report with `runtime_coverage: unverified`
- WHEN the report is rendered
- THEN it MUST contain a section titled "Unverified Coverage"
- AND the section MUST list the triggering categories
- AND MUST name the specialists that did not run
- AND MUST include `runtime_unverified_reason` value
- AND MUST include the closing command (e.g., `/qa-browser <url>`)

#### Scenario: Unverified Coverage section absent when not-required

- GIVEN a report with `runtime_coverage: not-required`
- WHEN the report is rendered
- THEN the report MUST NOT contain an "Unverified Coverage" section

---

### Requirement: runtime_unverified_reason Is Review-Scoped

`runtime_unverified_reason` is a **review-scoped** field. Its enum extends the preflight
`unavailable_reason` values with two additional values (`no-url-resolved`, `user-declined`)
that describe URL resolution outcomes, not environment probing. These values MUST NOT be added
to the preflight `unavailable_reason` enum in `persistence-contract.md`.

The preflight Outcome Truth Table in `persistence-contract.md` MUST remain byte-identical to
its pre-change state. The preflight `unavailable_reason` enum values are closed:
`null`, `"bash-unavailable"`, `"agent-browser-not-installed"`, `"no-chrome-binary"`,
`"smoke-test-failed"`.

`runtime_unverified_reason` enum values:
- All five preflight `unavailable_reason` values (when the skip is cache-driven)
- `no-url-resolved` (orchestrator exhausted all five precedence steps without a URL)
- `user-declined` (user was asked and declined or did not respond)

#### Scenario: runtime_unverified_reason uses no-url-resolved when URL not found

- GIVEN the orchestrator exhausted all five URL resolution steps without a result
- WHEN `qa-report` records the reason
- THEN `runtime_unverified_reason` MUST be `no-url-resolved`
- AND this value MUST NOT appear in the preflight `unavailable_reason` enum

#### Scenario: Preflight truth table is byte-identical after the change

- GIVEN the implemented change is applied
- WHEN `persistence-contract.md` is read
- THEN the Preflight Outcome Truth Table section MUST be byte-identical to its pre-change state
- AND the `unavailable_reason` enum declaration MUST be unchanged

#### Scenario: Impossible to imply runtime verification that never happened

- GIVEN any QASE report
- WHEN the report metadata is inspected
- THEN IF `runtime_coverage: unverified`, the verdict string MUST contain `(STATIC ONLY)`
- AND IF the verdict string is bare `APPROVE` or `APPROVE WITH WARNINGS`,
  `runtime_coverage` MUST be `verified` or `not-required`
- AND no combination of fields MUST imply runtime verification occurred without `runtime_coverage: verified`
