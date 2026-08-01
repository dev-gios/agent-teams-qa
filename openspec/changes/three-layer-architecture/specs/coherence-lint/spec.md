# Coherence Lint Specification

## Purpose

Define the coherence checks added to `scripts/lint_skills.sh` via the new `scripts/lib/coherence.sh`
module. Every check MUST be mechanically assertable by a shell script — if the check cannot be
expressed as a concrete grep or file comparison, it does not belong here. Three defect classes were
found by a fresh-context review and are the concrete test cases. A fourth class (single-source
violation) is covered by the rule-de-duplication capability; it is referenced here for linter
integration only.

---

## Requirements

### Requirement: Forbidden-Token Check

For each skill file, a per-skill deny-list of forbidden tokens MUST be maintained in
`rule-ownership.md` (or a dedicated section thereof). When a registered forbidden token appears in
a file that declares it cannot emit that token, the linter MUST fail.

Concrete test case: `HAS_BLOCKERS` is a token in the result-contract of several skills. `qa-visual`
declares via `veto_power: false` and the severity contract that it cannot emit BLOCKERs. The string
`HAS_BLOCKERS` appearing in `skills/qa-visual/SKILL.md` (outside the metadata frontmatter field
`veto_power:`) is the exact defect the fresh review found.

The check is: `rg -n '<forbidden-token>' <skill-file>` returns a match in a file whose deny-list
registers that token as forbidden.

#### Scenario: Forbidden token detected in skill that cannot emit it

- GIVEN a fixture file `tests/fixtures/forbidden-token-bad.md` that is a copy of
  `skills/qa-visual/SKILL.md` with the string `HAS_BLOCKERS` inserted in a prose section
- WHEN `scripts/lint_skills.sh` (sourcing `coherence.sh`) processes the fixture
- THEN the linter MUST emit FAIL with a message naming `HAS_BLOCKERS` and the fixture file
- AND the linter MUST exit with a non-zero exit code

#### Scenario: Forbidden token absent — linter passes

- GIVEN `skills/qa-visual/SKILL.md` after this change is applied
- WHEN the forbidden-token check runs for `HAS_BLOCKERS` against `qa-visual`
- THEN the check MUST emit PASS
- AND the linter MUST NOT report a failure for this file

#### Scenario: Negative fixture proves the linter can fail

- GIVEN the three deliberately-broken fixture files created by this change
- WHEN `bash scripts/lint_skills.sh --fixtures-only` (or equivalent flag) runs
- THEN each fixture MUST cause at least one FAIL
- AND the linter MUST exit 1

---

### Requirement: Undefined-Placeholder Check

Every template variable in the form `<token>` or `{token}` that appears in a skill file or shared
contract MUST be defined within that file or explicitly cited as defined in a referenced contract.
A token that appears in the file but is defined in zero locations (neither locally nor by reference)
is an undefined placeholder.

Concrete test cases found by the fresh review:
1. `<evid>` used 3 times in `skills/qa-visual/SKILL.md`, defined 0 times.
2. `{page-slug}` used in `skills/qa-visual/SKILL.md` with no derivation algorithm stated in that
   file. (The algorithm exists in `openspec-convention.md`; the skill file must cite it.)

The check is:
- Extract all `<token>` and `{token}` patterns from the file.
- For each token, verify a definition line exists (`token:`, `### token`, or a cited-by-reference
  note) in the file or in a file the skill explicitly references by name.
- A token used but not defined and not cited is a FAIL.

#### Scenario: Undefined placeholder detected

- GIVEN a fixture file containing `<evid>` used in three places with no definition
- WHEN the undefined-placeholder check runs against the fixture
- THEN the linter MUST emit FAIL naming `<evid>` and the file
- AND the linter MUST exit 1

#### Scenario: Template variable with no derivation algorithm detected

- GIVEN a fixture file containing `{page-slug}` with no "page-slug derivation" section and no
  citation of `openspec-convention.md`
- WHEN the undefined-placeholder check runs against the fixture
- THEN the linter MUST emit FAIL naming `{page-slug}` and the file

#### Scenario: Template variable with cited derivation algorithm passes

- GIVEN `skills/qa-visual/SKILL.md` after this change, containing `{page-slug}` and a citation:
  "slug derived per `openspec-convention.md`"
- WHEN the undefined-placeholder check runs
- THEN the check MUST emit PASS for `{page-slug}` in that file

#### Scenario: Defined placeholder passes

- GIVEN a skill file containing `{review-id}` defined in its "Review ID Format" section
- WHEN the undefined-placeholder check runs
- THEN the check MUST emit PASS for `{review-id}`

---

### Requirement: Single-Source Check (Linter Integration)

The linter MUST read `rule-ownership.md` and, for each registered rule string, verify that the
string appears in exactly one file under `skills/`. If it appears in zero files, the registry is
stale (WARN). If it appears in more than one file, it is a duplication defect (FAIL).

This requirement is the mechanical enforcement of the rule-de-duplication capability. The linter
is the agent; `rule-ownership.md` is the registry it reads.

#### Scenario: Rule string found in more than one file

- GIVEN a rule string registered in `rule-ownership.md` with owner `severity-contract.md`
- AND the same string also appearing verbatim in `skills/qa-security/SKILL.md`
- WHEN the single-source check runs
- THEN the linter MUST emit FAIL naming both files and the offending string
- AND the linter MUST exit 1

#### Scenario: Rule string found in exactly one file (owner)

- GIVEN a rule string registered in `rule-ownership.md` with owner `oracle-contract.md`
- AND the string appearing only in `oracle-contract.md`
- WHEN the single-source check runs
- THEN the linter MUST emit PASS

#### Scenario: Rule string found in zero files

- GIVEN a rule string registered in `rule-ownership.md` whose literal has been removed from all files
- WHEN the single-source check runs
- THEN the linter MUST emit WARN indicating a stale registry entry
- AND the linter MUST NOT exit 1 for a stale entry (registry drift is a warning, not a blocker)

---

### Requirement: coherence.sh Is a Sourced Module

The coherence checks MUST live in `scripts/lib/coherence.sh` and MUST be loaded by `scripts/lint_
skills.sh` via `source "$LIB_DIR/coherence.sh"`. This follows the existing modular pattern
(`os_detect.sh`, `json_parser.sh`, `installer_core.sh`).

`coherence.sh` MUST NOT be executed directly as a standalone script. It is a library of functions,
not an entry point.

#### Scenario: lint_skills.sh sources coherence.sh

- GIVEN `scripts/lint_skills.sh` after this change is applied
- WHEN the file is inspected for `source` or `.` commands
- THEN it MUST contain `source "$LIB_DIR/coherence.sh"` (or `. "$LIB_DIR/coherence.sh"`)

#### Scenario: coherence.sh defines functions, not a main block

- GIVEN `scripts/lib/coherence.sh`
- WHEN the file is inspected
- THEN it MUST contain only function definitions (and optional comments)
- AND it MUST NOT contain top-level imperative code that executes on source

---

### Requirement: Agent/Skill Bijection Check in Linter

The linter MUST verify that the set of agent file stems under `agents/` is in exact bijection with
the set of `skills/qa-*/` directory names. An orphan in either direction is a FAIL.

#### Scenario: Bijection check detects orphan agent

- GIVEN `agents/qa-orphan.md` with no matching `skills/qa-orphan/SKILL.md`
- WHEN the bijection check runs
- THEN the linter MUST emit FAIL naming `qa-orphan` as an orphan with no matching skill
- AND the linter MUST exit 1

#### Scenario: Bijection check detects orphan skill

- GIVEN `skills/qa-orphan/SKILL.md` with no matching `agents/qa-orphan.md`
- WHEN the bijection check runs
- THEN the linter MUST emit FAIL naming `qa-orphan` as an orphan with no matching agent

#### Scenario: Bijection check passes when 12 pairs exist

- GIVEN exactly 12 `agents/qa-*.md` files each with a matching `skills/qa-*/SKILL.md`
- WHEN the bijection check runs
- THEN the linter MUST emit PASS with count 12 for each pair
