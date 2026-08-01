# Oracle Contract Specification

## Purpose

Define the 4-tier oracle model that governs how every runtime finding in QASE attributes the source of its expectation. An expectation without a stated source is an opinion; an expectation with a cited source is evidence. This spec governs the oracle contract shared file at `skills/_shared/qase/oracle-contract.md`.

---

## Requirement: Tier Definitions and Assignment

The oracle contract MUST define exactly four tiers. Every finding produced by a runtime specialist MUST declare exactly one oracle tier.

### Tier Reference

| Tier | Name | Source |
|------|------|--------|
| L1 | SDD spec scenarios | `openspec/changes/*/specs/**/*.md` — Given/When/Then scenarios from the active SDD change |
| L2 | Repo test suite, executed | Output of the project's own test runner, executed and read |
| L3-schema | Code contract (schema-first) | Structured, machine-readable source: OpenAPI, JSON Schema, Zod, Pydantic, Prisma, GraphQL SDL |
| L3-inferred | Code contract (pattern-inferred) | Validation regexes, error message literals, redirect targets, guard clauses extracted from handlers/components |
| L4 | Universal heuristics | WCAG, Nielsen, HTTP semantics, CWV thresholds — no project-specific source |

### Scenario: L1 tier assigned when a matching SDD spec scenario exists

- GIVEN a runtime finding whose expected outcome matches a Given/When/Then scenario in `openspec/changes/*/specs/**/*.md`
- WHEN the runtime specialist assigns an oracle tier
- THEN it MUST assign `L1`
- AND the finding MUST cite the spec file path and the matching scenario title
- AND the finding MAY carry BLOCKER severity

### Scenario: L2 tier assigned when the project test suite covers the verified path

- GIVEN a project whose test runner has been executed AND whose output confirms a test case covering the verified behavior
- WHEN the runtime specialist assigns an oracle tier
- THEN it MUST assign `L2`
- AND the finding MUST cite the test file name and the test case name or description
- AND the finding MAY carry BLOCKER severity

### Scenario: L3-schema tier assigned when a structured schema file declares the contract

- GIVEN a finding whose expected behavior is declared in a structured, machine-readable schema file (e.g., a Zod schema, OpenAPI spec, Prisma model, JSON Schema, Pydantic model, GraphQL SDL)
- WHEN the runtime specialist assigns an oracle tier
- THEN it MUST assign `L3-schema`
- AND the finding MUST include a mandatory citation: file path, line number, and the literal contract text (for example: "`src/schemas/auth.ts:14` — `z.string().email({ message: \"Invalid email address\" })`")
- AND the finding MAY carry BLOCKER severity

### Scenario: L3-schema downgraded to L3-inferred when citation is absent

- GIVEN a finding that claims `L3-schema` oracle tier
- BUT the finding does NOT include a file path, line number, and literal contract text citation
- WHEN the oracle tier is validated (at runtime specialist level or at verify phase)
- THEN the tier MUST be automatically downgraded to `L3-inferred`
- AND the finding MUST NOT carry BLOCKER severity (it is capped at WARNING)
- AND the evidence record MUST note: "Downgraded from L3-schema — citation absent"

### Scenario: L3-inferred tier requires corroboration from two independent signals

- GIVEN a finding derived via static pattern extraction (Approach B) claiming `L3-inferred`
- WHEN the oracle tier is assigned
- THEN the finding MUST be supported by at least two independent signals (for example: a validation regex AND a matching error-message literal on the same code path)
- AND a single unsupported pattern match MUST be downgraded to L4
- AND the finding MUST list both signals in its evidence

### Scenario: L3-inferred tier caps at WARNING severity

- GIVEN a runtime finding at oracle tier `L3-inferred`
- WHEN the finding's severity is determined
- THEN the severity MUST NOT exceed WARNING
- AND if the finding would otherwise qualify as BLOCKER (e.g., critical path failure), it MUST be set to WARNING and annotated: "Capped at WARNING — L3-inferred oracle"
- AND the finding MUST NOT carry veto weight

### Scenario: L4 tier assigned when no project-specific oracle exists

- GIVEN a runtime finding whose expected behavior cannot be tied to an SDD spec, a test suite, or a code contract
- WHEN the runtime specialist assigns an oracle tier
- THEN it MUST assign `L4`
- AND the finding MUST cite the universal heuristic standard consulted (e.g., "WCAG 2.1 SC 1.4.3", "HTTP semantics — 4xx client error", "Google Core Web Vitals — LCP threshold 2.5s")
- AND the finding MUST NOT carry BLOCKER severity
- AND the finding MUST NOT carry veto weight

### Scenario: L4 tier never blocks delivery

- GIVEN any number of L4 findings in a runtime review
- WHEN the verdict is calculated
- THEN no L4 finding MUST produce a BLOCKER verdict contribution
- AND L4 findings MUST contribute at most WARNING to the verdict

---

## Requirement: Graceful Degradation When No L3 Source Exists

When no schema file or structured contract is discoverable for a verified path, the finding MUST explicitly declare the absence rather than silently dropping to L4.

### Scenario: Explicit declaration when no code contract found

- GIVEN a runtime step that inspects a behavior for which no schema, spec, or test suite entry exists
- WHEN the oracle is consulted
- THEN the evidence record MUST include the explicit statement: "No code contract found for this path"
- AND the tier MUST be set to `L4`
- AND the finding MUST be marked advisory

### Scenario: Project with no openspec directory still produces oracle-attributed findings

- GIVEN a target project that has no `openspec/` directory and no test suite
- WHEN a runtime review is executed against it
- THEN every finding MUST still declare an oracle tier
- AND at least one finding MUST be at tier L3 (schema or inferred) OR L4 with a stated heuristic
- AND the review MUST NOT fail or produce empty output solely because L1 and L2 are unavailable
- AND the review summary MUST note: "L1 (SDD spec) unavailable — no openspec directory found" and "L2 (test suite) unavailable — no test runner detected"

---

## Requirement: Oracle-Tier Blocking Matrix

The blocking matrix MUST be stated explicitly in `oracle-contract.md` and referenced by `severity-contract.md`.

### Scenario: Blocking matrix governs which tiers may produce BLOCKER

- GIVEN a finding at any oracle tier
- WHEN the severity is assigned
- THEN the following MUST hold:
  - `L1`: MAY produce BLOCKER
  - `L2`: MAY produce BLOCKER
  - `L3-schema`: MAY produce BLOCKER (requires mandatory citation)
  - `L3-inferred`: MUST NOT produce BLOCKER (capped at WARNING)
  - `L4`: MUST NOT produce BLOCKER (advisory only)
- AND this table MUST appear verbatim in `oracle-contract.md`

### Scenario: All five other shared contracts reference oracle-contract.md

- GIVEN the oracle-contract.md file exists at `skills/_shared/qase/oracle-contract.md`
- WHEN each of the other five shared contracts is inspected (`persistence-contract.md`, `engram-convention.md`, `openspec-convention.md`, `routing-rules.md`, `severity-contract.md`)
- THEN each MUST include a reference to `oracle-contract.md` (a link, import, or explicit "read and follow" instruction)
- AND no shared contract file MUST be orphaned from the oracle model

---

## Requirement: Oracle Tier in the Issue Format

Every browser and visual finding MUST carry the oracle tier as a required field.

### Scenario: Browser Testing Variant finding carries Oracle Tier field

- GIVEN a qa-browser finding produced after this change is applied
- WHEN the finding is written in Browser Testing Variant format
- THEN it MUST include an `**Oracle Tier**` field with one of: `L1`, `L2`, `L3-schema`, `L3-inferred`, `L4`
- AND the `L3-schema` value MUST be accompanied by the mandatory file/line/literal citation in the Evidence section

### Scenario: Visual Testing Variant finding carries Oracle Tier field

- GIVEN a qa-visual finding produced after this change is applied
- WHEN the finding is written in Visual Testing Variant format
- THEN it MUST include an `**Oracle Tier**` field with one of: `L1`, `L2`, `L3-schema`, `L3-inferred`, `L4`

### Scenario: Metadata envelope carries oracle_tier_breakdown

- GIVEN a qa-browser or qa-visual report produced after this change is applied
- WHEN the metadata envelope is inspected
- THEN it MUST include an `oracle_tier_breakdown` field listing the count of findings per tier
- AND the format MUST be: `oracle_tier_breakdown: { L1: N, L2: N, L3-schema: N, L3-inferred: N, L4: N }`
