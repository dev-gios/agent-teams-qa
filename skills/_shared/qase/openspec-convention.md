# OpenSpec File Convention (shared across all QASE skills)

See `skills/_shared/qase/oracle-contract.md` for tier semantics and citation requirements referenced in flow evidence and baseline diff paths below.

## Directory Structure

```
qaspec/
├── config.yaml              <- Project-specific QASE config
├── init.yaml                <- Project context from qa-init
├── preflight-cache.yaml     <- NEW, produced by qa-init, written by orchestrator
├── baselines/               <- NEW, persists ACROSS reviews
│   └── {page-slug}/
│       ├── 1440x900.png
│       ├── 768x1024.png
│       └── 375x812.png
├── reviews/                 <- Review artifacts
│   ├── archive/             <- Completed reviews (YYYY-MM-DD-{scope-slug}/)
│   └── {review-id}/         <- Active review folder
│       ├── scan.md          <- from qa-scan (routing manifest)
│       ├── architect.md     <- from qa-architect
│       ├── advocate.md      <- from qa-advocate
│       ├── security.md      <- from qa-security
│       ├── inclusion.md     <- from qa-inclusion
│       ├── performance.md   <- from qa-performance
│       ├── test-strategy.md <- from qa-test-strategy
│       ├── browser.md       <- from qa-browser
│       ├── visual.md        <- from qa-visual
│       ├── report.md        <- from qa-report (final verdict)
│       ├── visual-diffs/    <- NEW, diff output (per review)
│       │   └── {page-slug}-{viewport}.png
│       └── flow-evidence/   <- NEW
│           ├── {flow-slug}.md               <- the evidence document
│           └── {flow-slug}/                 <- binary artifacts for this flow
│               ├── screenshots/step-01.png ... step-NN.png
│               ├── console/step-01.json    ... step-NN.json
│               ├── errors/step-01.json     ... step-NN.json
│               ├── network/step-01.json    ... step-NN.json
│               ├── har/{flow-slug}.har          (deep / on request)
│               └── recordings/{flow-slug}.webm  (deep / on request)
├── feedback/                <- Persistent feedback (survives across reviews)
│   └── {agent}/
│       └── {pattern-slug}.md
```

## Artifact File Paths

Specialists are **producers** — they return their report payload. The orchestrator is the
**writer** — it persists artifacts to the filesystem. See `persistence-contract.md` for the
sole-writer rule and the producer/writer distinction.

| Artifact | Produced By | Written By (Orchestrator) | Path |
|----------|-------------|--------------------------|------|
| preflight-cache | qa-init | Orchestrator | `qaspec/preflight-cache.yaml` |
| config + init | qa-init | Orchestrator | `qaspec/config.yaml`, `qaspec/init.yaml`, `qaspec/reviews/`, `qaspec/feedback/`, `qaspec/reviews/archive/` |
| scan | qa-scan | Orchestrator | `qaspec/reviews/{review-id}/scan.md` |
| architect report | qa-architect | Orchestrator | `qaspec/reviews/{review-id}/architect.md` |
| advocate report | qa-advocate | Orchestrator | `qaspec/reviews/{review-id}/advocate.md` |
| security report | qa-security | Orchestrator | `qaspec/reviews/{review-id}/security.md` |
| inclusion report | qa-inclusion | Orchestrator | `qaspec/reviews/{review-id}/inclusion.md` |
| performance report | qa-performance | Orchestrator | `qaspec/reviews/{review-id}/performance.md` |
| test-strategy report | qa-test-strategy | Orchestrator | `qaspec/reviews/{review-id}/test-strategy.md` |
| browser report | qa-browser | Orchestrator | `qaspec/reviews/{review-id}/browser.md`, `qaspec/reviews/{review-id}/flow-evidence/{flow-slug}.md`, and artifact subtree |
| visual report | qa-visual | Orchestrator | `qaspec/reviews/{review-id}/visual.md`, `qaspec/reviews/{review-id}/visual-diffs/{page-slug}-{viewport}.png`; reads `qaspec/baselines/` |
| final report | qa-report | Orchestrator | `qaspec/reviews/{review-id}/report.md` |
| feedback patterns | qa-feedback | Orchestrator | `qaspec/feedback/{agent}/{pattern-slug}.md` |

## Review ID Format

```
{YYYY-MM-DD}-{scope-slug}
```

Example: `2024-01-15-auth-refactor`, `2024-01-15-staged`, `2024-01-15-src-utils`

## Reading Artifacts

Each skill reads its dependencies from the filesystem:

```
Config:     qaspec/config.yaml
Init:       qaspec/init.yaml
Scan:       qaspec/reviews/{review-id}/scan.md
Reports:    qaspec/reviews/{review-id}/{agent}.md
Feedback:   qaspec/feedback/{agent}/  (all files in directory)
```

## Writing Rules

- ALWAYS create the review directory (`qaspec/reviews/{review-id}/`) before writing artifacts
- If a file already exists, READ it first and UPDATE it (don't overwrite blindly)
- Use the `qaspec/config.yaml` to apply project-specific constraints
- Feedback files are NEVER inside reviews — they live in `qaspec/feedback/` and persist across reviews
- Visual baselines persist ACROSS reviews and MUST live at `qaspec/baselines/`, never inside a `reviews/{review-id}/` directory. A baseline inside a review folder cannot be diffed against by the next review — the same reason feedback files never live inside reviews.
- Visual diff *outputs* are per-review and belong in `qaspec/reviews/{review-id}/visual-diffs/`. Visual diff *inputs* (baselines) are cross-review and belong in `qaspec/baselines/`.
- `{flow-slug}` is a kebab-case slug of the flow name. Step index `NN` is zero-padded, one-based, matching the evidence row numbering exactly (e.g., `step-01.png`, `step-02.png`).

## Slug Derivation Algorithms

These are the canonical, deterministic algorithms for deriving slugs from URLs and flow names. **All skills MUST use these exact rules** — two runs against the same input must produce the same slug, or baselines are silently never reused.

### `{page-slug}` — from a URL

```
1. Take the URL path component (strip protocol, host, query string, and fragment).
2. Normalize: lowercase, collapse consecutive slashes to one, strip trailing slash.
3. Special case: empty path (i.e., the root URL "/") → slug is "root".
4. Replace every character that is NOT [a-z0-9] with a hyphen.
5. Collapse consecutive hyphens to one.
6. Strip leading and trailing hyphens.
```

Examples:
- `https://app.example.com/`           → `root`
- `https://app.example.com/dashboard`  → `dashboard`
- `https://app.example.com/auth/login` → `auth-login`
- `https://app.example.com/users/42`   → `users-42`
- `https://app.example.com/settings/profile/?tab=security` → `settings-profile`

### `{flow-slug}` — from a flow name

```
1. Lowercase the flow name.
2. Replace every character that is NOT [a-z0-9] with a hyphen.
3. Collapse consecutive hyphens to one.
4. Strip leading and trailing hyphens.
```

Examples:
- `"User Registration Flow"` → `user-registration-flow`
- `"Login + 2FA (Mobile)"`   → `login-2fa-mobile`
- `"Sign In"`                → `sign-in`

## Config File Reference

```yaml
# qaspec/config.yaml
schema: qase-review

context: |
  Tech stack: {detected}
  Architecture: {detected}
  Testing: {detected}
  Style: {detected}

rules:
  scan:
    - Classify changes before routing
  architect:
    - Focus on SOLID principles for the detected architecture
  security:
    - Apply OWASP Top 10 checks
  inclusion:
    - Target WCAG 2.1 AA compliance
  performance:
    - Flag O(n^2) or worse in hot paths
  report:
    - Deduplicate findings across specialists
    - Apply veto logic for BLOCKER severity
```

## Archive Structure

When archiving a completed review:
```
qaspec/reviews/archive/YYYY-MM-DD-{scope-slug}/
```

The archive is an AUDIT TRAIL — never delete or modify archived reviews.
