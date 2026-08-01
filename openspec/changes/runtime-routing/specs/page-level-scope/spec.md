# page-level-scope Specification

## Purpose

Define the scope boundary for the first slice of runtime verification. `qa-browser` is
launched with a URL and zero inferred flows. Flow inference from a diff is explicitly
deferred because a wrong flow produces confident L1/L2 findings at a veto-bearing tier —
which is strictly worse than not running the flow at all.

---

## Requirements

### Requirement: Page-Level Runtime Verification

When launched under a runtime recommendation, `qa-browser` MUST perform page-level checks
using only the provided URL. Page-level checks include: console error audit, network health
audit, accessibility audit on the rendered DOM, interactive element testing, navigation
audit, responsive layout sweep, and Core Web Vitals measurement.

These checks need only a URL and are where `qa-browser`'s L1/L2 tiers are directly
applicable (console errors, failed network requests, rendered-DOM accessibility, CWV).

#### Scenario: qa-browser launched with URL and no flows

- GIVEN the orchestrator resolved a URL for a review with `runtime_recommendation.recommended: true`
- WHEN the orchestrator launches `qa-browser`
- THEN `qa-browser` MUST receive the URL and MUST execute Steps 1–8 (page-level checks)
- AND Step 9 (user flow engine) MUST be skipped unless the user explicitly passed flows
- AND the report MUST record "User flows: none provided — page-level only"

#### Scenario: Page-level checks include all seven standard checks

- GIVEN `qa-browser` is running a page-level review
- WHEN it completes its execution
- THEN the report MUST include results for: console errors, network health, accessibility,
  interactive elements, navigation, responsive layout, and Core Web Vitals
- AND each result MUST carry an Oracle Tier per `oracle-contract.md`

---

### Requirement: Flow Inference from Diff Is Out of Scope

`qa-browser` MUST NOT infer user flows from the diff or from changed file paths. A diff
shows changed symbols; a flow is a sequence of user intentions. Inferring "the checkout
flow" from `src/pages/checkout.tsx` is an inference, not evidence.

A wrongly inferred flow produces confident findings at L1 or L2, which are veto-bearing.
A veto-bearing finding based on a wrong flow is the worst possible output.

#### Scenario: qa-browser does not infer flows from diff

- GIVEN a diff containing `src/pages/checkout.tsx` as a changed file
- WHEN the orchestrator launches `qa-browser` under a runtime recommendation
- THEN `qa-browser` MUST NOT construct a checkout flow from the file path
- AND Step 9 (user flow engine) MUST remain skipped
- AND no L1 or L2 findings MUST be produced from an inferred flow

#### Scenario: User-supplied flows are accepted but not inferred

- GIVEN the user explicitly passes a flow (e.g., via orchestrator option)
- WHEN the orchestrator launches `qa-browser`
- THEN the provided flow MUST be executed via Step 9
- AND the report MUST record the flow as user-supplied, not diff-derived

---

### Requirement: Clean Degradation on Skills-Only Installs

A skills-only install (one where `runtime_available: false`) MUST still complete a UI
review. The review MUST complete with `runtime_coverage: unverified` and the
`(STATIC ONLY)` qualifier on the verdict. It MUST NOT error, block, or emit a fabricated
finding.

#### Scenario: UI review completes on skills-only install

- GIVEN a skills-only install where `runtime_available: false`
- AND a diff triggering the `ui` category
- WHEN the orchestrator runs the review pipeline
- THEN all static specialists MUST complete normally
- AND `qa-browser` and `qa-visual` MUST skip and return `verdict_contribution: UNVERIFIED`
- AND the final report MUST be `APPROVE (STATIC ONLY)` or `APPROVE WITH WARNINGS (STATIC ONLY)`
- AND `scripts/install_test.sh` MUST exit 0 for a skills-only target

#### Scenario: Error is never emitted solely from runtime unavailability

- GIVEN a review where `runtime_coverage: unverified` due to any `runtime_unverified_reason`
- WHEN `qa-report` produces the final report
- THEN `status` MUST NOT be `error` or `failed` solely because runtime did not run
- AND the review pipeline MUST complete with a qualified APPROVE or standard REJECT verdict

---

### Requirement: Bash Confinement Unchanged

Bash remains confined to exactly `qa-browser` and `qa-visual`. No other specialist, no
`qa-scan`, and the orchestrator's URL-resolution reachability probe MUST NOT use Bash via
the specialist tool class. The orchestrator performs its reachability probe through its own
native HTTP capability, not through a Bash specialist.

#### Scenario: qa-scan tool class remains static

- GIVEN the `rule-ownership.md` capabilities table
- WHEN the row for `qa-scan` is inspected
- THEN `class` MUST be `static`
- AND `Bash` MUST NOT appear in the allowed tools

#### Scenario: Runtime specialists retain runtime class

- GIVEN the `rule-ownership.md` capabilities table
- WHEN the rows for `qa-browser` and `qa-visual` are inspected
- THEN `class` MUST be `runtime`
- AND `Bash` MUST appear in the allowed tools for both
