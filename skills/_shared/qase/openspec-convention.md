# OpenSpec File Convention (shared across all QASE skills)

## Directory Structure

```
qaspec/
├── config.yaml              <- Project-specific QASE config
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
│       └── report.md        <- from qa-report (final verdict)
├── feedback/                <- Persistent feedback (survives across reviews)
│   └── {agent}/
│       └── {pattern-slug}.md
└── init.yaml                <- Project context from qa-init
```

## Artifact File Paths

| Skill | Creates / Reads | Path |
|-------|----------------|------|
| qa-init | Creates | `qaspec/config.yaml`, `qaspec/init.yaml`, `qaspec/reviews/`, `qaspec/feedback/`, `qaspec/reviews/archive/` |
| qa-scan | Creates | `qaspec/reviews/{review-id}/scan.md` |
| qa-architect | Creates | `qaspec/reviews/{review-id}/architect.md` |
| qa-advocate | Creates | `qaspec/reviews/{review-id}/advocate.md` |
| qa-security | Creates | `qaspec/reviews/{review-id}/security.md` |
| qa-inclusion | Creates | `qaspec/reviews/{review-id}/inclusion.md` |
| qa-performance | Creates | `qaspec/reviews/{review-id}/performance.md` |
| qa-test-strategy | Creates | `qaspec/reviews/{review-id}/test-strategy.md` |
| qa-browser | Creates | `qaspec/reviews/{review-id}/browser.md` |
| qa-report | Creates | `qaspec/reviews/{review-id}/report.md` |
| qa-feedback | Creates | `qaspec/feedback/{agent}/{pattern-slug}.md` |

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
