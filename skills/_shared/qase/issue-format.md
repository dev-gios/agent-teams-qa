# Issue Format (shared across all QASE skills)

## Standard Finding Format

Every finding produced by a QASE specialist MUST follow this exact format:

```markdown
### {SEVERITY}: {Title}

**Agent**: {agent-name}
**File**: `{file-path}`
**Lines**: {start}-{end} (or single line number)
**Category**: {category from routing-rules.md}

#### What Failed
{Concise description of the specific problem found in the code}

#### Why It Matters
{Impact explanation — what could go wrong, who is affected, what's the cost of not fixing}

#### Senior Suggestion
{Actual refactored code showing the fix — not vague advice, but concrete code}

```{language}
// Before (problematic)
{existing code snippet}

// After (suggested fix)
{refactored code snippet}
```

#### References
- {Link or name of relevant standard, rule, or best practice}
- {e.g., "OWASP A03:2021 — Injection", "SOLID — Single Responsibility Principle", "WCAG 2.1 SC 1.4.3"}
```

## Format Rules

1. **Title** must be actionable and specific (not "Potential issue" but "SQL injection via unsanitized user input in query builder")
2. **Agent** is the skill name (e.g., `qa-security`, `qa-architect`)
3. **File** must be the actual file path relative to project root
4. **Lines** must reference actual line numbers from the code
5. **Category** must match one of the categories in `routing-rules.md`
6. **What Failed** is factual, not judgmental — describe what the code does wrong
7. **Why It Matters** connects to real impact (security breach, maintenance cost, user exclusion, performance degradation)
8. **Senior Suggestion** MUST include actual code — not "consider refactoring" but the actual refactored code. If the fix is architectural (not a code snippet), describe the structural change with a before/after diagram.
9. **References** link to established standards — not opinions

## Browser Testing Variant

`qa-browser` uses an adapted finding format for runtime issues discovered in a live application:

```markdown
### {SEVERITY}: {Title}

**Agent**: qa-browser
**URL**: `{page-url}`
**Element**: `{element description or CSS selector}`
**Category**: {console-errors | network | accessibility | interaction | navigation | responsive | performance | user-flow}

#### What Failed
{Concise description of the runtime issue observed}

#### Why It Matters
{Impact on real users — broken functionality, inaccessibility, poor experience}

#### Senior Suggestion
{Actionable fix — code snippet, configuration change, or specific remediation}

#### Evidence
{Console error text, network request details, axe-core violation, or screenshot reference}

#### References
- {Relevant standard: WCAG 2.1 SC X.Y.Z, Web Vitals threshold, OWASP rule, etc.}
```

Key differences from the standard format:
- **URL** replaces **File** — findings reference the page URL, not a source file
- **Element** replaces **Lines** — findings reference DOM elements, not line numbers
- **Evidence** section is added — captures runtime proof (console output, network details, axe results)
- **Category** uses browser-specific categories instead of code routing categories

## Grouping

Within a specialist's report, findings are grouped by severity:

```markdown
## Findings

### BLOCKERs
{findings with BLOCKER severity}

### WARNINGs
{findings with WARNING severity}

### INFOs
{findings with INFO severity — only included in --deep mode}
```

## Empty Report

If a specialist finds NO issues, return:

```markdown
## {Agent Name} Report

**Verdict**: CLEAN
**Files reviewed**: {count}
**Findings**: 0

No issues found in the reviewed scope.
```

## Metadata Envelope

Every specialist report MUST end with a machine-readable metadata block:

```markdown
---
## Metadata
- **agent**: {agent-name}
- **review-id**: {review-id}
- **files-reviewed**: {count}
- **findings-count**: {total}
- **blockers**: {count}
- **warnings**: {count}
- **infos**: {count}
- **verdict-contribution**: CLEAN | HAS_WARNINGS | HAS_BLOCKERS
---
```

This metadata is consumed by `qa-report` for the consensus engine.
