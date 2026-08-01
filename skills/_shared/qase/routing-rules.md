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

## Runtime Recommendation

`qa-scan` produces a `runtime_recommendation` block alongside the routing manifest. This is **advisory
only** — it tells the orchestrator which runtime specialists would be useful, but does not activate
them. The orchestrator decides whether to launch them based on the preflight cache, URL availability,
and user consent (see Sequence Diagram 1 in `design.md`).

### Runtime Trigger Table

| Category | Recommended specialists | Notes |
|----------|------------------------|-------|
| `ui` | `qa-browser`, `qa-visual` | Rendered UI changes benefit from both functional and visual runtime checks |
| `api` | `qa-browser` | Network request validation and runtime API surface checks |
| `auth` | `qa-browser` | Auth flows, cookie handling, and session state require a live runtime |
| `business` | — (no recommendation) | Business logic is covered by static specialists; runtime adds noise |
| all others | — (no recommendation) | `test`, `infra`, `config`, `docs`, `database` carry no runtime surface |

### `runtime_recommendation` Manifest Block

`qa-scan` appends this block to its result envelope when at least one triggering category is
detected. When no triggering category is present, `recommended: false` MUST be emitted explicitly
(an absent block is indistinguishable from a pre-change `qa-scan`).

```yaml
runtime_recommendation:
  recommended: true | false
  reason: "ui and auth categories detected — page rendering and auth flows may be affected"
  triggering_categories: [ui, auth]          # subset of detected categories that triggered
  specialists: [qa-browser, qa-visual]       # specialists the orchestrator should consider launching
  candidate_targets: []                      # URL hints for display only; NEVER auto-navigated
```

### No-Auto-Start Rule

The orchestrator MUST NOT execute detected_start_hints[].command. A start-command hint says what
command **would** start the application — it does not mean the application **is** running. The
orchestrator resolves a URL and, if needed, asks the user once. It never starts the application
automatically.

## Oracle-Tier-Aware Routing

See `skills/_shared/qase/oracle-contract.md` for the full tier definitions and blocking matrix.

A runtime specialist's findings enter the `qa-report` consensus engine with their Oracle Tier attached. `qa-report` sorts and gates on tier, not on agent name alone. This means:

- A `qa-browser` finding at L1 or L3-schema with a verified citation carries the same blocking weight as a `qa-security` finding at the same severity.
- A `qa-browser` finding at L4 is advisory only (WARNING cap) regardless of how confident the observation appears.
- `qa-visual` findings are predominantly L4 and therefore advisory. `qa-visual` has no veto power.

Routing agents should not assume a runtime specialist's verdict contribution based on agent identity alone; it depends on the tier distribution of the findings in that review.

## Dismissed Patterns (Feedback Integration)

Before routing, `qa-scan` loads any existing feedback from Engram or `qaspec/feedback/`:
- For each specialist being activated, check if there are dismissed patterns
- Pass dismissed patterns to the specialist so they can skip known-accepted findings
- Include dismissed patterns in the routing manifest for transparency
