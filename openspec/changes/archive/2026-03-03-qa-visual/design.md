# Design: QA Visual Specialist

## Technical Approach

Implement `qa-visual` as the second out-of-band runtime specialist in the QASE framework, mirroring the structural pattern established by `qa-browser`. Where qa-browser tests **functional correctness** of a live application (console errors, network health, interactive elements, navigation), qa-visual tests **visual correctness** (design system compliance, typography, color/contrast, layout integrity, responsive quality, animation behavior). Both use the Chrome DevTools MCP toolchain but target entirely different problem domains with zero overlap in finding categories.

The specialist follows a 10-step sequential pipeline that progressively deepens analysis from baseline capture through design token extraction, typographic audit, color/contrast validation, layout integrity, responsive viewport sweep, cross-viewport consistency, animation audit, pattern filtering, and final report generation. Depth controls (`concise | standard | deep`) bound the work at each step identically to qa-browser's model.

## Architecture Decisions

### Decision: Sequential Pipeline with Progressive Depth Gating

**Choice**: Execute all 10 steps sequentially, with depth controls gating how much work each step performs (not which steps execute).
**Alternatives considered**: (1) Skip entire steps at `concise` level -- rejected because even `concise` needs layout and typography checks at desktop; (2) Parallel step execution -- rejected because later steps depend on earlier captures (e.g., cross-viewport consistency needs screenshots from the responsive sweep).
**Rationale**: Sequential execution matches qa-browser's proven model. Progressive depth gating within each step keeps the pipeline structure stable across depth levels while controlling total runtime. The dependency chain between steps (baseline -> extraction -> validation -> comparison) requires sequential ordering.

### Decision: Computed Style Extraction via evaluate_script for Design Token Validation

**Choice**: Use `evaluate_script()` to run `window.getComputedStyle()` on DOM elements and compare extracted values against intra-page consistency heuristics and WCAG thresholds.
**Alternatives considered**: (1) Parse CSS source files for token definitions -- rejected (out of scope; qa-visual inspects the rendered DOM, not source); (2) Require users to provide a design token JSON file -- rejected (too much friction; the specialist must work with zero configuration); (3) Use `take_snapshot()` accessibility tree to infer styles -- rejected (accessibility tree lacks computed style values).
**Rationale**: `getComputedStyle()` is the only reliable way to get the final rendered values after cascade, inheritance, and specificity resolution. It works regardless of the CSS methodology (CSS-in-JS, Tailwind, vanilla CSS, SCSS). The specialist groups elements by semantic role (all headings, all buttons, all links) and checks consistency within groups -- this is a "design system compliance" heuristic that needs no external token file.

### Decision: Screenshot-Based Evidence with Viewport-Keyed Capture

**Choice**: Capture one PNG screenshot per viewport breakpoint using `take_screenshot()`, keyed by viewport dimensions. Screenshots serve as evidence for findings, not as diff inputs.
**Alternatives considered**: (1) Pixel-diff screenshots across viewports for regression detection -- rejected (requires a baseline image store which is out of scope); (2) Skip screenshots entirely and rely on DOM inspection -- rejected (visual bugs often only manifest visually, not in computed styles); (3) Multiple screenshots per viewport (above-the-fold, below-the-fold) -- rejected for `concise`/`standard` (too much data), accepted for `deep` mode only.
**Rationale**: Screenshots provide irreplaceable evidence for visual findings. By capturing at each breakpoint, findings can reference the exact visual state. Without a baseline image store, screenshots serve as documentation rather than automated diffing -- this is the correct scope boundary per the proposal ("pixel-perfect image diffing requires external tooling").

### Decision: Component Grouping Heuristic for Design System Compliance

**Choice**: Group DOM elements by semantic selector patterns (tag name + ARIA role + class-name prefix) and check consistency of computed styles within each group.
**Alternatives considered**: (1) Treat every element independently -- rejected (generates noise; intentional style variation within a group is a finding, random variation across unrelated elements is not); (2) Require a component manifest from the user -- rejected (zero-config principle).
**Rationale**: Grouping by `(tagName, role, classPrefix)` captures design system intent. For example, all `<button>` elements should share font-family, padding, and border-radius unless they are explicitly variant classes. Deviations within a group are flagged as `design-system` findings. The heuristic tolerates expected variation (e.g., `.btn-primary` vs `.btn-secondary` are different groups because their class prefixes differ).

### Decision: WCAG 2.1 Relative Luminance Algorithm for Contrast Checking

**Choice**: Implement WCAG 2.1 relative luminance contrast ratio calculation directly in `evaluate_script()`, operating on computed foreground/background color pairs.
**Alternatives considered**: (1) Rely on axe-core injection (as qa-browser does for accessibility) -- rejected (axe-core checks contrast but qa-visual needs finer-grained color palette analysis beyond what axe reports; also avoids duplicating qa-browser's axe-core domain); (2) Use a third-party contrast library -- rejected (adds CDN dependency for something implementable in ~30 lines of JS).
**Rationale**: The WCAG 2.1 contrast algorithm is well-specified (W3C formula for relative luminance + contrast ratio). Implementing it inline via `evaluate_script()` keeps the specialist self-contained. qa-visual checks ALL text-background pairs (not just axe violations), extracts the full color palette, and reports color consistency issues that axe-core does not cover. When qa-visual and qa-browser both run, qa-report deduplicates overlapping contrast findings.

### Decision: Three-Breakpoint Viewport Strategy with Mobile-First Sweep Order

**Choice**: Test at three breakpoints -- mobile (375x812), tablet (768x1024), desktop (1440x900) -- sweeping from mobile to desktop.
**Alternatives considered**: (1) Five breakpoints including small mobile (320x568) and large desktop (1920x1080) -- rejected for `standard` (too much work), accepted for `deep`; (2) Desktop-first sweep order -- rejected because mobile-first reveals the most critical responsive failures first; (3) Arbitrary user-provided breakpoints -- not rejected but deferred (future enhancement).
**Rationale**: These three breakpoints match the most common CSS media query boundaries and align with qa-browser's Step 7 viewport sizes for consistency. Mobile-first sweep order prioritizes the viewport where visual failures are most common and most impactful. `deep` mode adds 320x568 (small mobile) and 1920x1080 (large desktop) for completeness.

### Decision: Integrate with qa-report via Shared Issue Format (Visual Testing Variant)

**Choice**: Define a "Visual Testing Variant" of the issue format (adapted from the Browser Testing Variant) and feed findings through the standard qa-report consensus engine.
**Alternatives considered**: (1) Use the standard file-based issue format -- rejected (qa-visual findings reference URLs and DOM elements, not source files); (2) Skip qa-report integration and produce standalone verdicts -- rejected (breaks the QASE model where qa-report owns the final verdict).
**Rationale**: The Visual Testing Variant is structurally identical to the Browser Testing Variant but uses qa-visual-specific categories (`design-system`, `visual-regression`, `responsive`, `typography`, `layout`, `color`, `animation`). This means qa-report can ingest qa-visual findings using the same parsing logic it uses for qa-browser, with category-based deduplication handling overlap.

## Data Flow

### Sequence Diagram: Full qa-visual Pipeline

```
User                Orchestrator           qa-visual SKILL              Chrome DevTools MCP
 |                      |                       |                             |
 |  /qa-visual <url>    |                       |                             |
 |--------------------->|                       |                             |
 |                      |  Launch sub-agent     |                             |
 |                      |  (review-id, url,     |                             |
 |                      |   depth, mode)        |                             |
 |                      |---------------------->|                             |
 |                      |                       |                             |
 |                      |                       |  Step 1: Baseline Capture   |
 |                      |                       |  navigate_page(url)         |
 |                      |                       |---------------------------->|
 |                      |                       |  wait_for("load")           |
 |                      |                       |---------------------------->|
 |                      |                       |  take_screenshot()          |
 |                      |                       |---------------------------->|
 |                      |                       |  take_snapshot()            |
 |                      |                       |---------------------------->|
 |                      |                       |  <-- baseline data ---------|
 |                      |                       |                             |
 |                      |                       |  Step 2: Design System      |
 |                      |                       |  evaluate_script()          |
 |                      |                       |   [extract computed styles  |
 |                      |                       |    for component groups]    |
 |                      |                       |---------------------------->|
 |                      |                       |  <-- style map -------------|
 |                      |                       |  [compare within groups]    |
 |                      |                       |                             |
 |                      |                       |  Step 3: Typography         |
 |                      |                       |  evaluate_script()          |
 |                      |                       |   [font-family, fallbacks,  |
 |                      |                       |    line-height, overflow]   |
 |                      |                       |---------------------------->|
 |                      |                       |  <-- typography metrics ----|
 |                      |                       |                             |
 |                      |                       |  Step 4: Color & Contrast   |
 |                      |                       |  evaluate_script()          |
 |                      |                       |   [color palette, WCAG      |
 |                      |                       |    contrast ratios]         |
 |                      |                       |---------------------------->|
 |                      |                       |  <-- color data ------------|
 |                      |                       |                             |
 |                      |                       |  Step 5: Layout Integrity   |
 |                      |                       |  evaluate_script()          |
 |                      |                       |   [overlap detection,       |
 |                      |                       |    z-index, grid alignment] |
 |                      |                       |---------------------------->|
 |                      |                       |  <-- layout metrics --------|
 |                      |                       |                             |
 |                      |                       |  Step 6: Responsive Sweep   |
 |                      |                       |  FOR EACH breakpoint:       |
 |                      |                       |    resize_page(w, h)        |
 |                      |                       |---------------------------->|
 |                      |                       |    wait_for("load")         |
 |                      |                       |---------------------------->|
 |                      |                       |    take_screenshot()        |
 |                      |                       |---------------------------->|
 |                      |                       |    evaluate_script()        |
 |                      |                       |     [overflow, truncation,  |
 |                      |                       |      element visibility]    |
 |                      |                       |---------------------------->|
 |                      |                       |  <-- per-viewport data -----|
 |                      |                       |                             |
 |                      |                       |  Step 7: Cross-Viewport     |
 |                      |                       |  [Compare structural        |
 |                      |                       |   patterns across           |
 |                      |                       |   viewport captures]        |
 |                      |                       |                             |
 |                      |                       |  Step 8: Animation Audit    |
 |                      |                       |  evaluate_script()          |
 |                      |                       |   [CSS animations,          |
 |                      |                       |    transitions,             |
 |                      |                       |    prefers-reduced-motion]  |
 |                      |                       |---------------------------->|
 |                      |                       |  <-- animation data --------|
 |                      |                       |                             |
 |                      |                       |  Step 9: Filter Findings    |
 |                      |                       |  [Apply dismissed patterns  |
 |                      |                       |   from qa-feedback]         |
 |                      |                       |                             |
 |                      |                       |  Step 10: Report + Persist  |
 |                      |                       |  [Format findings, build    |
 |                      |                       |   report, persist to        |
 |                      |                       |   engram/openspec/inline]   |
 |                      |                       |                             |
 |                      |  <-- structured       |                             |
 |                      |      envelope ---------|                             |
 |  <-- verdict +       |                       |                             |
 |      summary --------|                       |                             |
```

### Internal Data Flow Between Steps

```
Step 1 (Baseline)
  ├── page_loaded: bool
  ├── desktop_screenshot: PNG reference
  ├── dom_snapshot: accessibility tree
  └── baseline_url: string
         │
         ▼
Step 2 (Design System) ──────────────────────────────────┐
  ├── component_groups: Map<GroupKey, Element[]>          │
  ├── style_map: Map<GroupKey, ComputedStyleSet>          │
  └── design_findings: Finding[]                         │
         │                                               │
         ▼                                               │
Step 3 (Typography)                                      │
  ├── font_families_used: Set<string>                    │
  ├── font_loading_status: Map<font, loaded|fallback>    │
  ├── text_overflow_elements: Element[]                  │
  └── typography_findings: Finding[]                     │
         │                                               │
         ▼                                               │
Step 4 (Color & Contrast)                                │
  ├── color_palette: Map<color, usage_count>             │
  ├── contrast_pairs: Array<{fg, bg, ratio, passes}>     │
  └── color_findings: Finding[]                          │
         │                                               │
         ▼                                               │
Step 5 (Layout Integrity)                                │
  ├── overlapping_elements: Array<{el1, el2, overlap}>   │
  ├── z_index_stack: Array<{element, z_index}>           │
  └── layout_findings: Finding[]                         │
         │                                               │
         ▼                                               │
Step 6 (Responsive Sweep)                                │
  ├── viewport_screenshots: Map<breakpoint, PNG>         │
  ├── viewport_metrics: Map<breakpoint, LayoutMetrics>   │
  └── responsive_findings: Finding[]                     │
         │                                               │
         ▼                                               │
Step 7 (Cross-Viewport Consistency) ◄────────────────────┘
  ├── structural_diffs: Array<{pattern, viewport_a, viewport_b}>
  └── consistency_findings: Finding[]
         │
         ▼
Step 8 (Animation Audit)
  ├── animations_detected: Array<{element, type, duration}>
  ├── reduced_motion_support: bool
  └── animation_findings: Finding[]
         │
         ▼
Step 9 (Filter)
  └── filtered_findings: Finding[]  (all categories, dismissed removed)
         │
         ▼
Step 10 (Report)
  ├── formatted_report: Markdown
  ├── metadata_envelope: JSON
  └── engram_observation_id: string (if engram mode)
```

## Chrome DevTools MCP Tool Usage Map

| Pipeline Step | MCP Tool | Purpose | Invocation Count |
|---------------|----------|---------|-----------------|
| Step 1: Baseline | `navigate_page` | Load the target URL | 1 |
| Step 1: Baseline | `wait_for` | Ensure page is fully loaded | 1 |
| Step 1: Baseline | `take_screenshot` | Capture desktop visual baseline | 1 |
| Step 1: Baseline | `take_snapshot` | Capture DOM/accessibility tree | 1 |
| Step 2: Design System | `evaluate_script` | Extract computed styles for all component groups | 1 (batch script) |
| Step 3: Typography | `evaluate_script` | Check font loading, measure text metrics | 1 (batch script) |
| Step 4: Color/Contrast | `evaluate_script` | Extract color palette, compute contrast ratios | 1 (batch script) |
| Step 5: Layout | `evaluate_script` | Detect overlaps, z-index issues, grid alignment | 1 (batch script) |
| Step 6: Responsive | `resize_page` | Change viewport to each breakpoint | 3-5 (per breakpoint) |
| Step 6: Responsive | `wait_for` | Allow layout reflow after resize | 3-5 (per breakpoint) |
| Step 6: Responsive | `take_screenshot` | Capture visual state at each breakpoint | 3-5 (per breakpoint) |
| Step 6: Responsive | `evaluate_script` | Check overflow, truncation, visibility at breakpoint | 3-5 (per breakpoint) |
| Step 8: Animation | `evaluate_script` | Detect CSS animations, transitions, reduced-motion | 1 |
| Step 8: Animation | `emulate` | Test `prefers-reduced-motion: reduce` media feature | 1 (deep only) |

**Total MCP calls by depth level:**

| Depth | Approximate MCP Calls | Rationale |
|-------|----------------------|-----------|
| `concise` | ~8 | Steps 1-5 only at desktop viewport, no responsive sweep |
| `standard` | ~22 | All steps, 3 breakpoints in responsive sweep |
| `deep` | ~32 | All steps, 5 breakpoints, emulate for reduced-motion |

## Component Breakdown: SKILL.md Structure

The `skills/qa-visual/SKILL.md` file follows the exact structural pattern of `skills/qa-browser/SKILL.md`:

```
skills/qa-visual/SKILL.md
├── Frontmatter (YAML)
│   ├── name: qa-visual
│   ├── description: Visual Inspector specialist
│   ├── metadata.framework: QASE
│   └── metadata.veto_power: false
│
├── Purpose
│   └── Role definition as Visual Inspector
│
├── What You Receive
│   └── Input contract (review-id, URL, depth, mode, dismissed patterns)
│
├── Execution and Persistence Contract
│   └── References to shared contracts + artifact type: visual-report
│
├── What to Do
│   ├── Step 1: Establish Connection + Visual Baseline
│   ├── Step 2: Design System Compliance
│   ├── Step 3: Typography Audit
│   ├── Step 4: Color and Contrast Audit
│   ├── Step 5: Layout Integrity
│   ├── Step 6: Responsive Viewport Sweep
│   ├── Step 7: Cross-Viewport Visual Consistency
│   ├── Step 8: Animation and Transition Audit
│   ├── Step 9: Apply Dismissed Patterns
│   └── Step 10: Produce Report + Persist
│
├── Report Format
│   ├── Visual Health Summary table
│   └── Metadata envelope
│
├── Depth Controls
│   ├── concise: desktop only, Steps 1-5, max 5 component groups
│   ├── standard: all steps, 3 breakpoints, max 10 component groups
│   └── deep: all steps, 5 breakpoints, all component groups, full palette
│
├── Safety Rules
│   └── Read-only, no navigation away from URL, no modifications
│
└── Rules
    └── Behavioral guidelines matching qa-browser pattern
```

## Viewport Strategy

### Breakpoint Definitions

| Name | Width x Height | CSS Equivalent | When Used |
|------|---------------|----------------|-----------|
| Small Mobile | 320x568 | `max-width: 374px` | `deep` only |
| Mobile | 375x812 | `max-width: 767px` | `standard`, `deep` |
| Tablet | 768x1024 | `min-width: 768px` and `max-width: 1023px` | `standard`, `deep` |
| Desktop | 1440x900 | `min-width: 1024px` | ALL depth levels (baseline) |
| Large Desktop | 1920x1080 | `min-width: 1440px` | `deep` only |

### Sweep Order

```
concise:  [1440x900 only -- no sweep]

standard: 375x812 → 768x1024 → 1440x900
          (mobile-first, return to desktop as baseline)

deep:     320x568 → 375x812 → 768x1024 → 1440x900 → 1920x1080
          (smallest to largest, complete coverage)
```

### Per-Viewport Operations

At each breakpoint during the sweep:
1. `resize_page(width, height)` -- set viewport
2. `wait_for("load")` -- allow CSS reflow and lazy-loaded content
3. `take_screenshot()` -- capture visual evidence
4. `evaluate_script()` -- run viewport-specific checks:
   - Horizontal overflow: `document.documentElement.scrollWidth > viewportWidth`
   - Element visibility: critical elements still visible (navigation, CTAs)
   - Text truncation: elements with `overflow: hidden` + `text-overflow: ellipsis` that lose content
   - Spacing collapse: margin/padding values that collapse to zero at this viewport
   - Image scaling: images that overflow or become too small

### Responsive Failure Detection Heuristics

| Failure Type | Detection Method | Severity |
|-------------|------------------|----------|
| Horizontal scroll on mobile | `scrollWidth > clientWidth` | WARNING |
| Content hidden at breakpoint | Element with `display: none` that contains critical content | WARNING |
| Overlapping elements | `getBoundingClientRect()` intersection check | WARNING |
| Text unreadable at mobile | `font-size < 12px` computed at mobile viewport | WARNING |
| Navigation unreachable | Nav element or hamburger menu not visible/interactable | BLOCKER |
| Form inputs cut off | Input `width > viewport width` | BLOCKER |
| Images not scaling | Image `naturalWidth` exceeds viewport but no responsive sizing | WARNING |

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `skills/qa-visual/SKILL.md` | Create | Complete specialist skill definition -- the primary deliverable |
| `skills/_shared/qase/routing-rules.md` | Modify | Add qa-visual to the Out-of-Band Specialists table |
| `skills/_shared/qase/engram-convention.md` | Modify | Add `visual-report` to the Artifact Types table |
| `skills/_shared/qase/openspec-convention.md` | Modify | Add `visual.md` to the file paths table and directory tree |
| `skills/_shared/qase/issue-format.md` | Modify | Add Visual Testing Variant section (adapted from Browser Testing Variant) |

## Interfaces / Contracts

### Visual Testing Variant (Issue Format)

```markdown
### {SEVERITY}: {Title}

**Agent**: qa-visual
**URL**: `{page-url}`
**Element**: `{element description or CSS selector}`
**Viewport**: `{widthxheight at which the issue was observed}`
**Category**: {design-system | visual-regression | responsive | typography | layout | color | animation}

#### What Failed
{Concise description of the visual issue observed}

#### Why It Matters
{Impact on users -- broken visual hierarchy, inaccessible content, inconsistent brand, poor readability}

#### Senior Suggestion
{Actionable CSS/HTML fix -- concrete code, not vague advice}

#### Evidence
{Screenshot reference, computed style values, contrast ratio calculation, or viewport comparison}

#### References
- {Relevant standard: WCAG 2.1 SC X.Y.Z, Material Design guideline, CSS spec, etc.}
```

Key differences from Browser Testing Variant:
- **Viewport** field added -- visual findings are viewport-specific
- **Category** uses visual-specific categories instead of browser-specific categories
- **Evidence** emphasizes computed style values and contrast calculations rather than console/network data

### Structured Envelope (Return Format)

```yaml
status: "completed" | "partial" | "failed"
executive_summary: "One-paragraph summary of visual health"
artifacts:
  - type: "visual-report"
    location: "engram:{observation-id}" | "openspec:qaspec/reviews/{id}/visual.md" | "inline"
verdict_contribution: "CLEAN" | "HAS_WARNINGS" | "HAS_BLOCKERS"
risks:
  - description: "Risk encountered during analysis"
    mitigation: "What was done about it"
```

### Engram Artifact Naming

```
title:     qase/{review-id}/visual-report
topic_key: qase/{review-id}/visual-report
type:      architecture
project:   {detected project name}
scope:     project
```

### OpenSpec File Path

```
qaspec/reviews/{review-id}/visual.md
```

### Report Format

```markdown
## Visual Inspector Report

**Review ID**: {review-id}
**URL tested**: {url}
**Viewports tested**: {list of breakpoints}
**Philosophy**: "If a user can see it, it should look right"

### Findings

#### BLOCKERs
{findings}

#### WARNINGs
{findings}

#### INFOs
{findings -- only if deep mode}

### Visual Health Summary

| Category | Status | Findings |
|----------|--------|----------|
| Design System Compliance | {CONSISTENT/DEVIATIONS/INCONSISTENT} | {count} |
| Typography | {CLEAN/ISSUES/BROKEN} | {count} |
| Color & Contrast | {COMPLIANT/PARTIAL/FAILING} | {count} |
| Layout Integrity | {SOLID/ISSUES/BROKEN} | {count} |
| Responsive Design | {SOLID/ISSUES/BROKEN} | {count} |
| Cross-Viewport Consistency | {CONSISTENT/DRIFTING/BROKEN} | {count} |
| Animations | {CLEAN/ISSUES/BROKEN} | {count} |

### Color Palette Extracted

| Color | Hex | Usage Count | Role |
|-------|-----|-------------|------|
| {swatch} | {#hex} | {N} | {text/background/accent/border} |

### Contrast Audit Summary

| Pair | Foreground | Background | Ratio | AA | AAA |
|------|-----------|------------|-------|----|-----|
| {description} | {#hex} | {#hex} | {N:1} | {PASS/FAIL} | {PASS/FAIL} |

---
## Metadata
- **agent**: qa-visual
- **review-id**: {review-id}
- **url-tested**: {url}
- **viewports-tested**: {count}
- **findings-count**: {total}
- **blockers**: {count}
- **warnings**: {count}
- **infos**: {count}
- **verdict-contribution**: CLEAN | HAS_WARNINGS | HAS_BLOCKERS
---
```

## Error Handling Strategy

| Error Condition | Detection | Response | Continue? |
|----------------|-----------|----------|-----------|
| Page fails to load | `navigate_page` timeout or error | Report BLOCKER: "Application unreachable at {url}" | STOP -- no further steps possible |
| Page loads but is blank | `take_snapshot` returns empty DOM | Report BLOCKER: "Page rendered with empty body" | STOP |
| `evaluate_script` fails (CSP) | Script execution error | Degrade: skip computed style extraction, rely on snapshot-based visual review; note limitation in report | YES (degraded) |
| `resize_page` fails | MCP tool error | Report WARNING: "Viewport resize unavailable"; skip responsive sweep (Steps 6-7) | YES (skip Steps 6-7) |
| `take_screenshot` fails | MCP tool error | Report INFO: "Screenshots unavailable"; continue with DOM-only analysis; note missing evidence | YES (degraded) |
| `emulate` fails | MCP tool error at deep level | Skip `prefers-reduced-motion` emulation; note in animation audit | YES |
| Single breakpoint times out | `wait_for` timeout after resize | Skip that breakpoint; report WARNING: "Viewport {WxH} timed out" | YES (skip breakpoint) |
| Too many elements in DOM | Element count > 1000 in a component group | Apply sampling: analyze first N elements per group (N from depth limit) | YES (bounded) |
| Font loading check fails | `document.fonts.check()` unsupported | Skip font loading verification; report INFO: "Font loading API unavailable" | YES (degraded) |
| Computed style returns empty | Element detached or hidden | Skip element; do not generate finding for it | YES |

### Graceful Degradation Principle

The pipeline NEVER hard-fails after Step 1 succeeds. If any tool call fails in Steps 2-8, the specialist:
1. Records the failure as an INFO-level finding noting the degradation
2. Continues to the next step
3. Notes the degraded coverage in the final report metadata

This matches qa-browser's pattern where axe-core injection failure does not halt the entire review.

## Performance Considerations: Work Bounds by Depth Level

| Metric | Concise | Standard | Deep |
|--------|---------|----------|------|
| Viewports tested | 1 (desktop) | 3 | 5 |
| Component groups analyzed | Max 5 | Max 10 | All |
| Elements per group | Max 3 | Max 10 | All |
| Text-background contrast pairs | Max 20 | Max 50 | All |
| Color palette entries reported | Top 5 | Top 15 | All |
| Screenshots captured | 1 | 4 (1 baseline + 3 viewports) | 6 (1 baseline + 5 viewports) |
| Animations checked | First 3 | First 10 | All |
| MCP tool calls (approximate) | ~8 | ~22 | ~32 |
| Expected runtime | < 30s | < 90s | < 180s |
| INFO findings included | No | No | Yes |

### Why These Bounds

- **Component group limits**: A typical page has 5-15 distinct component groups. Concise checks the most prominent ones (headings, buttons, links, inputs, cards). Standard covers all common groups. Deep is exhaustive.
- **Element-per-group limits**: Checking 3 elements per group is sufficient to detect consistency violations (if element 1 and 3 differ, there is a problem). Standard's 10 elements catches subtler deviations. Deep checks everything.
- **Contrast pair limits**: WCAG contrast checking is O(N) per text element. Concise prioritizes body text and headings. Standard covers interactive elements. Deep covers everything including decorative text.
- **MCP call batching**: Steps 2-5 each use a SINGLE `evaluate_script()` call with a comprehensive inline script that returns all needed metrics in one round-trip. This is critical for performance -- one batched call vs N individual calls per element.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Lint | SKILL.md frontmatter and structure | Run `scripts/lint_skills.sh` -- must pass without errors |
| Integration | Shared contract references | Verify all `skills/_shared/qase/*.md` references resolve correctly |
| Integration | Routing-rules update | Verify qa-visual appears in the Out-of-Band Specialists table |
| Integration | Engram convention | Verify `visual-report` appears in the Artifact Types table |
| Integration | OpenSpec convention | Verify `visual.md` appears in the file path table |
| Integration | Issue format | Verify Visual Testing Variant section is well-formed |
| Manual | Solo command | Run `/qa-visual <url>` against a test page and verify 10-step pipeline executes |
| Manual | Depth control | Run at `concise`, `standard`, and `deep` and verify bounds are respected |
| Manual | Error handling | Test with an unreachable URL and verify BLOCKER + early termination |

## Migration / Rollout

No migration required. qa-visual is a new specialist with no existing data, no database changes, and no infrastructure requirements beyond the Chrome DevTools MCP server (already required by qa-browser). Rollback is a clean file revert as specified in the proposal.

## Open Questions

- [ ] Should qa-visual detect and report on dark mode / light mode toggle consistency? (Recommendation: Defer to a future enhancement -- detecting theme toggles requires interaction, which is qa-browser's domain. qa-visual inspects the current rendered state only.)
- [ ] Should the color palette extraction deduplicate near-identical colors (e.g., `#333` vs `#334`)? (Recommendation: Yes, use a Delta-E threshold of 2.0 for perceptual similarity grouping -- implement in the `evaluate_script` that extracts the palette.)
