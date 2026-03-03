# Routing Rules (shared across all QASE skills)

## Purpose

`qa-scan` uses these rules to decide which specialists to activate for a given set of changes. Smart routing avoids noise — a CSS-only change doesn't need a security scan.

## Category Detection Patterns

Each changed file is classified into one or more categories based on path and content patterns:

| Category | Path Patterns | Content Patterns |
|----------|--------------|-----------------|
| `auth` | `**/auth/**`, `**/login/**`, `**/session/**`, `**/oauth/**`, `**/jwt/**`, `**/permission*`, `**/role*`, `**/acl*` | `password`, `token`, `secret`, `credential`, `bcrypt`, `hash`, `encrypt`, `bearer`, `cookie`, `session` |
| `database` | `**/db/**`, `**/database/**`, `**/migration*/**`, `**/model*/**`, `**/schema*/**`, `**/repository*/**`, `**/dao/**` | `SELECT`, `INSERT`, `UPDATE`, `DELETE`, `CREATE TABLE`, `prisma`, `sequelize`, `mongoose`, `typeorm`, `knex`, `drizzle`, `query` |
| `api` | `**/api/**`, `**/routes/**`, `**/controllers/**`, `**/handlers/**`, `**/endpoints/**`, `**/middleware/**`, `**/graphql/**` | `req.body`, `req.params`, `request.`, `response.`, `@Get`, `@Post`, `@Put`, `@Delete`, `router.`, `app.get`, `app.post`, `fetch(`, `axios` |
| `ui` | `**/components/**`, `**/pages/**`, `**/views/**`, `**/layouts/**`, `**/templates/**`, `**/*.css`, `**/*.scss`, `**/*.html`, `**/*.jsx`, `**/*.tsx`, `**/*.vue`, `**/*.svelte` | `className`, `style=`, `aria-`, `role=`, `onClick`, `onChange`, `render`, `<div`, `<button`, `<form`, `<input` |
| `business` | `**/services/**`, `**/domain/**`, `**/usecases/**`, `**/core/**`, `**/lib/**`, `**/utils/**`, `**/helpers/**` | Business logic files that don't match other categories |
| `test` | `**/*.test.*`, `**/*.spec.*`, `**/test/**`, `**/tests/**`, `**/__tests__/**`, `**/fixtures/**` | `describe(`, `it(`, `test(`, `expect(`, `assert`, `mock`, `jest`, `vitest`, `pytest`, `unittest` |
| `infra` | `**/ci/**`, `**/.github/**`, `**/docker*`, `**/k8s/**`, `**/terraform/**`, `**/ansible/**`, `**/nginx*`, `Makefile`, `Dockerfile` | `pipeline`, `deploy`, `build`, `container`, `image` |
| `config` | `*.config.*`, `*.json`, `*.yaml`, `*.yml`, `*.toml`, `*.env*`, `*.ini` | Configuration files |
| `docs` | `**/*.md`, `**/docs/**`, `**/documentation/**`, `CHANGELOG*`, `LICENSE*` | Documentation files |

## Routing Matrix

Based on detected categories, activate these specialists:

| Category | Architect | Advocate | Security | Inclusion | Performance | Test Strategist |
|----------|:---------:|:--------:|:--------:|:---------:|:-----------:|:---------------:|
| `auth` | yes | yes | **PRIMARY** | — | — | yes |
| `database` | yes | yes | yes | — | **PRIMARY** | yes |
| `api` | yes | yes | **PRIMARY** | — | yes | yes |
| `ui` | yes | — | yes | **PRIMARY** | yes | yes |
| `business` | **PRIMARY** | yes | yes | — | yes | yes |
| `test` | yes | — | — | — | — | **PRIMARY** |
| `infra` | — | yes | **PRIMARY** | — | — | — |
| `config` | — | — | yes | — | — | — |
| `docs` | — | — | — | — | — | — |

**PRIMARY** = this specialist is the lead reviewer for this category (its findings carry extra weight in consensus).

## Minimum Viable Squad

Regardless of category, these specialists are ALWAYS activated:
- `qa-architect` (SOLID is always relevant)
- `qa-test-strategy` (test coverage is always relevant)

Exception: `docs` category skips ALL specialists → automatic `APPROVE` (clean).

## Full Squad Triggers

ALL specialists are activated when ANY of these conditions are met:
- `--full` flag is passed
- `auth` + `database` categories both present in the same review
- More than 10 files changed
- Any file touches both `auth` and `api` categories

## Routing Manifest Format

`qa-scan` produces this manifest for the orchestrator:

```yaml
review_id: "{YYYY-MM-DD}-{scope-slug}"
scope: "{original scope argument}"
files_changed: {count}
categories_detected:
  - {category}: [{file1}, {file2}, ...]
risk_level: low | medium | high | critical
activated_specialists:
  - agent: qa-architect
    reason: "Always activated (minimum viable)"
    primary_for: [{categories where PRIMARY}]
  - agent: qa-security
    reason: "auth category detected"
    primary_for: [auth]
  # ...
skipped_specialists:
  - agent: qa-inclusion
    reason: "No UI changes detected"
dismissed_patterns:
  - agent: qa-architect
    pattern: "service-god-object"
    reason: "PROJECT_RULE: monolith pattern accepted"
```

## Risk Level Calculation

```
critical: auth + database + api (triple combo)
high:     auth + any other, or 15+ files changed
medium:   database or api or business, or 5+ files changed
low:      ui-only, test-only, config-only, docs-only
```

## Out-of-Band Specialists

Some specialists operate **outside the code-diff pipeline** and are not routed by `qa-scan`:

| Specialist | Trigger | Why Out-of-Band |
|------------|---------|-----------------|
| `qa-browser` | `/qa-browser <url> [flows]` | Tests a live running application via Chrome DevTools, not source code diffs |

Out-of-band specialists:
- Do NOT have a column in the routing matrix (they don't analyze file changes)
- Are NOT activated by `qa-scan` — they are launched directly via solo commands
- The "Minimum Viable Squad" rule only applies to code-change reviews, not to out-of-band specialists
- Can still use dismissed patterns from `qa-feedback` for their own finding categories

## Dismissed Patterns (Feedback Integration)

Before routing, `qa-scan` loads any existing feedback from Engram or `qaspec/feedback/`:
- For each specialist being activated, check if there are dismissed patterns
- Pass dismissed patterns to the specialist so they can skip known-accepted findings
- Include dismissed patterns in the routing manifest for transparency
