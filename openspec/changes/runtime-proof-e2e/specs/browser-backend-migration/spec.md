# Browser Backend Migration Specification

## Purpose

Define the complete migration from Chrome DevTools MCP tool calls to agent-browser CLI commands in `qa-browser` and `qa-visual`. After this change, QASE skills MUST invoke agent-browser exclusively through the CLI via Bash. The agent-browser MCP `core` tools profile MUST NOT be used as a backend. All commands in this spec are verified against `openspec/changes/runtime-proof-e2e/agent-browser-command-reference.md` (agent-browser@0.32.2).

---

## Requirement: No Chrome DevTools MCP Tool References Remain

After this change, every Chrome DevTools MCP tool reference MUST be removed from the affected skill files.

### Scenario: Zero MCP tool references in affected skill files

- GIVEN the change has been applied to `skills/qa-browser/SKILL.md` and `skills/qa-visual/SKILL.md`
- WHEN the following grep is executed:
  `rg -n "navigate_page|take_snapshot|take_screenshot|evaluate_script|wait_for|resize_page|list_console_messages|list_network_requests|get_network_request|get_console_message|performance_start_trace|performance_stop_trace|performance_analyze_insight|emulate\(" skills/`
- THEN the command MUST return zero matches
- AND any match is a CRITICAL failure of this spec

### Scenario: Zero "Chrome DevTools MCP" string references in affected files and registry

- GIVEN the change has been applied
- WHEN the following grep is executed:
  `rg -ni "chrome devtools mcp" skills/ README.md .atl/skill-registry.md`
- THEN the command MUST return zero matches
- AND any match is a CRITICAL failure of this spec

### Scenario: MCP core tools profile explicitly excluded as a backend

- GIVEN the change has been applied to `skills/qa-browser/SKILL.md`
- WHEN the file is inspected for backend documentation
- THEN the file MUST include an explicit statement that the agent-browser MCP `core` tools profile is NOT a supported backend
- AND the rationale MUST be stated: "The MCP `core` tools profile is a curated subset; it lacks network interception, full session, and debug capabilities required by QASE"
- AND the file MUST state that skills invoke the CLI via Bash

---

## Requirement: Complete Command Mapping — Navigation and State

### Scenario: navigate_page(url) replaced by agent-browser open

- GIVEN `qa-browser` or `qa-visual` needs to navigate to a URL
- WHEN the skill executes navigation
- THEN it MUST use `agent-browser open <url>` (with or without `https://` prefix; the CLI prepends it automatically)
- AND it MUST NOT use `navigate_page(url)`

### Scenario: wait_for("load") replaced by agent-browser wait --load

- GIVEN the skill needs to wait for a page load state
- WHEN the skill executes a load wait
- THEN it MUST use `agent-browser wait --load networkidle` (or `load` or `domcontentloaded` as appropriate)
- AND it MUST NOT use `wait_for("load")` or `wait networkidle` (the bare form without `--load` is INVALID)
- AND the verify phase MUST check that `rg -n "wait networkidle" skills/` returns zero matches

### Scenario: Session flags are global and precede the subcommand

- GIVEN the skill needs to open a URL with a named session and restore state
- WHEN the command is written
- THEN the CORRECT form is `agent-browser --session "$S" --restore open <url>`
- AND the INCORRECT form `agent-browser open --session qa-auth --restore <url>` MUST NOT appear in any skill file
- AND `--session` and `--restore` MUST appear before the subcommand (`open`), not after it

### Scenario: Session ID derived stably from worktree scope

- GIVEN the skill needs a stable, reproducible session name for QASE browser testing
- WHEN a session ID is generated
- THEN it MUST use `agent-browser session id --scope worktree --prefix qase`
- AND the result MUST be captured in a variable: `S="$(agent-browser session id --scope worktree --prefix qase)"`
- AND hand-built session names MUST NOT be used for repeatability-sensitive flows

---

## Requirement: Complete Command Mapping — Inspection and Capture

### Scenario: take_screenshot() replaced by agent-browser screenshot

- GIVEN the skill needs to capture a screenshot
- WHEN the command is written
- THEN it MUST use `agent-browser screenshot` (optionally with `--full` for full-page or `--annotate` for labeled elements)
- AND it MUST NOT use `take_screenshot()`

### Scenario: take_snapshot() replaced by agent-browser snapshot

- GIVEN the skill needs the accessibility tree
- WHEN the command is written
- THEN it MUST use `agent-browser snapshot` (optionally with `-i` for interactive-only, `--compact`, `--depth <n>`, or `-s <selector>`)
- AND it MUST NOT use `take_snapshot()`

### Scenario: evaluate_script() replaced by agent-browser eval

- GIVEN the skill needs to execute JavaScript
- WHEN the command is written
- THEN it MUST use `agent-browser eval "<expression>"` for simple expressions
- AND for complex or multiline scripts it MUST use `agent-browser eval --stdin` (heredoc) or `agent-browser eval -b <base64>`
- AND inline `eval "<complex-multi-line-script>"` MUST NOT be used for scripts that contain shell special characters

### Scenario: list_console_messages() replaced by agent-browser console

- GIVEN the skill needs to read console output
- WHEN the command is written
- THEN it MUST use `agent-browser console` to read all output
- AND it MUST use `agent-browser console --clear` to clear the buffer
- AND it MUST NOT use `list_console_messages()` or `get_console_message(id)`

### Scenario: list_network_requests() and get_network_request() replaced

- GIVEN the skill needs to inspect network requests
- WHEN the commands are written
- THEN `list_network_requests()` MUST be replaced by `agent-browser network requests` (optionally with `--filter <pattern>`, `--type <csv>`, `--method <method>`, `--status <code>`)
- AND `get_network_request(id)` MUST be replaced by `agent-browser network request <requestId>`
- AND `agent-browser network requests --clear` MUST be used for per-step buffer clearing

### Scenario: resize_page(w, h) replaced by agent-browser set viewport

- GIVEN the skill needs to change the viewport
- WHEN the command is written
- THEN it MUST use `agent-browser set viewport <w> <h>` (optionally with a third scale argument for retina)
- AND it MUST NOT use `resize_page(w, h)`

---

## Requirement: Complete Command Mapping — Performance and Emulation

### Scenario: performance_start_trace / performance_stop_trace replaced by agent-browser vitals

- GIVEN the skill needs Core Web Vitals
- WHEN the command is written
- THEN it MUST use `agent-browser vitals [url] [--json]` as the primary mechanism
- AND it MUST NOT use `performance_start_trace()`, `performance_stop_trace()`, or `performance_analyze_insight()` in QASE skills
- AND the trace/profiler commands (`agent-browser trace start/stop`, `agent-browser profiler start/stop`) remain available for deep-mode debugging, not as the default metrics path

### Scenario: emulate({reducedMotion}) replaced by agent-browser set media

- GIVEN the skill needs to emulate color scheme or reduced-motion preference
- WHEN the command is written
- THEN it MUST use `agent-browser set media dark` or `agent-browser set media light reduced-motion`
- AND the CORRECT forms are `set media dark` and `set media light reduced-motion` (as documented in the command reference)
- AND the INCORRECT forms `set media reduced-motion` (missing scheme) MUST NOT appear in any skill file
- AND it MUST NOT use `emulate({reducedMotion: ...})`

---

## Requirement: New CLI Capabilities Available After Migration

The migration makes capabilities available that Chrome DevTools MCP never provided. These MUST be used where the spec requires them.

### Scenario: Network route interception available via CLI

- GIVEN `qa-browser` needs to abort a network request for a forced-failure test step
- WHEN the command is written
- THEN it MUST use `agent-browser network route "{url-pattern}" --abort`
- AND to inject a mock response it MUST use `agent-browser network route "{url-pattern}" --body '{json}'`
- AND to remove an interception it MUST use `agent-browser network unroute`

### Scenario: Video recording available via CLI

- GIVEN `qa-browser` needs to record a flow execution as video
- WHEN the recording commands are written
- THEN it MUST use `agent-browser record start {path}.webm` to begin and `agent-browser record stop` to finalize
- AND the `record restart {path}.webm` form is available for re-takes

### Scenario: HAR capture available via CLI

- GIVEN `qa-browser` needs to capture the full network archive for a flow
- WHEN the commands are written
- THEN it MUST use `agent-browser network har start` before the flow and `agent-browser network har stop {path}.har` after the flow

### Scenario: Visual diff available via CLI

- GIVEN `qa-visual` needs to compare the current page against a stored baseline screenshot
- WHEN the command is written
- THEN it MUST use `agent-browser diff screenshot --baseline <file>` (optionally with `--threshold <0-1>`, `--output <file>`, `--selector <sel>`, `--full`)
- AND this command is IN SCOPE and confirmed to exist in agent-browser@0.32.2
- AND snapshot diff is `agent-browser diff snapshot [-b <file>] [-s <sel>] [-c] [-d <n>]`
- AND url diff is `agent-browser diff url <url1> <url2> [options]`

### Scenario: cookies get available as the default operation

- GIVEN `qa-browser` needs to retrieve all cookies for the current session
- WHEN the command is written
- THEN it MUST use `agent-browser cookies get` or simply `agent-browser cookies` (get is the default operation)
- AND to set a cookie it MUST use `agent-browser cookies set <name> <value> [options]`
- AND to clear cookies it MUST use `agent-browser cookies clear`

---

## Requirement: Command Correctness Discipline

Every agent-browser command string written into a skill file MUST be verifiable against `openspec/changes/runtime-proof-e2e/agent-browser-command-reference.md`.

### Scenario: wait --load networkidle is the only valid wait-for-load form

- GIVEN any skill file containing a wait-for-networkidle command
- WHEN the verify phase scans skill files
- THEN `rg -n "wait networkidle" skills/` MUST return zero matches
- AND every load-state wait MUST use the form `agent-browser wait --load {state}` where `{state}` is one of `load`, `domcontentloaded`, `networkidle`

### Scenario: Global flags precede the subcommand in all session-bearing commands

- GIVEN any skill file that uses `--session` or `--restore`
- WHEN the verify phase scans skill files
- THEN every occurrence MUST follow the pattern `agent-browser --session "{name}" [--restore] <subcommand> [args]`
- AND the pattern `agent-browser <subcommand> --session "{name}"` MUST NOT appear

### Scenario: sdd-verify enumerates all agent-browser commands in touched skill files and spot-checks each

- GIVEN the apply phase has completed
- WHEN sdd-verify runs
- THEN it MUST enumerate every `agent-browser` command string in `skills/qa-browser/SKILL.md`, `skills/qa-visual/SKILL.md`, and `skills/qa-init/SKILL.md`
- AND for each command, verify that the subcommand and flags appear in `openspec/changes/runtime-proof-e2e/agent-browser-command-reference.md`
- AND any command not found in the reference MUST be reported as a CRITICAL failure

---

## Requirement: Skill-Registry Entry Updated

The skill registry at `.atl/skill-registry.md` MUST be updated to reflect the new backend.

### Scenario: qa-browser registry entry no longer mentions Chrome DevTools MCP

- GIVEN `.atl/skill-registry.md` after this change is applied
- WHEN the `qa-browser` row is inspected
- THEN the `Trigger / description` MUST NOT contain the phrase "Chrome DevTools MCP"
- AND it MUST describe the agent-browser CLI as the backend

### Scenario: qa-visual registry entry no longer mentions Chrome DevTools MCP

- GIVEN `.atl/skill-registry.md` after this change is applied
- WHEN the `qa-visual` row is inspected
- THEN the `Trigger / description` MUST NOT contain the phrase "Chrome DevTools MCP"
- AND it MUST describe the agent-browser CLI as the backend
