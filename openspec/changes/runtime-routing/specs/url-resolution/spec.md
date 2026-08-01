# url-resolution Specification

## Purpose

Define the orchestrator's five-step URL resolution precedence for runtime reviews, the
read-only reachability probe, and the absolute prohibition on executing
`detected_start_hints[].command`. Bash belongs to `qa-browser` and `qa-visual` only; the
orchestrator MUST NOT start the user's application.

---

## Requirements

### Requirement: URL Resolution Precedence

The orchestrator MUST resolve the application URL by evaluating the following steps in order,
stopping at the first step that yields a URL. All resolution logic is owned by the orchestrator;
no specialist resolves URLs independently.

| Step | Source | Action |
|---|---|---|
| 1 | `--url <url>` flag | Accept as-is — user stated the fact |
| 2 | `runtime.base_url` in project context | Read from `qa-init` output |
| 3 | `detected_start_hints[].likely_port` | Probe `http://localhost:{port}` (read-only) |
| 4 | Ask the user once, quoting the detected start command as a suggestion | — |
| 5 | No answer or unattended run | Runtime does not execute → `runtime_coverage: unverified` |

#### Scenario: --url flag takes precedence over all other sources

- GIVEN `/qa-review --pr 42 --url http://localhost:4200` is invoked
- WHEN the orchestrator resolves the URL
- THEN it MUST use `http://localhost:4200`
- AND MUST NOT probe any other source

#### Scenario: runtime.base_url used when --url is absent

- GIVEN no `--url` flag was passed
- AND the project context contains `runtime.base_url: http://localhost:3000`
- WHEN the orchestrator resolves the URL
- THEN it MUST use `http://localhost:3000` without probing ports

#### Scenario: Port probe used when --url and base_url are absent

- GIVEN no `--url` flag and no `runtime.base_url`
- AND the preflight cache contains `detected_start_hints[{likely_port: 3000}]`
- WHEN the orchestrator resolves the URL
- THEN it MUST perform a single read-only reachability probe to `http://localhost:3000`
- AND if the probe succeeds (HTTP 2xx or 3xx) the orchestrator MUST use that URL
- AND if the probe fails the orchestrator MUST fall through to step 4

#### Scenario: Orchestrator asks the user when port probe fails

- GIVEN no `--url`, no `runtime.base_url`, and a failed port probe
- WHEN the orchestrator prompts the user
- THEN it MUST ask exactly once
- AND MUST quote the detected start command (e.g., `npm run dev`) as a suggestion
- AND MUST NOT start the application itself

#### Scenario: No URL resolved in unattended run

- GIVEN no `--url`, no `runtime.base_url`, no reachable port, and no user answer
- WHEN the orchestrator completes URL resolution
- THEN runtime specialists MUST NOT execute
- AND the review MUST proceed with `runtime_coverage: unverified`

---

### Requirement: Read-Only Reachability Probe

The reachability probe at step 3 MUST be a single read-only HTTP request. It MUST NOT mutate
any server state and MUST NOT require authentication.

#### Scenario: Probe is read-only

- GIVEN the orchestrator is performing a port probe
- WHEN it issues the reachability request
- THEN the request MUST be an HTTP GET (or equivalent read-only method)
- AND the orchestrator MUST NOT follow more than one redirect
- AND a non-2xx/3xx response MUST cause step 3 to fail and fall through to step 4

---

### Requirement: No-Auto-Start Prohibition

The orchestrator MUST NOT execute `detected_start_hints[].command` under any circumstances.
This rule extends the prohibition declared in `skills/qa-init/SKILL.md:158`
("SUGGEST ONLY — never run these") to the orchestrator. It is a registered single-source
literal in `rule-ownership.md`; restating it in any other file is a lint violation.

A reachability probe reads; a start command mutates the developer's environment. That
boundary MUST be enforced.

#### Scenario: Orchestrator never runs detected start commands

- GIVEN a preflight cache containing `detected_start_hints[{command: "npm run dev"}]`
- WHEN the orchestrator attempts URL resolution
- THEN it MUST NOT execute `npm run dev` or any other `detected_start_hints[].command`
- AND it MUST present the command to the user as a suggestion only

#### Scenario: No-auto-start rule is a registered single-source literal

- GIVEN `rule-ownership.md`'s rules table
- WHEN the linter parses the table
- THEN a row registering the no-auto-start literal MUST exist with `severity-contract.md` or
  `routing-rules.md` as owner (whichever the design phase assigns as sole owner)
- AND `allow_count: 0` MUST be set so any restatement outside the owner file fails the linter

#### Scenario: STATIC ONLY qualifier is a registered single-source literal

- GIVEN `rule-ownership.md`'s rules table
- WHEN the linter parses the table
- THEN a row registering `(STATIC ONLY)` MUST exist with `severity-contract.md` as owner
- AND `allow_count: 0` MUST be set so any restatement outside the owner file fails the linter
