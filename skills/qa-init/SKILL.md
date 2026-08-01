---
name: qa-init
description: >
  Initialize QASE (QA-Squad-Excellence) context in any project. Detects stack, architecture DNA,
  conventions, and bootstraps the active persistence backend.
  Trigger: When user wants to initialize QASE in a project, or says "qa init", "qa-init", "/qa-init".
license: MIT
metadata:
  author: dev-gios
  version: "1.0"
  framework: QASE
---

## Purpose

You are a sub-agent responsible for initializing the QASE (QA-Squad-Excellence) review context in a project. You detect the project stack, architecture patterns, existing quality tooling, and bootstrap the active persistence backend so that future reviews have full project context.

## Execution and Persistence Contract

Read and follow `skills/_shared/qase/persistence-contract.md` for mode resolution rules.

- If mode is `engram`: Read and follow `skills/_shared/qase/engram-convention.md`. Do not create `qaspec/`.
- If mode is `openspec`: Read and follow `skills/_shared/qase/openspec-convention.md`. Run full bootstrap.
- If mode is `none`: Return detected context without writing project files.

## What to Do

### Step 1: Detect Project Context

Read the project to understand its "architecture DNA":

```
DETECT:
├── Tech Stack
│   ├── package.json, go.mod, pyproject.toml, Cargo.toml, build.gradle, pom.xml, etc.
│   ├── Framework: React, Next.js, Vue, Angular, Express, FastAPI, Django, Spring, etc.
│   └── Language version and variant (TypeScript vs JavaScript, Python 3.x, etc.)
│
├── Architecture Patterns
│   ├── Directory structure → layered, hexagonal, feature-sliced, MVC, monolith, microservices
│   ├── State management → Redux, Zustand, Context, MobX, Vuex, Pinia
│   ├── API style → REST, GraphQL, tRPC, gRPC
│   └── Data layer → ORM (Prisma, TypeORM, SQLAlchemy), raw SQL, NoSQL
│
├── Quality Tooling (existing)
│   ├── Linters: ESLint, Biome, Ruff, Clippy, golangci-lint
│   ├── Formatters: Prettier, Black, rustfmt, gofmt
│   ├── Type checkers: TypeScript (strict?), mypy, pyright
│   ├── Test frameworks: Jest, Vitest, pytest, Go test, JUnit
│   ├── CI/CD: GitHub Actions, GitLab CI, Jenkins
│   └── Other quality tools: Husky, lint-staged, pre-commit, Storybook, Chromatic
│
├── Security Posture
│   ├── Auth: JWT, sessions, OAuth providers, API keys
│   ├── Dependencies: package-lock.json age, known vulnerabilities
│   └── Environment: .env files, secrets management
│
└── Accessibility Baseline
    ├── a11y testing tools: axe-core, pa11y, Lighthouse
    ├── Component library with built-in a11y: Radix, Headless UI, Ant Design
    └── ARIA usage patterns in existing code
```

### Step 2: Initialize Persistence Backend

If mode resolves to `openspec`, create this directory structure:

```
qaspec/
├── config.yaml              <- Project-specific QASE config
├── init.yaml                <- Detected project context
├── reviews/                 <- Review artifacts
│   └── archive/             <- Completed reviews
└── feedback/                <- Persistent feedback (empty initially)
```

### Step 3: Generate Config (openspec mode)

Based on what you detected, create the config:

```yaml
# qaspec/config.yaml
schema: qase-review

context: |
  Tech stack: {detected stack}
  Architecture: {detected patterns}
  Testing: {detected test framework}
  Style: {detected linting/formatting}
  Auth: {detected auth approach}

rules:
  scan:
    - Classify changes before routing
  architect:
    - Focus on SOLID principles for the detected architecture
    - {architecture-specific rules based on detected patterns}
  security:
    - Apply OWASP Top 10 checks
    - {auth-specific rules based on detected auth approach}
  inclusion:
    - Target WCAG 2.1 AA compliance
    - {component-library-specific rules if detected}
  performance:
    - Flag O(n^2) or worse in hot paths
    - {framework-specific performance rules}
  report:
    - Deduplicate findings across specialists
    - Apply veto logic for BLOCKER severity
```

### Step 4: Runtime Preflight (Browser Backend)

This step runs as the LAST `qa-init` step before the return summary. It proves that a browser can actually be driven from this executor, caches the verdict, and records start-command hints for the user. Runtime specialists (`qa-browser`, `qa-visual`) read this cache; they do not probe the environment themselves.

**P0 — Bash availability check** (FIRST action in this step):

```bash
printf 'qase-bash-ok\n'
```

- If the Bash tool is unavailable (the command cannot run): record `bash_available: false`, `runtime_available: false`, `unavailable_reason: "bash-unavailable"`, `detection_mechanism: "bash-unavailable"`. Surface note: "Runtime preflight skipped — no Bash tool available in this executor; agent-browser is CLI-only." Jump directly to P6 (persist). Do NOT attempt any agent-browser command.
- If the command succeeds: record `bash_available: true`. Continue to P1.

**P1 — Presence probe**:

```bash
command -v agent-browser
```

- Not found (exit non-zero): record `agent_browser.available: false`, `runtime_available: false`, `unavailable_reason: "agent-browser-not-installed"`. Surface install hint text (do NOT execute):
  ```
  npm i -g agent-browser && agent-browser install
  # On Linux hosts: agent-browser install --with-deps may be required
  ```
  Jump to P6.
- Found: record `agent_browser.available: true`, `agent_browser.detection: "command -v"`.
  Version: `--version` is a verified global flag (`agent-browser --version` outputs `agent-browser 0.32.2`). Record the version string in `agent_browser.version`. If `--version` fails, fall back to reading the version from `doctor --json` output.

**P2 — Doctor check** (primary diagnostic):

```bash
agent-browser doctor --json
```

- Exit 0: record `doctor.ran: true`, `doctor.exit_code: 0`, `detection_mechanism: "doctor"`. Proceed to P3.
- Exit 1: record `doctor.ran: true`, `doctor.exit_code: 1`, `doctor.failed_checks: [...]` (names from JSON). Proceed to P3 (smoke test is the final authority — doctor exit 1 does not end the preflight).
- Output unparseable: record `doctor.ran: true`, `doctor.exit_code: null`. Fall back to P2b.
- Command not found or cannot be parsed: fall back to P2b.

**P2b — Chrome binary fallback probe** (only when doctor output is unavailable or unparseable):

```bash
command -v chromium          # probe 1
command -v google-chrome-stable  # probe 2
command -v google-chrome    # probe 3
command -v chrome           # probe 4
```

Stop at the first hit. Record `chrome_binary.name` and `detection_mechanism: "chrome-probe-fallback"`. NEVER probe a single name only — false-negative risk on working environments (R4). If none found: record `chrome_binary.available: false`, `unavailable_reason: "no-chrome-binary"`. Jump to P6.

**P3 — Smoke connection test** (final authority):

```bash
S="$(agent-browser session id --scope worktree --prefix qase)"
agent-browser --session "$S" open
agent-browser --session "$S" get url --json
agent-browser --session "$S" close
```

- All three commands succeed and the JSON from `get url --json` contains `data.url == "about:blank"` (actual output: `{"success":true,"data":{...,"url":"about:blank"},"error":null}` — the url is nested under `data`, not at the top level): record `smoke_test: passed`, `runtime_available: true`, `unavailable_reason: null`.
- Any command fails: record `smoke_test: failed`, `runtime_available: false`, `unavailable_reason: "smoke-test-failed"`, `smoke_test_error: {stderr}`.
  This is the installed-but-broken case the preflight exists to make loud.

**P4 — App start-command hints** (SUGGEST only — NEVER EXECUTE):

Read the following sources and extract commands that likely start the application:
- `package.json` scripts: `dev`, `start`, `serve`
- `Makefile` targets: `run`, `serve`, `dev`
- `Procfile` web: line
- `docker-compose.yml` service port mappings
- `go.mod` / `main.go` port flag
- `README` "Getting Started" section
- `.env.example PORT=`

For each discovered command, record `{ command, source, likely_port }` under `detected_start_hints[]`. If none found: `detected_start_hints: []` and note in the summary.

**NEVER execute any detected command.** Starting the user's application is outside `qa-init`'s mandate — the same principle as refusing to truncate their database.

**P5 — Cleanup-hook detection** (opportunistic):

Look for a test-reset endpoint or script: `POST /test/reset`, `npm run test:reset`, or similar patterns in `package.json`, `Makefile`, or README. Record as `detected_cleanup_hook: { kind: "endpoint" | "command", value: "..." }` or `null`. QASE will not invent cleanup, run migrations, or truncate tables.

**P6 — Persist cache**:

- `openspec` → write `qaspec/preflight-cache.yaml` with the full schema from `persistence-contract.md`.
- `engram` → `mem_save` with `topic_key: "qa-init/{project}/preflight"`, `type: architecture`.
- `none` → return inline only; note that cache was not persisted.

---

### Step 5: Return Summary

Return a structured summary adapted to the resolved mode:

#### If mode is `engram`:

Persist project context following `skills/_shared/qase/engram-convention.md` with title and topic_key `qa-init/{project-name}`.

Return:
```
## QASE Initialized

**Project**: {project name}
**Stack**: {detected stack summary}
**Architecture**: {detected patterns}
**Quality Tooling**: {existing tools}
**Persistence**: engram

### Context Saved
Project context persisted to Engram.
- **Engram ID**: #{observation-id}
- **Topic key**: qa-init/{project-name}

No project files created.

### Architecture DNA
{Brief summary of detected architecture patterns, conventions, and quality posture}

### Runtime Backend
- **runtime_available**: {true | false}
- **unavailable_reason**: {null | "specific cause"}
- **detection_mechanism**: {doctor | chrome-probe-fallback | bash-unavailable}
- **agent-browser version**: {version string | not detected}
- **App start hints** (SUGGEST ONLY — never run these):
  {list of detected_start_hints[].command or "None detected"}

### Next Steps
Ready for `/qa-review [scope]` to review code changes.
{If runtime_available: true: "Runtime browser testing available — use /qa-browser <url> to test a live application."}
{If runtime_available: false: "Runtime browser testing unavailable: {unavailable_reason}. Fix the issue and re-run /qa-init to update the cache."}
```

#### If mode is `openspec`:
```
## QASE Initialized

**Project**: {project name}
**Stack**: {detected stack summary}
**Architecture**: {detected patterns}
**Quality Tooling**: {existing tools}
**Persistence**: openspec

### Structure Created
- qaspec/config.yaml           <- Project config with detected context
- qaspec/init.yaml             <- Full architecture DNA
- qaspec/preflight-cache.yaml  <- Runtime backend capability cache
- qaspec/reviews/              <- Ready for review artifacts
- qaspec/feedback/             <- Ready for feedback persistence

### Runtime Backend
- **runtime_available**: {true | false}
- **unavailable_reason**: {null | "specific cause"}
- **detection_mechanism**: {doctor | chrome-probe-fallback | bash-unavailable}
- **agent-browser version**: {version string | not detected}
- **App start hints** (SUGGEST ONLY — never run these):
  {list of detected_start_hints[].command or "None detected"}

### Next Steps
Ready for `/qa-review [scope]` to review code changes.
{If runtime_available: true: "Runtime browser testing available — use /qa-browser <url> to test a live application."}
{If runtime_available: false: "Runtime browser testing unavailable: {unavailable_reason}. Fix the issue and re-run /qa-init to update the cache."}
```

#### If mode is `none`:
```
## QASE Initialized

**Project**: {project name}
**Stack**: {detected stack summary}
**Architecture**: {detected patterns}
**Quality Tooling**: {existing tools}
**Persistence**: none (ephemeral)

### Architecture DNA
{Full summary of detected architecture patterns, conventions, and quality posture}

### Runtime Backend
- **runtime_available**: {true | false}
- **unavailable_reason**: {null | "specific cause"}
- **detection_mechanism**: {doctor | chrome-probe-fallback | bash-unavailable}
- **agent-browser version**: {version string | not detected}
- **App start hints** (SUGGEST ONLY — never run these):
  {list of detected_start_hints[].command or "None detected"}
- **Note**: preflight cache was NOT persisted (mode: none). Re-run /qa-init with engram or openspec to persist.

### Recommendation
Enable `engram` for artifact persistence across reviews. Without persistence, review context and feedback will be lost between sessions.

### Next Steps
Ready for `/qa-review [scope]` to review code changes.
{If runtime_available: true: "Runtime browser testing available — use /qa-browser <url> to test a live application."}
{If runtime_available: false: "Runtime browser testing unavailable: {unavailable_reason}. Fix the issue and re-run /qa-init to update the cache."}
```

## Rules

- ALWAYS detect the real tech stack, don't guess
- If the project already has a `qaspec/` directory, report what exists and ask the orchestrator if it should be updated
- Keep config.yaml context CONCISE — no more than 10 lines
- The init.yaml can be more detailed (architecture DNA dump)
- DO NOT modify any existing project code
- DO NOT create placeholder review files — reviews are created by qa-scan during an actual review
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
