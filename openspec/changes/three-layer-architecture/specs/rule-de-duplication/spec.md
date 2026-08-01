# Rule De-Duplication Specification

## Purpose

Define the single-source-of-truth discipline for normative rules: each rule is stated exactly once
in its owner file, referenced but never restated elsewhere, with ownership declared in a new
`skills/_shared/qase/rule-ownership.md` registry. A conflict between a procedure and a contract is
resolved by the contract; the specialist reports the conflict as a WARNING finding.

---

## Requirements

### Requirement: rule-ownership.md Exists and Is Machine-Readable

`skills/_shared/qase/rule-ownership.md` MUST exist and MUST register, for every normative rule, its
owner file and the literal string the linter matches on. The registry is the source the linter reads;
it is not documentation.

A normative rule is any statement using RFC 2119 keywords (MUST, SHALL, SHOULD, MUST NOT) that
governs specialist behaviour, severity, oracle tier, persistence, or routing.

#### Scenario: rule-ownership.md exists and is parseable by the linter

- GIVEN `skills/_shared/qase/rule-ownership.md` exists
- WHEN `scripts/lint_skills.sh` sources or reads it
- THEN the linter MUST successfully load the registry without error
- AND the registry MUST contain at least one entry for each shared contract file

#### Scenario: Registry entry format is complete

- GIVEN any entry in `rule-ownership.md`
- WHEN the entry is inspected
- THEN it MUST declare the owner file path
- AND it MUST declare the literal match string used by the linter
- AND the literal match string MUST appear in the owner file

---

### Requirement: Referencing Files Cite Rather Than Restate

Any SKILL.md or contract file that needs to rely on a normative rule owned by another file MUST
reference that file by name (e.g., "see `severity-contract.md`") rather than reproducing or
paraphrasing the rule text. A reproduction is detected when the registered literal rule string
appears in a file other than its owner.

#### Scenario: Registered rule string appears in exactly one file

- GIVEN a rule registered in `rule-ownership.md` with owner `severity-contract.md`
- WHEN the command `rg -l "<rule-string>" skills/` is run
- THEN the command MUST return exactly one file path
- AND that path MUST be `skills/_shared/qase/severity-contract.md`
- AND the linter MUST emit FAIL if the count is not exactly one

#### Scenario: severity-contract.md:15 self-declared restatement is removed

- GIVEN `skills/_shared/qase/severity-contract.md` after this change is applied
- WHEN the file is inspected for the string "This section restates"
- THEN the string MUST NOT be present
- AND the duplicated tier-ceiling table MUST NOT appear in `severity-contract.md`
- AND a reference to `oracle-contract.md` MUST replace it

#### Scenario: veto rule string appears only in severity-contract.md

- GIVEN the rule string "requires explicit user acknowledgment" (or its canonical form registered in
  `rule-ownership.md`)
- WHEN `rg -n 'requires explicit user acknowledgment|forces REJECT' skills/qa-*/SKILL.md` is run
- THEN the command MUST return zero matches
- AND the string MUST exist in `severity-contract.md` only

---

### Requirement: Contract Wins When Procedure Conflicts

When a specialist's procedure (SKILL.md) appears to contradict a shared contract, the shared
contract MUST take precedence. The specialist MUST report the contradiction as a WARNING finding
against the QASE installation rather than silently picking one interpretation. This is the conflict
protocol; it is owned by this change and SHALL be stated in `rule-ownership.md`.

#### Scenario: Specialist detects contradiction and reports WARNING

- GIVEN a `skills/qa-*/SKILL.md` whose Step N says "severity cap is X"
- AND `severity-contract.md` states the cap is Y (where X ≠ Y)
- WHEN the specialist executes Step N
- THEN it MUST apply cap Y (the contract value)
- AND it MUST produce a WARNING finding with text describing the contradiction and naming both files
- AND it MUST NOT silently apply X or suppress the conflict

#### Scenario: No specialist SKILL.md overrides a contract rule silently

- GIVEN any `skills/qa-*/SKILL.md` that contains a severity, veto, or oracle-tier statement
- WHEN the statement is compared to the corresponding rule in the owner contract file
- THEN the SKILL.md statement MUST be a citation or pointer (e.g., "per severity-contract.md")
- AND it MUST NOT be a restatement of the contract rule text

---

### Requirement: oracle-contract.md Is the Sole Tier Table Owner

The tier-to-max-severity table MUST appear exactly once, in `oracle-contract.md`.
`severity-contract.md` MUST reference `oracle-contract.md` for tier definitions and MUST NOT contain
a standalone tier table. After this change, `oracle-contract.md` is the sole owner of tier
definitions, citation rules, the resolution algorithm, and the blocking matrix.

#### Scenario: Tier table appears only in oracle-contract.md

- GIVEN the registered rule string for the tier-ceiling table (as declared in `rule-ownership.md`)
- WHEN `rg -l "<tier-ceiling-table-literal>" skills/` is run
- THEN the result MUST contain exactly one file: `skills/_shared/qase/oracle-contract.md`

#### Scenario: severity-contract.md no longer contains the word "restates"

- GIVEN `skills/_shared/qase/severity-contract.md` after this change is applied
- WHEN `rg -n 'restates' skills/_shared/qase/severity-contract.md` is run
- THEN the command MUST return zero matches

---

### Requirement: Ownership Pointers in SKILL.md Files

All 12 `skills/qa-*/SKILL.md` files MUST strip normative rules owned by shared contracts and replace
them with a pointer to the owner file. The rule-ownership clause already present in
`agents/qa-security.md` is the approved pattern.

#### Scenario: SKILL.md rule-ownership section present

- GIVEN any `skills/qa-*/SKILL.md` after this change is applied
- WHEN the file is inspected for a rule-ownership or rule-pointer section
- THEN it MUST contain a reference to at least `severity-contract.md`, `oracle-contract.md`, and
  `persistence-contract.md`
- AND it MUST NOT contain the registered literal string of any rule owned by those contracts
