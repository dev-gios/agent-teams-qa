# Engram Artifact Convention (shared across all QASE skills)

See `skills/_shared/qase/oracle-contract.md` for tier semantics and evidence citation requirements referenced throughout this file.

## Naming Rules

ALL QASE artifacts persisted to Engram MUST follow this deterministic naming:

### Review Artifacts (per-review, ephemeral)

```
title:     qase/{review-id}/{artifact-type}
topic_key: qase/{review-id}/{artifact-type}
type:      architecture
project:   {detected or current project name}
scope:     project
```

### Flow Evidence (per-flow)

```
title:     qase/{review-id}/flow-evidence/{flow-slug}
topic_key: qase/{review-id}/flow-evidence/{flow-slug}
type:      architecture
project:   {detected or current project name}
scope:     project
```

`{flow-slug}` is a kebab-case slug of the flow name (e.g., `user-login-flow`). One artifact per flow per review.

### Project Init (project-scoped, long-lived)

```
title:     qa-init/{project-name}
topic_key: qa-init/{project-name}
type:      architecture
project:   {detected or current project name}
scope:     project
```

### Preflight Cache (project-scoped, long-lived, 24 h TTL)

```
title:     qa-init/{project-name}/preflight
topic_key: qa-init/{project-name}/preflight
type:      architecture
```

The orchestrator is the sole writer of the preflight cache key. `qa-init` produces the payload; the orchestrator calls `mem_save`. `qa-browser` and `qa-visual` read this artifact; they MUST NOT produce or write it. See `persistence-contract.md` for the full schema and TTL/freshness rule.

### Feedback (project-scoped, persistent)

```
title:     qase/{project}/feedback/{agent}/{pattern-slug}
topic_key: qase/{project}/feedback/{agent}/{pattern-slug}
type:      architecture
project:   {detected or current project name}
scope:     project
```

### Artifact Types (exact strings)

Capability class per agent is declared in `skills/_shared/qase/rule-ownership.md` (the `capabilities` table). Consult that file for the class of any agent.

| Artifact Type | Produced By | Written By | Description |
|---------------|-------------|------------|-------------|
| `scan` | qa-scan | Orchestrator | Routing manifest + diff classification |
| `architect-report` | qa-architect | Orchestrator | SOLID analysis findings |
| `advocate-report` | qa-advocate | Orchestrator | Resilience analysis findings |
| `security-report` | qa-security | Orchestrator | Security analysis findings |
| `inclusion-report` | qa-inclusion | Orchestrator | Accessibility analysis findings |
| `performance-report` | qa-performance | Orchestrator | Performance analysis findings |
| `test-strategy-report` | qa-test-strategy | Orchestrator | Test strategy findings |
| `browser-report` | qa-browser | Orchestrator | Runtime browser testing findings |
| `visual-report` | qa-visual | Orchestrator | Visual regression and design system compliance findings |
| `final-report` | qa-report | Orchestrator | Consensus verdict |
| `actionable-issues` | qa-report | Orchestrator | Bridge artifact for SDD integration |
| `feedback` | qa-feedback | Orchestrator | Dismissal pattern (under feedback/ path) |
| `flow-evidence` | qa-browser | Orchestrator | Per-flow evidence (topic_key: `qase/{review-id}/flow-evidence/{flow-slug}`) |
| `preflight-cache` | qa-init | Orchestrator | Runtime backend capability cache (24 h TTL) |

> **Note**: Engram stores markdown only. Binary artifact PATHS are recorded with an `(ephemeral)` marker; binary artifact bytes are not stored. Screenshots, `.webm` recordings, and `.har` files are written to a run-scoped temp directory and referenced by absolute path. See `persistence-contract.md` for the binary artifact rule.

### Example

```
mem_save(
  title: "qase/review-2024-01-15-auth-refactor/scan",
  topic_key: "qase/review-2024-01-15-auth-refactor/scan",
  type: "architecture",
  project: "my-app",
  content: "# Scan: auth-refactor\n\n..."
)
```

## Recovery Protocol (2 steps — MANDATORY)

To retrieve an artifact, ALWAYS use this two-step process:

```
Step 1: Search by topic_key pattern
  mem_search(query: "qase/{review-id}/{artifact-type}", project: "{project}")
  → Returns a truncated preview with an observation ID

Step 2: Get full content (REQUIRED)
  mem_get_observation(id: {observation-id from step 1})
  → Returns complete, untruncated content
```

NEVER use `mem_search` results directly as the full artifact — they are truncated previews.
ALWAYS call `mem_get_observation` to get the complete content.

### Loading Project Context

```
mem_search(query: "qa-init/{project}", project: "{project}") → get ID
mem_get_observation(id) → full project context
```

### Loading Feedback for a Specialist

```
mem_search(query: "qase/{project}/feedback/{agent}/", project: "{project}")
→ Returns all dismissed patterns for that agent
```

### Browsing All Artifacts for a Review

```
mem_search(query: "qase/{review-id}/", project: "{project}")
→ Returns all artifacts for that review
```

## Writing Artifacts

### Standard Write (new artifact)

```
mem_save(
  title: "qase/{review-id}/{artifact-type}",
  topic_key: "qase/{review-id}/{artifact-type}",
  type: "architecture",
  project: "{project}",
  content: "{full markdown content}"
)
```

### Update Existing Artifact

```
mem_update(
  id: {observation-id},
  content: "{updated full content}"
)
```

Use `mem_update` when you have the exact observation ID. Use `mem_save` with the same `topic_key` for upserts (Engram deduplicates by topic_key).

## SDD Bridge Artifact (Cross-System Integration)

When a QASE review produces BLOCKERs or WARNINGs, qa-report generates an additional **bridge artifact** designed for consumption by SDD (Spec-Driven Development) or any other fix-automation system.

### Naming

```
title:     qase/{review-id}/actionable-issues
topic_key: qase/{review-id}/actionable-issues
type:      architecture
project:   {detected or current project name}
scope:     project
```

### Format

The bridge artifact contains ONLY actionable findings (BLOCKERs + WARNINGs) in a structured format that SDD can convert directly into a proposal:

```markdown
# QASE Actionable Issues

**Review ID**: {review-id}
**Project**: {project}
**Date**: {YYYY-MM-DD}
**Verdict**: {REJECT | APPROVE WITH WARNINGS}
**Total actionable**: {count}

## Issues

### {SEVERITY}: {Title}

- **File**: `{file-path}`
- **Lines**: {start}-{end}
- **Agent**: {qa-agent that found it}
- **Category**: {OWASP-A03 | SOLID-SRP | WCAG-1.4.3 | etc.}
- **What**: {One-line description of the problem}
- **Fix**: {Senior Suggestion — actual refactored code or specific action}

---
{repeat for each issue}
```

### How SDD Consumes This

SDD (or any other system) can discover QASE findings by searching Engram:

```
mem_search(query: "qase/actionable-issues", project: "{project}")
→ Returns recent actionable-issues artifacts

mem_get_observation(id) → full content with all issues
```

SDD can then use this as input for `sdd-propose`:
- Each issue becomes a task in the proposal
- The "Fix" field provides the implementation direction
- File paths and line numbers give exact scope

### Rules

- ONLY generated when verdict is REJECT or APPROVE WITH WARNINGS (no artifact if APPROVE clean)
- Contains BLOCKERs and WARNINGs only — no INFOs
- Each issue includes the concrete fix suggestion, not just "fix this"
- The artifact is an upsert — re-running qa-report on the same review-id updates it
- This artifact is a ONE-WAY bridge: QASE writes, other systems read. QASE never reads this artifact.

## Why This Convention Exists

- **Deterministic titles** → recovery works by exact match, not fuzzy search
- **`topic_key`** → enables upserts (updating same artifact without creating duplicates)
- **`qase/` prefix** → namespaces all QASE artifacts away from SDD and other Engram observations
- **Two-step recovery** → `mem_search` previews are always truncated; `mem_get_observation` is the only way to get full content
- **Feedback persistence** → project-scoped feedback survives across reviews, enabling institutional memory
- **SDD bridge** → actionable-issues artifact enables cross-system integration without coupling
