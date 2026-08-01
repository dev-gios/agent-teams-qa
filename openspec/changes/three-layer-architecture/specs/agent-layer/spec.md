# Agent Layer Specification

## Purpose

Define the structure, constraints, and behaviour of the twelve `agents/qa-*.md` files that form the
new thin-agent layer. An agent file provides process isolation, a `tools` capability boundary, and a
routing `description`. It does NOT contain procedure or normative rules — those live in the matching
`SKILL.md` and in `skills/_shared/qase/`.

---

## Requirements

### Requirement: Required Frontmatter Fields

Every `agents/qa-*.md` file MUST contain a YAML frontmatter block (delimited by `---`) that declares
exactly the fields `name`, `description`, `model`, and `tools`. No additional frontmatter fields are
required; no required field MAY be omitted.

`name` MUST equal the filename stem (e.g., `qa-security`) and MUST equal the matching skill directory
name under `skills/`. `description` MUST be non-empty and MUST name the trigger condition that causes
an orchestrator to select this agent.

Verified reference pattern: `sdd-verify.md` frontmatter — `name`, `description`, `model`, `tools`.
The `review-readability.md` pattern (rules embedded in agent body) is explicitly rejected for QASE
agents; agent bodies contain only pointers to SKILL.md and shared contracts.

#### Scenario: Valid agent frontmatter accepted by the linter

- GIVEN an `agents/qa-*.md` file with a frontmatter block containing `name`, `description`, `model`,
  and `tools`
- WHEN `scripts/lint_skills.sh` validates the file
- THEN the linter MUST emit PASS for each required field
- AND the linter MUST NOT report a missing-field failure

#### Scenario: Missing frontmatter field detected

- GIVEN an `agents/qa-*.md` file whose frontmatter omits `description`
- WHEN `scripts/lint_skills.sh` validates the file
- THEN the linter MUST emit a FAIL for the missing field
- AND the linter MUST exit with a non-zero exit code

#### Scenario: name field matches filename stem and skill directory

- GIVEN `agents/qa-architect.md` with `name: qa-architect`
- WHEN the linter performs the bijection check
- THEN `skills/qa-architect/SKILL.md` MUST exist
- AND the linter MUST emit PASS for the bijection check
- AND no orphan agent or orphan skill MUST exist

---

### Requirement: Thin-Agent Contract (pointer, not procedure)

Every agent body MUST contain an explicit reference to its own `SKILL.md` path and to
`skills/_shared/qase/persistence-contract.md`. The body MUST NOT restate, summarize, or paraphrase
any normative rule owned by a shared contract. Procedure and rules appear in the referenced files
only.

An agent body that duplicates a rule creates a second source of truth. The conflict protocol
(contract wins, specialist reports WARNING) from `severity-contract.md` applies at installation time
as a lint failure.

#### Scenario: Agent body references its SKILL.md

- GIVEN `agents/qa-security.md`
- WHEN the agent body is inspected
- THEN it MUST contain a reference to `skills/qa-security/SKILL.md` (or its resolved install path)
- AND it MUST contain a reference to `persistence-contract.md`

#### Scenario: Agent body contains no restated normative rule

- GIVEN any `agents/qa-*.md` file
- WHEN the linter checks for registered rule strings from `rule-ownership.md`
- THEN no registered rule string MUST appear in the agent body
- AND if a match is found, the linter MUST emit FAIL with the offending string and its owner file

---

### Requirement: Startup Guard

Every agent MUST include a startup guard that verifies its contract files are readable before
proceeding. If any required file cannot be read, the agent MUST return `status: blocked` naming the
unreadable file. It MUST NOT proceed from memory or produce findings without its contracts.

#### Scenario: Startup guard blocks when SKILL.md is unreadable

- GIVEN an agent whose `SKILL.md` does not exist at the declared install path
- WHEN the agent is invoked
- THEN it MUST return `status: blocked`
- AND the response MUST name the missing file
- AND it MUST NOT produce any findings or verdict contribution

#### Scenario: Startup guard blocks when a shared contract is unreadable

- GIVEN an agent that lists `persistence-contract.md` as a required contract
- AND `persistence-contract.md` is not readable at the resolved path
- WHEN the agent is invoked
- THEN it MUST return `status: blocked` naming `persistence-contract.md`

#### Scenario: Startup guard passes when all files are readable

- GIVEN an agent whose SKILL.md and all listed shared contracts are readable
- WHEN the agent is invoked
- THEN the startup guard MUST pass silently
- AND the agent MUST proceed to execute its skill procedure

---

### Requirement: No-Delegation Constraint

Every agent MUST include an explicit instruction that it is the executor, NOT the orchestrator. It
MUST NOT call the Task tool, MUST NOT launch sub-agents, and MUST NOT delegate further. All work is
performed inline in the agent's context window.

#### Scenario: Agent declares do-not-delegate instruction

- GIVEN any `agents/qa-*.md` file
- WHEN the agent body is inspected
- THEN it MUST contain an instruction equivalent to: "Do NOT call the Task tool. Do NOT launch
  sub-agents."
- AND the linter MUST emit FAIL if this instruction is absent

#### Scenario: Agent does not invoke Task during execution

- GIVEN an agent that has received a review scope
- WHEN it executes its skill procedure
- THEN it MUST NOT emit a Task tool call
- AND all specialist work MUST be performed in the single agent context

---

### Requirement: Result Contract

Every agent MUST declare and return a structured result envelope containing: `status`, `executive_
summary`, `artifacts`, `verdict_contribution`, `risks`, and `skill_resolution`.

`status` MUST be one of `done`, `blocked`, or `partial`. `verdict_contribution` MUST be one of
`CLEAN`, `HAS_WARNINGS`, or `HAS_BLOCKERS` per `severity-contract.md`.

#### Scenario: Specialist returns complete result envelope

- GIVEN a specialist agent that has completed its review
- WHEN it returns its result
- THEN the result MUST contain `status`, `executive_summary`, `artifacts`, `verdict_contribution`,
  `risks`, and `skill_resolution`
- AND `verdict_contribution` MUST be one of `CLEAN`, `HAS_WARNINGS`, `HAS_BLOCKERS`

#### Scenario: Blocked specialist returns minimal envelope

- GIVEN a specialist that returned `status: blocked` at startup
- WHEN the orchestrator reads the result
- THEN `status` MUST be `blocked`
- AND `verdict_contribution` MUST NOT be `HAS_BLOCKERS` (a blocked agent makes no finding)
- AND `artifacts` MUST be empty or `none`

---

### Requirement: Agent Set Is a Bijection with Skills

The set of agent file stems MUST be in exact bijection with the set of `skills/qa-*/` directory
names. Exactly 12 agents and 12 skill directories are required. No agent MAY exist without a
matching skill directory; no skill directory MAY exist without a matching agent file.

#### Scenario: Bijection check passes when all 12 pairs exist

- GIVEN `agents/` containing exactly 12 `qa-*.md` files
- AND `skills/` containing exactly 12 `qa-*/` directories
- AND every stem appearing in one set also appears in the other
- WHEN the linter runs the bijection check
- THEN it MUST emit PASS with count 12

#### Scenario: Orphan agent detected

- GIVEN `agents/qa-orphan.md` with no matching `skills/qa-orphan/SKILL.md`
- WHEN the linter runs the bijection check
- THEN it MUST emit FAIL naming `qa-orphan` as an orphan agent

#### Scenario: Agent file stays under 120 lines

- GIVEN any `agents/qa-*.md` file
- WHEN `wc -l` is applied to the file
- THEN the line count MUST NOT exceed 120
- AND the linter MUST emit FAIL if the threshold is exceeded
