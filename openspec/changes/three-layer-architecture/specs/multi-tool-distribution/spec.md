# Multi-Tool Distribution Specification

## Purpose

Define how `scripts/install.sh` distributes the new `agents/` layer and how each of the 8
`examples/*/qase.json` files declares agent installation. Skills MUST remain fully functional
without agents — the "Works everywhere" promise is not conditional on agent support. The agent layer
is an opt-in isolation and routing upgrade for tools that declare it.

---

## Requirements

### Requirement: install.sh Distributes agents/ When Declared

`scripts/install.sh` (via `scripts/lib/installer_core.sh`) MUST gain an `install_agents_to_path()`
function alongside the existing `install_skills_to_path()`. When a `qase.json` contains an
`install_agents.<os>` key for the current OS, `install_tool()` MUST call `install_agents_to_path()`
in addition to `install_skills_to_path()`. When the key is absent, `install_tool()` MUST call only
`install_skills_to_path()` and MUST NOT attempt to create an agents directory or produce an error.

#### Scenario: Tool with install_agents block receives both skills and agents

- GIVEN `examples/claude-code/qase.json` containing `"install_agents": { "linux": "$HOME/.claude/agents" }`
- AND the current OS is `linux`
- WHEN `bash scripts/install.sh --agent claude-code` runs
- THEN skills MUST be copied to `$HOME/.claude/skills`
- AND agent files MUST be copied to `$HOME/.claude/agents`
- AND the install MUST exit 0

#### Scenario: Tool without install_agents block receives skills only

- GIVEN `examples/gemini-cli/qase.json` with no `install_agents` key
- WHEN `bash scripts/install.sh --agent gemini-cli` runs
- THEN skills MUST be copied to the declared install path
- AND no agents directory MUST be created
- AND the install MUST exit 0 without an agents-related error

#### Scenario: install_test.sh asserts agents land at declared target

- GIVEN a fresh install for a tool that declares `install_agents`
- WHEN `bash scripts/install_test.sh` runs
- THEN it MUST verify that `agents/qa-*.md` files exist at the declared `install_agents` path
- AND it MUST verify that no installed agent grants `Write`
- AND it MUST exit 0

---

### Requirement: Skills-Only Remains a Complete and Supported Configuration

Installing skills without agents MUST be fully functional for all six non-Claude-Code toolchains.
A skills-only install MUST provide all 12 specialist procedures and all shared contracts. The
orchestrator for a skills-only tool loads specialists as prompt context, not as native agents. No
feature of QASE that is currently available via skills-only MUST be removed by this change.

#### Scenario: Fresh skills-only install for gemini-cli succeeds

- GIVEN `examples/gemini-cli/qase.json` with no `install_agents` key
- WHEN a fresh install runs for `gemini-cli` on linux
- THEN all 12 `skills/qa-*/SKILL.md` files MUST be present at the install target
- AND all `skills/_shared/qase/*.md` files MUST be present
- AND no error MUST be emitted about agents
- AND the install MUST exit 0

#### Scenario: skills-only tool can still run a full qa-review pipeline

- GIVEN a tool configured with skills only (no agents)
- WHEN the orchestrator for that tool loads `qa-security/SKILL.md` as prompt context
- THEN the skill procedure MUST be fully readable and self-sufficient
- AND the shared contracts referenced in the skill MUST be resolvable from the install path

---

### Requirement: qase.json Files Declare Optional install_agents Block

Each of the 8 `examples/*/qase.json` files MUST either declare an `install_agents` block or omit
it entirely. There is no default or fallback agents path — omission means skills-only.

Claude Code is the only tool with a native agents directory today. Its `qase.json` MUST declare
`install_agents`. The other seven tools (codex, cursor, gemini-cli, mock-tool, opencode, vscode,
antigravity) MAY omit `install_agents` or MAY declare it if their platform supports it.

`examples/mock-tool/qase.json` is a test fixture. It MUST get `install_agents` only if
`scripts/install_test.sh` requires it to verify agent installation logic.

#### Scenario: claude-code qase.json declares install_agents

- GIVEN `examples/claude-code/qase.json` after this change is applied
- WHEN the file is parsed
- THEN it MUST contain an `install_agents` object with at least a `linux` key
- AND the value MUST be `$HOME/.claude/agents` (or equivalent per OS)

#### Scenario: codex qase.json lacks install_agents — linter accepts it

- GIVEN `examples/codex/qase.json` with no `install_agents` key
- WHEN `validate_qase_json` in `install.sh` processes the file
- THEN it MUST accept the file as valid
- AND it MUST NOT report a missing-field error for `install_agents`

#### Scenario: mock-tool qase.json structure is valid for test purposes

- GIVEN `examples/mock-tool/qase.json`
- WHEN `validate_qase_json` processes the file
- THEN it MUST pass validation
- AND if `install_test.sh` needs agents verification, the file MUST declare `install_agents`

---

### Requirement: installer_core.sh Gains install_agents_to_path()

`scripts/lib/installer_core.sh` MUST gain a new function `install_agents_to_path(target_path,
tool_name, agents_src)` that mirrors the signature and behaviour of `install_skills_to_path()`.
The function MUST copy only `agents/qa-*.md` files (not subdirectories) to the target path. It
MUST create the target directory if it does not exist. It MUST log the files installed and any
errors encountered.

#### Scenario: install_agents_to_path copies agent files to target

- GIVEN `install_agents_to_path` called with `target=/tmp/test-agents, agents_src=$REPO/agents`
- WHEN the function executes
- THEN all `agents/qa-*.md` files MUST be copied to `/tmp/test-agents/`
- AND the function MUST return 0 on success

#### Scenario: install_agents_to_path creates target directory if absent

- GIVEN a target directory that does not exist
- WHEN `install_agents_to_path` is called
- THEN the function MUST create the target directory (equivalent to `mkdir -p`)
- AND the copy MUST succeed

#### Scenario: Agent-install step is skipped when install_agents key absent in qase.json

- GIVEN a `qase.json` with no `install_agents` key
- WHEN `install_tool` resolves the agents path with `get_agents_path(json, OS)`
- THEN `get_agents_path` MUST return an empty string
- AND `install_tool` MUST NOT call `install_agents_to_path`
