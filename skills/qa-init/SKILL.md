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

### Step 4: Produce Preflight Cache Payload

Read the probe results supplied in your context by the orchestrator. The orchestrator ran the P0-P3 sequence (bash availability, `command -v agent-browser`, `agent-browser doctor --json`, and the smoke connection test) before launching you. The preflight outcome truth table, cache schema, TTL, and refusal rule are owned by `skills/_shared/qase/persistence-contract.md` — read that file before producing the payload.

Produce the preflight cache payload from the supplied probe results and return it. The orchestrator writes it:
- `openspec` → orchestrator writes `qaspec/preflight-cache.yaml`
- `engram` → orchestrator calls `mem_save(topic_key: "qa-init/{project}/preflight", type: architecture, content: {payload})`
- `none` → payload is returned inline; cache is not persisted

Also read app start-command hints and cleanup-hook patterns from project files (see `persistence-contract.md` for the full `detected_start_hints[]` and `detected_cleanup_hook` schema) — include them in the payload.

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
