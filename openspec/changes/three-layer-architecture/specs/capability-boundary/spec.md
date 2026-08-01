# Capability Boundary Specification

## Purpose

Define `tools:` as a real security boundary, not a documentation field. Specify the exact tool sets
permitted per specialist class, and define how a specialist MUST behave when it needs a tool it was
not granted.

---

## Requirements

### Requirement: Tool Set Assignment per Specialist Class

The `tools:` frontmatter field in every agent file MUST reflect a deliberate, per-class decision.
Three classes exist:

| Class | Permitted tools | Rationale |
|-------|----------------|-----------|
| Static reviewers (qa-scan, qa-architect, qa-security, qa-advocate, qa-inclusion, qa-performance, qa-test-strategy, qa-init, qa-feedback) | `Read, Grep, Glob` plus Engram mem_ tools | Read-only analysis; no execution |
| Runtime specialists (qa-browser, qa-visual) | `Read, Grep, Glob, Bash` plus Engram mem_ tools | `agent-browser` CLI is launched via Bash; without Bash, runtime QA is impossible |
| Consensus / report (qa-report) | `Read, Grep, Glob` plus Engram mem_ tools | Aggregates reports already written; does not execute or browse |

`Write` MUST NOT appear in any specialist's `tools:` list. `Edit`, `MultiEdit`, and `NotebookEdit`
MUST NOT appear in any specialist's `tools:` list.

#### Scenario: Static reviewer grants only read tools

- GIVEN `agents/qa-security.md`
- WHEN the frontmatter `tools:` field is inspected
- THEN `Bash` MUST NOT appear in the tool list
- AND `Write` MUST NOT appear in the tool list
- AND `Edit` MUST NOT appear in the tool list

#### Scenario: Runtime specialist grants Bash

- GIVEN `agents/qa-browser.md`
- WHEN the frontmatter `tools:` field is inspected
- THEN `Bash` MUST appear in the tool list
- AND `Write` MUST NOT appear in the tool list

#### Scenario: qa-visual grants Bash, not Write

- GIVEN `agents/qa-visual.md`
- WHEN the frontmatter `tools:` field is inspected
- THEN `Bash` MUST appear in the tool list
- AND `Write` MUST NOT appear in the tool list
- AND `Edit` MUST NOT appear in the tool list

---

### Requirement: Write Is Removed from All Specialist Agents

No specialist agent MAY grant `Write`. This applies to `qa-security` (which currently lists `Write`)
and all eleven other specialists. The amendment of `agents/qa-security.md` to remove `Write` from
`tools:` and to delete the "Your `Write` access exists for exactly ONE purpose" paragraph is in
scope for this change.

`tools:` accepts tool names, not paths. A path-restricted write grant is not expressible; therefore
the only correct boundary is no `Write` grant.

#### Scenario: No agent grants Write

- GIVEN all files matching `agents/qa-*.md`
- WHEN the command `rg -n '^tools:.*\bWrite\b' agents/` is run
- THEN the command MUST return zero matches
- AND the linter MUST emit FAIL if any match is found

#### Scenario: qa-security amended paragraph is absent

- GIVEN `agents/qa-security.md` after this change is applied
- WHEN the file is inspected for the string "Your `Write` access exists"
- THEN the string MUST NOT be present
- AND no rationale for `Write` MAY remain in the file

---

### Requirement: Exactly Two Agents Grant Bash

Exactly two agent files — `qa-browser` and `qa-visual` — MUST grant `Bash`. All other agents MUST
NOT grant `Bash`. This is verifiable with a single grep command.

#### Scenario: Bash is limited to two runtime specialists

- GIVEN all files matching `agents/qa-*.md`
- WHEN the command `rg -l '^tools:.*\bBash\b' agents/` is run
- THEN the output MUST contain exactly two file paths
- AND those paths MUST be `agents/qa-browser.md` and `agents/qa-visual.md`
- AND the linter MUST emit FAIL if the count is not exactly two

---

### Requirement: Edit Family Tools Are Absent

No specialist agent MAY grant `Edit`, `MultiEdit`, or `NotebookEdit`. A specialist that cannot write
cannot edit; the edit tools are a subset of the write surface.

#### Scenario: No agent grants Edit, MultiEdit, or NotebookEdit

- GIVEN all files matching `agents/qa-*.md`
- WHEN the command `rg -n '^tools:.*\b(Edit|MultiEdit|NotebookEdit)\b' agents/` is run
- THEN the command MUST return zero matches
- AND the linter MUST emit FAIL if any match is found

---

### Requirement: Specialist Reports Limitation Rather Than Routing Around It

When a specialist's procedure appears to require a tool it was not granted, the specialist MUST
report the limitation as an INFO finding rather than attempting to fulfil the requirement using a
tool it does not hold. Routing around a capability boundary is a security violation, not a fallback.

This requirement protects the boundary's integrity: a specialist that silently adapts when missing a
tool renders `tools:` meaningless.

#### Scenario: Static reviewer cannot execute — reports limitation

- GIVEN `agents/qa-test-strategy.md` (static reviewer, no Bash)
- WHEN its procedure encounters a step that would require executing a test suite
- THEN it MUST NOT attempt to execute via any alternative mechanism
- AND it MUST produce an INFO finding describing what it could not verify and why
- AND `status` MUST be `partial` if the unverifiable step would have been material to the review

#### Scenario: Runtime specialist cannot browse — skips and reports

- GIVEN `agents/qa-browser.md`
- AND the preflight cache indicates `runtime_available: false`
- WHEN the agent is invoked
- THEN it MUST return `status: skipped` per `persistence-contract.md`
- AND it MUST NOT fabricate findings from static reading
- AND `verdict_contribution` MUST be `CLEAN`
