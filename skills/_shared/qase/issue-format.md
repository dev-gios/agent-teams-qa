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
**Oracle Tier**: L1 | L2 | L3-schema | L3-inferred | L4

#### What Failed
{Concise description of the runtime issue observed}

#### Why It Matters
{Impact on real users — broken functionality, inaccessibility, poor experience}

#### Senior Suggestion
{Actionable fix — code snippet, configuration change, or specific remediation}

#### Evidence
{Console error text, network request details, axe-core violation, or screenshot reference}

#### Oracle Citation
{path:line — verbatim literal from the cited source}
{Or, if no L3-schema source was found: Oracle Absence note — e.g., "L1 unavailable: no openspec/ directory. L2 unavailable: no test runner detected. L3-schema unavailable: no schema file declares this field."}

#### References
- {Relevant standard: WCAG 2.1 SC X.Y.Z, Web Vitals threshold, OWASP rule, etc.}
```

Key differences from the standard format:
- **URL** replaces **File** — findings reference the page URL, not a source file
- **Element** replaces **Lines** — findings reference DOM elements, not line numbers
- **Oracle Tier** field is required — must match the tier resolved by the Oracle Resolution Algorithm
- **Evidence** section is added — captures runtime proof (console output, network details, axe results)
- **Oracle Citation** section is required — `path:line` + verbatim literal, or the Oracle Absence note if no L3-schema source was found
- **Category** uses browser-specific categories instead of code routing categories

## Visual Testing Variant

`qa-visual` uses an adapted finding format for visual issues discovered in a live application:

```markdown
### {SEVERITY}: {Title}

**Agent**: qa-visual
**URL**: `{page-url}`
**Element**: `{element description or CSS selector}`
**Viewport**: `{widthxheight}`
**Category**: {design-system | visual-regression | responsive | typography | layout | color | animation}
**Oracle Tier**: L1 | L2 | L3-schema | L3-inferred | L4

#### What Failed
{Concise description of the visual issue observed}

#### Why It Matters
{Impact on real users — visual inconsistency, accessibility barrier, poor responsive experience, broken visual hierarchy}

#### Senior Suggestion
{Actionable CSS/HTML fix or design system recommendation — concrete code, not vague advice}

#### Evidence
{Screenshot reference, computed style values, contrast ratio calculation, or viewport comparison}

#### Oracle Citation
{Named standard — e.g., "WCAG 2.1 SC 1.4.3 — Contrast (Minimum)" or "Web Vitals — LCP threshold 2.5 s"}
{Note: qa-visual findings are predominantly L4. State the named WCAG SC or named standard as the citation.}

#### References
- {Relevant standard: WCAG 2.1 SC X.Y.Z, design system guideline, CSS specification, etc.}
```

Key differences from the Browser Testing Variant:
- **Viewport** field added — visual findings are viewport-specific (e.g., `1440x900`, `375x812`)
- **Oracle Tier** field is required — qa-visual findings are predominantly L4 (contrast ratios, spacing, motion heuristics); state the named WCAG SC or named standard as the citation per `oracle-contract.md`
- **Oracle Citation** section is required — for L4, name the standard (e.g., `WCAG 2.1 SC 1.4.3`); advisory only at L4
- **Category** uses visual-specific categories (`design-system`, `visual-regression`, `responsive`, `typography`, `layout`, `color`, `animation`) instead of browser-specific categories (`console-errors`, `network`, `accessibility`, `interaction`, `navigation`, `responsive`, `performance`, `user-flow`)
- **Evidence** emphasizes computed style values, contrast ratio calculations, and viewport comparisons rather than console output or network request data

## Flow Evidence Format

Use this format for the per-step flow evidence document produced by `qa-browser` Step 9.

### Flow Evidence Document Header

```markdown
## Flow Evidence: {flow-name}

**Started at**: {ISO-8601 timestamp}
**App URL**: {url}
**Session**: {session-id}
**Oracle sources consulted**: {L1 spec file(s) | L2 test runner | L3 schema file(s) | L3-inferred pattern(s) | L4 standard(s) — list all}
```

### Per-Step Evidence Table

| Step | Action | Observed | Expected | Oracle Tier | Status | Artifact |
|------|--------|----------|----------|-------------|--------|----------|
| 01 | {action performed, e.g., "fill email field with qase+{RUN}@example.com"} | {what was observed} | {what was expected, with citation} | {L1\|L2\|L3-schema\|L3-inferred\|L4\|UNGROUNDED} | {PASS \| FAIL — BLOCKER \| FAIL — WARNING \| INCONCLUSIVE \| SKIPPED} | {relative path to screenshot, e.g., flow-evidence/{slug}/screenshots/step-01.png} |

**Status value contract**:
- `PASS` — observed satisfies the resolved expectation
- `FAIL — BLOCKER` — observed contradicts expectation; tier is L1, L2, or L3-schema; severity BLOCKER
- `FAIL — WARNING` — observed contradicts expectation; tier is L3-inferred or L4; severity capped at WARNING
- `INCONCLUSIVE` — action could not be performed, daemon lost, observation ambiguous, or oracle UNGROUNDED
- `SKIPPED` — refused by policy (production write flow, destructive element, missing credentials)

Bare `FAIL` without a severity qualifier is **never valid**. Every FAIL must carry its severity.

### Flow Summary Table

| Metric | Value |
|--------|-------|
| Steps executed | {n} |
| Passed | {n} |
| Failed | {n} |
| BLOCKERs | {n} |
| WARNINGs | {n} |
| Video evidence | {path or `—` (not recorded)} |
| Network log (HAR) | {path or `—` (not recorded)} |

### Test Data Ledger

| Identity Type | Value | Created At Step | Cleanup |
|---------------|-------|-----------------|---------|
| {user\|org\|record} | {e.g., qase+1774915200-a3f19c@example.com} | Step {n} | {hook invoked and result, or "none — no cleanup hook detected"} |

For read-only flows, record `—` in all Value cells rather than omitting the table. An empty table means "no records were tracked", which is different from "no records were created."

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
- **oracle_tier_breakdown**: { L1: {n}, L2: {n}, L3-schema: {n}, L3-inferred: {n}, L4: {n} }
- **flow-evidence**: {path | topic_key | none}
- **runtime-available**: true | false
---
```

This metadata is consumed by `qa-report` for the consensus engine.

- `oracle_tier_breakdown` is required for runtime specialists (`qa-browser`, `qa-visual`). Static specialists omit it.
- `flow-evidence` is required for `qa-browser` when Step 9 was executed. Value is a file path (openspec mode), a topic_key (engram mode), or `none` (no flows executed or no persistence).
- `runtime-available` is required for `qa-browser` and `qa-visual`. Reflects the preflight cache result. Static specialists omit it.
