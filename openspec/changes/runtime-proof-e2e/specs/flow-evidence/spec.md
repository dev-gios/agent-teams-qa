# Flow Evidence Specification

## Purpose

Define the step-by-step executed evidence report that `qa-browser` produces for every user flow. The flow evidence document is the primary deliverable of a runtime review: a machine-readable, field-complete record of what was commanded, what was observed, what was expected (and from which oracle), and what artifact was captured for each step.

All agent-browser commands in this spec are verified against `openspec/changes/runtime-proof-e2e/agent-browser-command-reference.md`, which is the authoritative syntax source for agent-browser@0.32.2.

---

## Requirement: Per-Step Evidence Record

Every step of an executed user flow MUST produce a complete evidence record. A step missing any required field is a spec violation.

### Scenario: Complete per-step evidence record produced

- GIVEN a user flow with at least one step
- WHEN `qa-browser` executes that step
- THEN the evidence record for that step MUST include ALL of the following fields:
  - `**Action**`: the exact agent-browser CLI command(s) executed (e.g., `agent-browser find role button click --name "Sign In"`)
  - `**Observed**`: factual description of what the browser state was after the action (URL, visible text, HTTP status if observable, error state)
  - `**Expected**`: what the step was expected to produce, sourced from the oracle (not invented)
  - `**Oracle Tier**`: one of `L1`, `L2`, `L3-schema`, `L3-inferred`, `L4` — with a cited source
  - `**Status**`: one of `PASS`, `FAIL`, `INCONCLUSIVE`
  - `**Artifact**`: at minimum one screenshot path; additional paths for console log or network captures if applicable
- AND a step MUST NOT be recorded without all six fields present

### Scenario: FAIL status records the severity alongside the status

- GIVEN a step that fails
- WHEN the evidence record is written
- THEN `**Status**` MUST be `FAIL — BLOCKER` or `FAIL — WARNING` (never bare `FAIL`)
- AND the severity MUST respect the oracle-tier blocking matrix from `oracle-contract.md`

### Scenario: INCONCLUSIVE status used when step cannot be verified

- GIVEN a step where the browser connection is lost or the daemon times out mid-flow
- WHEN the evidence record is written
- THEN `**Status**` MUST be `INCONCLUSIVE` (not `FAIL`)
- AND the `**Observed**` field MUST describe the failure mode (e.g., "daemon connection lost during wait")
- AND the step MUST NOT be counted as a pass or a fail in the flow summary metrics

---

## Requirement: Per-Step Console and Error Buffer Clearing

Before each step executes, the console and error buffers MUST be cleared so that the step's diagnostics are isolated and attributable to that step alone.

### Scenario: Console buffer cleared before each step

- GIVEN a user flow being executed step by step
- WHEN `qa-browser` begins step N (where N >= 2)
- THEN `qa-browser` MUST execute `agent-browser console --clear` before the step's primary action
- AND the console output captured AFTER the step's action MUST be attributed exclusively to step N
- AND console output from step N-1 MUST NOT appear in step N's evidence record

### Scenario: Error buffer cleared before each step

- GIVEN a user flow being executed step by step
- WHEN `qa-browser` begins step N (where N >= 2)
- THEN `qa-browser` MUST execute `agent-browser errors --clear` before the step's primary action
- AND the errors captured after the step's action MUST be attributed exclusively to step N

### Scenario: First step does not require pre-clearing

- GIVEN a user flow beginning at step 1
- WHEN `qa-browser` executes step 1
- THEN it is ACCEPTABLE (but not required) to call `agent-browser console --clear` and `agent-browser errors --clear` before step 1
- AND any console or error output after step 1's action is attributed to step 1

---

## Requirement: Network Request Attribution Per Step

Each step MUST record the network requests it caused by clearing the network log before the step and reading it after.

### Scenario: Network requests cleared and attributed per step

- GIVEN a user flow step that triggers network activity (e.g., form submission, page navigation)
- WHEN `qa-browser` prepares for step N
- THEN it MUST execute `agent-browser network requests --clear` before the step's primary action
- AND after the step completes, it MUST execute `agent-browser network requests` to capture step-attributed requests
- AND the captured requests MUST be included in the step's evidence record under `**Artifact**` or inline in `**Observed**` when relevant to the finding

### Scenario: Failed network request attributed to the correct step

- GIVEN step N submits a form that triggers an API call returning 500
- WHEN the step evidence is recorded
- THEN the 5xx response MUST appear in step N's evidence
- AND it MUST NOT appear in step N+1's evidence (buffer was cleared before N+1)

---

## Requirement: Forced-Failure Steps via Network Interception

`qa-browser` MUST support steps that intentionally abort network routes to test error-handling paths. Syntax is verified against the agent-browser command reference.

### Scenario: Network route aborted for a forced-failure step

- GIVEN a flow step designed to test how the application handles an API failure
- WHEN `qa-browser` executes that step
- THEN it MUST execute `agent-browser network route "{url-pattern}" --abort` before the action that triggers the request
- AND the step's `**Action**` field MUST record both the route interception command and the triggering action
- AND after the step, `qa-browser` MUST execute `agent-browser network unroute` to remove the interception before subsequent steps
- AND the oracle tier for this step MUST be stated explicitly; the tier is `L4` unless a spec or code contract explicitly covers the failure path

### Scenario: Mock response injected for a forced-failure step

- GIVEN a flow step that injects a mock API response
- WHEN `qa-browser` executes that step
- THEN it MUST execute `agent-browser network route "{url-pattern}" --body '{json-body}'` before the triggering action
- AND `agent-browser network unroute` MUST be called after the step to restore normal network behavior

### Scenario: Forced-failure finding severity is L4 when no spec covers the error path

- GIVEN a step that aborts a network route and the observed error state is not covered by any L1/L2/L3 oracle
- WHEN the finding is recorded
- THEN the oracle tier MUST be `L4`
- AND the severity MUST NOT exceed WARNING
- AND the evidence MUST note: "No code contract or spec scenario found for this failure path — heuristic verdict only"

---

## Requirement: Video and HAR Artifacts

For a complete flow, `qa-browser` SHOULD capture a WebM video and a HAR network archive. These artifacts are tied to the flow as a whole (not per-step). Syntax verified against agent-browser command reference.

### Scenario: Video recording started before the flow and stopped after

- GIVEN a user flow at `deep` detail level OR when explicitly requested by the orchestrator
- WHEN `qa-browser` begins the flow
- THEN it MUST execute `agent-browser record start {artifact-path}.webm` before the first step
- AND after all steps complete (pass or fail), it MUST execute `agent-browser record stop`
- AND the video path MUST appear in the flow summary under `**Video evidence**`

### Scenario: HAR capture started before the flow and stopped after

- GIVEN a user flow at `deep` detail level OR when explicitly requested by the orchestrator
- WHEN `qa-browser` begins the flow
- THEN it MUST execute `agent-browser network har start` before the first step
- AND after all steps complete, it MUST execute `agent-browser network har stop {artifact-path}.har`
- AND the HAR path MUST appear in the flow summary under `**Network log**`

### Scenario: Video and HAR omitted at concise and standard depth unless explicitly requested

- GIVEN a user flow at `concise` or `standard` detail level
- AND the orchestrator did not explicitly request video or HAR
- WHEN `qa-browser` executes the flow
- THEN video recording and HAR capture MUST be omitted
- AND the flow summary MUST note which artifact types were skipped and why

---

## Requirement: Flow Summary

Every flow MUST conclude with a summary table that aggregates the step-level results.

### Scenario: Flow summary produced after all steps execute

- GIVEN a flow with N steps
- WHEN all steps have been executed (pass, fail, or inconclusive)
- THEN `qa-browser` MUST produce a flow summary table containing:
  - `Steps executed`: total count of steps attempted
  - `Passed / Failed`: count of PASS and FAIL steps (INCONCLUSIVE not included in either)
  - `BLOCKERs / WARNINGs`: count of findings by severity
  - `Video evidence`: file path if recorded, else `—`
  - `Network log`: HAR file path if recorded, else `—`
  - `Test Data Ledger`: table of identities and records created (see flow-evidence spec — write flows section)

---

## Requirement: Test Data Ledger for Write Flows

Any flow that creates records in the target application MUST include a Test Data Ledger in the flow evidence document.

### Scenario: Test Data Ledger records every generated identity

- GIVEN a flow step that creates a user account using a generated identity (e.g., `qase+{epoch}-{short-random}@example.com`)
- WHEN the flow evidence is finalized
- THEN the Test Data Ledger MUST list every identity and record created during the flow
- AND the ledger format MUST be:
  ```
  | Identity Type | Value | Created At |
  |---------------|-------|------------|
  | email         | qase+1722457123-x7f@example.com | 2026-07-31T14:32:03Z |
  ```
- AND the ledger MUST be present even if teardown was performed
- AND the ledger MUST note whether a teardown hook was invoked (yes/no) and the result if yes

### Scenario: Test Data Ledger absent for read-only flows

- GIVEN a flow that performs no write operations (navigation, observation, verification only)
- WHEN the flow evidence is finalized
- THEN the Test Data Ledger field MUST be set to `—` (not omitted)

---

## Requirement: Artifact Storage Paths

Flow evidence artifacts MUST be stored at deterministic paths in the active artifact store.

### Scenario: Flow evidence written in openspec mode

- GIVEN the artifact store mode is `openspec`
- AND the review ID is `{review-id}` and the flow slug is `{flow-slug}`
- WHEN `qa-browser` finalizes flow evidence
- THEN the evidence document MUST be written to `qaspec/reviews/{review-id}/flow-evidence/{flow-slug}.md`
- AND screenshots MUST be referenced by relative path from the review directory (e.g., `screenshots/flow-{flow-slug}-step-01.png`)
- AND video and HAR files MUST be referenced by relative path (e.g., `recordings/flow-{flow-slug}.webm`, `har/flow-{flow-slug}.har`)

### Scenario: Flow evidence written in engram mode

- GIVEN the artifact store mode is `engram`
- WHEN `qa-browser` finalizes flow evidence
- THEN it MUST call `mem_save` with:
  - `title`: `qase/{review-id}/flow-evidence/{flow-slug}`
  - `topic_key`: `qase/{review-id}/flow-evidence/{flow-slug}`
  - `type`: `architecture`
  - `project`: `{project}`
  - `content`: the full flow evidence markdown document
- AND the observation ID MUST be included in the browser report's `artifacts` list

---

## Requirement: Flow Evidence Document Structure

The flow evidence document MUST follow a defined structure so that it is machine-parseable by `qa-report`.

### Scenario: Flow evidence document structure is complete and parseable

- GIVEN a completed user flow
- WHEN the flow evidence document is written
- THEN it MUST follow this structure:

```markdown
## Flow Evidence: {flow-name}

**Started at**: {ISO-8601}
**App URL**: {url}
**Session**: {session-name | anonymous}
**Oracle sources consulted**: {list of tiers and sources found}

### Step 1: {Step description}

| Field | Value |
|-------|-------|
| **Action** | `{verified agent-browser command}` |
| **Observed** | {factual observation} |
| **Expected** | {expectation from oracle} |
| **Oracle Tier** | {tier} — {source citation} |
| **Status** | {PASS | FAIL — BLOCKER | FAIL — WARNING | INCONCLUSIVE} |
| **Artifact** | `{path(s)}` |

### Flow Summary

| Metric | Value |
|--------|-------|
| Steps executed | {N} |
| Passed / Failed | {P} / {F} |
| BLOCKERs / WARNINGs | {B} / {W} |
| Video evidence | {path | —} |
| Network log | {path | —} |

### Test Data Ledger

{table or —}
```

### Scenario: qa-report can parse flow evidence to extract findings

- GIVEN a flow evidence document written in the structure above
- WHEN `qa-report` processes the review
- THEN it MUST be able to extract all FAIL steps as findings
- AND apply veto logic based on the `**Oracle Tier**` field of each FAIL step
- AND include flow evidence findings in the deduplication pass
- AND include `qa-browser`'s flow evidence finding count in the final report's `oracle_tier_breakdown`
