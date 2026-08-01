# Runtime Preflight Specification

## Purpose

Define the behavior of the Runtime Preflight (Browser Backend) step added to `qa-init`. The preflight proves browser connectivity rather than mere binary presence, caches the result to the active artifact store, and surfaces Bash unavailability as a distinct and recorded failure reason. It detects likely app-start commands and surfaces them as suggestions only — it MUST NOT execute them.

---

## Requirement: Preflight Step Positioning and Trigger

The Runtime Preflight MUST execute as the final step of `qa-init`, after all existing project-context detection steps and before the return summary.

### Scenario: Runtime preflight runs as the last qa-init step

- GIVEN `qa-init` is invoked in any project
- WHEN all prior detection steps (stack, architecture, quality tooling) complete
- THEN `qa-init` MUST execute the Runtime Preflight (Browser Backend) step
- AND the preflight result MUST be included in the qa-init return summary
- AND the preflight cache MUST be written to the active artifact store before the summary is returned

---

## Requirement: Bash Availability Check

Before any agent-browser CLI command is attempted, `qa-init` MUST check whether a Bash tool is available to the executor.

### Scenario: Bash unavailability recorded as a distinct reason

- GIVEN `qa-init` is running in an executor that has no Bash tool
- WHEN the Runtime Preflight step begins
- THEN `qa-init` MUST record `runtime_available: false` in the preflight cache
- AND the `unavailable_reason` field MUST be set to `"bash-unavailable"`
- AND the preflight cache MUST NOT record any agent-browser version, Chrome binary, or smoke test result
- AND `qa-init` MUST NOT attempt any agent-browser commands
- AND the return summary MUST include the note: "Runtime preflight skipped — no Bash tool available in this executor"

---

## Requirement: agent-browser Detection

When Bash is available, `qa-init` MUST determine whether `agent-browser` is installed.

### Scenario: agent-browser detected by version command

- GIVEN Bash is available
- WHEN `qa-init` executes `agent-browser --version`
- AND the command exits with code `0`
- THEN `qa-init` MUST record `agent_browser.available: true` and `agent_browser.version: "{version string}"`
- AND the preflight MUST proceed to the doctor check

### Scenario: agent-browser absent — install instructions surfaced, not executed

- GIVEN Bash is available
- WHEN `qa-init` executes `agent-browser --version`
- AND the command fails (command not found or non-zero exit)
- THEN `qa-init` MUST record `agent_browser.available: false`
- AND `qa-init` MUST surface install instructions: "`npm i -g agent-browser && agent-browser install`; on Linux hosts, `agent-browser install --with-deps` may be required"
- AND `qa-init` MUST NOT execute any install command without explicit user consent
- AND the preflight MUST record `runtime_available: false` with `unavailable_reason: "agent-browser-not-installed"`
- AND the preflight MUST stop — no further checks are performed

---

## Requirement: Doctor Check as Primary Diagnostic

When `agent-browser` is present, `agent-browser doctor --json` is the primary health and connectivity check. It supersedes manual Chrome binary probing as the detection mechanism.

### Scenario: doctor exits 0 — preflight proceeds to smoke test

- GIVEN `agent-browser` is installed
- WHEN `qa-init` executes `agent-browser doctor --json`
- AND the command exits with code `0` (all checks pass; warnings are acceptable)
- THEN `qa-init` MUST record `doctor_result: passed`
- AND the preflight MUST proceed to the smoke connection test
- AND the Chrome binary found by `doctor` MUST be recorded in `chrome_binary.name` if extractable from the JSON output

### Scenario: doctor exits 1 — failure recorded, Chrome probing used as fallback diagnostic

- GIVEN `agent-browser` is installed
- WHEN `qa-init` executes `agent-browser doctor --json`
- AND the command exits with code `1` (at least one check failed)
- THEN `qa-init` MUST record `doctor_result: failed` and capture the failure detail from the JSON output
- AND `qa-init` MUST fall back to manual multi-name Chrome probing as a diagnostic step (see Scenario below)
- AND `qa-init` MUST record `runtime_available: false` with `unavailable_reason: "doctor-check-failed"` unless the smoke test subsequently passes

### Scenario: doctor output cannot be parsed — Chrome probing used as fallback

- GIVEN `agent-browser doctor --json` runs but produces output that cannot be parsed as JSON
- WHEN `qa-init` processes the output
- THEN `qa-init` MUST fall back to manual multi-name Chrome probing as a fallback diagnostic
- AND `qa-init` MUST record `doctor_result: parse-error`

---

## Requirement: Multi-Name Chrome Binary Probing as Fallback

When `doctor` is unavailable or its output cannot be parsed, `qa-init` MUST probe multiple Chrome binary names in order.

### Scenario: Chrome binary found under a non-default name

- GIVEN `agent-browser doctor` is unavailable or failed to parse
- WHEN `qa-init` probes Chrome binary names in order: `chromium`, `google-chrome-stable`, `google-chrome`, `chrome`
- AND `chromium` is found (exits 0) while `google-chrome` is absent
- THEN `qa-init` MUST record `chrome_binary.available: true` and `chrome_binary.name: "chromium"`
- AND `qa-init` MUST NOT report the environment as broken solely because `google-chrome` was absent
- AND the preflight MUST proceed to the smoke connection test

### Scenario: No Chrome binary found under any probed name

- GIVEN all probed Chrome binary names return non-zero exit or command-not-found
- WHEN `qa-init` completes the multi-name probe
- THEN `qa-init` MUST record `chrome_binary.available: false` and `chrome_binary.name: null`
- AND `qa-init` MUST surface the note: "`agent-browser install` downloads Chrome on first use if no system binary is found"
- AND the preflight MUST record `runtime_available: false` with `unavailable_reason: "no-chrome-binary"`

---

## Requirement: Real Smoke Connection Test

A passing `doctor` or a found Chrome binary does not prove that this executor, in this sandbox, can drive a page. The smoke connection test provides that proof.

### Scenario: Smoke test passes — runtime confirmed available

- GIVEN `agent-browser` is installed AND `doctor --json` exited 0 (or Chrome binary was found via fallback probing)
- WHEN `qa-init` executes `agent-browser open about:blank` followed by `agent-browser close`
- AND both commands succeed (exit 0)
- THEN `qa-init` MUST record `smoke_test: passed` and `runtime_available: true`
- AND the preflight cache MUST be written with `runtime_available: true`

### Scenario: Smoke test fails despite doctor passing

- GIVEN `agent-browser doctor --json` exited 0
- WHEN `qa-init` executes `agent-browser open about:blank` or `agent-browser close`
- AND either command fails (non-zero exit or timeout)
- THEN `qa-init` MUST record `smoke_test: failed` and `runtime_available: false`
- AND the error message from the failed command MUST be captured in `smoke_test_error`
- AND the preflight cache MUST be written with `runtime_available: false` and `unavailable_reason: "smoke-test-failed"`

---

## Requirement: App Start Command Detection — Suggest, Never Execute

`qa-init` MUST detect likely application start commands from project files and surface them as suggestions. It MUST NOT execute them.

### Scenario: Start command detected from package.json

- GIVEN the project contains a `package.json` with a `scripts.dev`, `scripts.start`, or `scripts.serve` entry
- WHEN `qa-init` scans the project context
- THEN `qa-init` MUST record the detected command under `detected_start_hints`
- AND the hint MUST include: `command`, `source` (e.g., `"package.json scripts.dev"`), and `likely_port` (if determinable)
- AND `qa-init` MUST NOT execute the command
- AND the return summary MUST surface the hint as: "Detected likely start command: `{command}` (from `{source}`). Run it manually to start the application before browser tests."

### Scenario: Start command detected from Makefile, Procfile, docker-compose, or go.mod

- GIVEN the project contains one or more of: `Makefile` with a `run`, `serve`, or `dev` target; `Procfile` with a `web:` entry; `docker-compose.yml` with service ports; `go.mod` / `main.go` with a port flag
- WHEN `qa-init` scans the project context
- THEN `qa-init` MUST record each detected hint under `detected_start_hints`
- AND MUST NOT execute any detected command

### Scenario: No start command detectable

- GIVEN the project contains none of the detection sources
- WHEN `qa-init` completes start-command detection
- THEN `qa-init` MUST record `detected_start_hints: []`
- AND the return summary MUST note: "No application start command detected automatically — provide the URL manually when invoking browser tests"

---

## Requirement: Preflight Cache Schema and Storage

The preflight result MUST be persisted to the active artifact store immediately after the preflight completes.

### Scenario: Preflight cache written in openspec mode

- GIVEN the artifact store mode is `openspec`
- WHEN the preflight completes (regardless of outcome)
- THEN `qa-init` MUST write the cache to `qaspec/preflight-cache.yaml`
- AND the file MUST conform to this schema:

```yaml
preflight:
  agent_browser:
    available: true | false
    version: "{semver}" | null
  doctor_result: passed | failed | parse-error | skipped
  chrome_binary:
    available: true | false
    name: "chromium" | "google-chrome-stable" | "google-chrome" | "chrome" | null
  smoke_test: passed | failed | skipped
  smoke_test_error: null | "{error message}"
  runtime_available: true | false
  unavailable_reason: null | "bash-unavailable" | "agent-browser-not-installed" | "doctor-check-failed" | "no-chrome-binary" | "smoke-test-failed"
  probed_at: "{ISO-8601 timestamp}"
detected_start_hints:
  - command: "{command string}"
    source: "{detection source}"
    likely_port: {integer} | null
```

### Scenario: Preflight cache written in engram mode

- GIVEN the artifact store mode is `engram`
- WHEN the preflight completes
- THEN `qa-init` MUST call `mem_save` with:
  - `title`: `qa-init/{project}/preflight`
  - `topic_key`: `qa-init/{project}/preflight`
  - `type`: `architecture`
  - `project`: `{project}`
  - `content`: the preflight result in the schema above (as YAML, embedded in Markdown)
- AND the observation ID MUST be included in the qa-init return summary

### Scenario: Preflight cache includes the detection mechanism used

- GIVEN the preflight has completed
- WHEN the cache is written
- THEN the cache MUST include a `detection_mechanism` field recording which path produced the result: one of `"doctor"`, `"chrome-probe-fallback"`, or `"bash-unavailable"`

### Scenario: Subsequent qa-browser invocation reads the preflight cache

- GIVEN a preflight cache exists with `runtime_available: false`
- WHEN `qa-browser` is launched for a review
- THEN `qa-browser` MUST read the preflight cache before attempting any browser command
- AND if `runtime_available: false`, `qa-browser` MUST record `status: "failed"` and return without fabricating any runtime findings
- AND the return envelope MUST include the preflight cache's `unavailable_reason`
