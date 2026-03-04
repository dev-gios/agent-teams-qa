# QA Visual Specialist Specification

## Purpose

Define the behavior of `qa-visual`, a QASE runtime specialist that connects to a live application via Chrome DevTools MCP and performs visual regression testing, design system compliance analysis, responsive design validation, and visual accessibility auditing. This specialist complements `qa-browser` (functional/interactive testing) with a visual-first perspective.

## Requirements

### Requirement: Solo Runtime Specialist Launch

The system MUST launch `qa-visual` as an out-of-band specialist via the `/qa-visual <url>` command. It SHALL NOT be activated by `qa-scan` or appear in the routing matrix.

#### Scenario: Basic visual audit at concise depth on a single URL

- GIVEN the user invokes `/qa-visual https://example.com`
- AND no explicit depth is specified (defaults to `concise`)
- WHEN the orchestrator launches the qa-visual specialist
- THEN the specialist MUST connect to the URL via Chrome DevTools MCP
- AND capture a visual baseline screenshot at desktop viewport (1440x900) only
- AND perform design system compliance, typography, color/contrast, and layout integrity checks at desktop viewport only
- AND skip responsive viewport sweeps (Steps 6-7) and animation auditing (Step 8)
- AND produce a report containing only BLOCKER and WARNING findings
- AND return a structured envelope with `status`, `executive_summary`, `artifacts`, `verdict_contribution`, and `risks`

#### Scenario: Launch with explicit depth and auth credentials

- GIVEN the user invokes `/qa-visual https://app.example.com --deep --auth user:pass`
- WHEN the orchestrator launches the qa-visual specialist with depth `deep` and credentials
- THEN the specialist MUST authenticate before capturing baselines
- AND execute all 10 analysis steps without element limits
- AND include INFO findings in the report

### Requirement: Connection Establishment and Visual Baseline Capture

The system MUST establish a Chrome DevTools connection to the target URL and capture a visual baseline before any analysis.

#### Scenario: Successful baseline capture at desktop viewport

- GIVEN a reachable URL at `https://example.com`
- WHEN qa-visual begins Step 1 (baseline capture)
- THEN it MUST call `navigate_page(url)` to load the application
- AND call `wait_for("load")` to ensure the page is fully rendered
- AND call `take_screenshot()` to capture the desktop baseline (1440x900)
- AND call `take_snapshot()` to capture the DOM tree for structural analysis
- AND record the baseline as evidence for later cross-viewport comparison

#### Scenario: Unreachable URL produces BLOCKER and halts

- GIVEN a URL that fails to load (timeout, DNS error, connection refused)
- WHEN qa-visual attempts Step 1
- THEN it MUST produce a single BLOCKER finding: "Application unreachable at {url}"
- AND MUST stop execution immediately (no further steps)
- AND return a report with `verdict_contribution: HAS_BLOCKERS`

#### Scenario: Page loads but Chrome DevTools MCP is unavailable

- GIVEN the Chrome DevTools MCP server is not connected in the current session
- WHEN qa-visual is launched
- THEN it MUST detect the absence of Chrome DevTools MCP tools (`take_screenshot`, `navigate_page`, `evaluate_script`)
- AND produce a single BLOCKER finding: "Chrome DevTools MCP unavailable — cannot perform visual analysis"
- AND MUST stop execution immediately
- AND return a report with `verdict_contribution: HAS_BLOCKERS`

#### Scenario: Page load timeout after partial render

- GIVEN a URL where the page begins loading but does not complete within 30 seconds
- WHEN qa-visual waits for the load event
- THEN it MUST capture whatever has rendered as a degraded baseline
- AND produce a WARNING finding: "Page did not fully load within timeout — analysis may be incomplete"
- AND proceed with analysis on the partially loaded page

### Requirement: Design System Compliance Analysis

The system MUST extract computed styles from rendered DOM elements and check for visual consistency across similar components.

#### Scenario: Deep design system compliance audit detects inconsistent component styles

- GIVEN a page with multiple button elements rendered with different font sizes, colors, or border-radius values
- WHEN qa-visual executes Step 2 (design system compliance) at `deep` depth
- THEN it MUST call `evaluate_script()` to extract computed styles (color, font-family, font-size, font-weight, padding, margin, border-radius, box-shadow, background-color) from all button-like elements
- AND group elements by semantic role (same tag + similar class patterns)
- AND compare computed style values within each group
- AND produce a WARNING or BLOCKER finding for each group where values diverge beyond a threshold
- AND the finding category MUST be `design-system`
- AND the finding MUST include evidence showing the divergent values per element

#### Scenario: Concise depth limits design system check to key component types

- GIVEN a page at `concise` depth
- WHEN qa-visual executes Step 2
- THEN it MUST check only primary component types: buttons, headings, links, and form inputs
- AND limit analysis to at most 3 elements per component type

#### Scenario: Standard depth checks all visible components with element limit

- GIVEN a page at `standard` depth
- WHEN qa-visual executes Step 2
- THEN it MUST check all visible semantic component groups
- AND limit analysis to at most 10 elements per component type
- AND include spacing consistency (margin/padding patterns) across sibling elements

### Requirement: Typography Audit

The system MUST audit font loading, fallback rendering, text overflow behavior, line height, and readability.

#### Scenario: Font loading failure detected

- GIVEN a page that references a web font (e.g., via Google Fonts or `@font-face`) that fails to load
- WHEN qa-visual executes Step 3 (typography audit)
- THEN it MUST call `evaluate_script()` to check `document.fonts.check()` for each declared font family
- AND detect any font that has not loaded successfully
- AND produce a WARNING finding with category `typography`
- AND the "Senior Suggestion" MUST include specifying proper `font-display` values and fallback font stacks

#### Scenario: Text overflow without visible handling

- GIVEN a page with text content that overflows its container without ellipsis, scroll, or visible truncation
- WHEN qa-visual executes Step 3
- THEN it MUST call `evaluate_script()` to detect elements where `scrollWidth > clientWidth` or `scrollHeight > clientHeight` without `overflow: hidden`, `overflow: scroll`, or `text-overflow: ellipsis`
- AND produce a WARNING finding with category `typography`
- AND include the element selector and overflow dimensions as evidence

#### Scenario: Line height below readability threshold

- GIVEN text elements with computed `line-height` below 1.5 for body text (paragraph elements)
- WHEN qa-visual executes Step 3
- THEN it SHOULD produce an INFO finding with category `typography`
- AND reference WCAG 2.1 SC 1.4.12 (Text Spacing) as the standard

### Requirement: Color and Contrast Audit (WCAG Compliance)

The system MUST extract foreground/background color combinations and verify WCAG 2.1 contrast ratio requirements.

#### Scenario: Insufficient contrast ratio on normal text

- GIVEN a page with text elements where the foreground-to-background contrast ratio is below 4.5:1 for normal text (below 18pt or below 14pt bold)
- WHEN qa-visual executes Step 4 (color and contrast audit)
- THEN it MUST call `evaluate_script()` to compute the contrast ratio using the WCAG 2.1 relative luminance algorithm
- AND produce a BLOCKER finding with category `color` for each failing combination
- AND the evidence MUST include the computed ratio, the foreground color, the background color, and the element selector
- AND reference WCAG 2.1 SC 1.4.3 (Contrast — Minimum)

#### Scenario: Large text with moderately insufficient contrast

- GIVEN text elements at or above 18pt (or 14pt bold) where the contrast ratio is between 3:1 and 4.5:1
- WHEN qa-visual executes Step 4
- THEN it MUST NOT produce a BLOCKER (large text threshold is 3:1 per WCAG 2.1)
- AND it SHOULD produce an INFO finding suggesting improvement above 4.5:1 for enhanced readability

#### Scenario: Color-only information conveyance detected

- GIVEN an element that uses color as the sole means of conveying information (e.g., red/green status indicators without icons or text labels)
- WHEN qa-visual executes Step 4
- THEN it MUST produce a WARNING finding with category `color`
- AND reference WCAG 2.1 SC 1.4.1 (Use of Color)
- AND the "Senior Suggestion" MUST recommend adding non-color indicators (icons, patterns, or text labels)

### Requirement: Layout Integrity Check

The system MUST detect overlapping elements, broken grid alignment, unexpected whitespace, and z-index stacking issues.

#### Scenario: Overlapping elements detected

- GIVEN a page where two or more visible elements have overlapping bounding rectangles and neither has `position: static`
- WHEN qa-visual executes Step 5 (layout integrity)
- THEN it MUST call `evaluate_script()` to compute bounding rectangles via `getBoundingClientRect()` for positioned elements
- AND detect overlaps that obscure content (not intentional layering like tooltips or modals)
- AND produce a WARNING finding with category `layout`
- AND include the selectors and bounding rectangle coordinates as evidence

#### Scenario: Unexpected large whitespace gap

- GIVEN a page where a visible region has a gap exceeding 200px in height with no content
- WHEN qa-visual executes Step 5
- THEN it SHOULD produce an INFO finding with category `layout` noting the potential unintentional whitespace
- AND include a screenshot reference showing the gap location

### Requirement: Multi-Viewport Responsive Check

The system MUST resize the viewport to standard breakpoints and validate layout at each size.

#### Scenario: Standard depth responsive sweep across three breakpoints

- GIVEN a page at `standard` depth
- WHEN qa-visual executes Step 6 (responsive viewport sweep)
- THEN it MUST call `resize_page()` to set the viewport to each of: mobile (375x812), tablet (768x1024), and desktop (1440x900)
- AND at each viewport call `wait_for("load")` to allow layout reflow
- AND call `take_screenshot()` to capture the visual state
- AND call `evaluate_script()` to check for horizontal overflow (`document.documentElement.scrollWidth > viewport width`)
- AND detect elements overflowing the viewport boundary
- AND reset to desktop (1440x900) after completing all viewports

#### Scenario: Horizontal scroll detected on mobile viewport

- GIVEN a page where the content width exceeds 375px at mobile viewport
- WHEN qa-visual captures the mobile viewport state
- THEN it MUST produce a WARNING finding with category `responsive`
- AND include the computed `scrollWidth` vs viewport width as evidence
- AND the "Senior Suggestion" MUST recommend checking for fixed-width containers or unresponsive images

#### Scenario: Content completely inaccessible at a viewport

- GIVEN a page where critical content (navigation, main content area, or call-to-action) is hidden, overflowed, or unreachable at mobile viewport
- WHEN qa-visual evaluates the mobile viewport
- THEN it MUST produce a BLOCKER finding with category `responsive`
- AND include the element selector and the viewport at which it becomes inaccessible

#### Scenario: Concise depth skips responsive sweep entirely

- GIVEN a page at `concise` depth
- WHEN qa-visual reaches Step 6
- THEN it MUST skip Steps 6, 7, and 8 entirely
- AND note in the report metadata that responsive checks were skipped due to depth level

#### Scenario: Deep depth tests additional breakpoints

- GIVEN a page at `deep` depth
- WHEN qa-visual executes Step 6
- THEN it MUST test all three standard breakpoints (375x812, 768x1024, 1440x900)
- AND MAY test additional breakpoints (e.g., 320x568 small mobile, 1920x1080 large desktop) for comprehensive coverage
- AND remove the 10-element limit per check, analyzing all visible elements at each viewport

### Requirement: Cross-Viewport Visual Consistency

The system MUST compare structural patterns across viewports to detect inconsistent behavior during layout adaptation.

#### Scenario: Navigation collapse verified across viewports

- GIVEN a page with a desktop navigation bar that collapses to a hamburger menu on mobile
- WHEN qa-visual executes Step 7 (cross-viewport consistency)
- THEN it MUST verify that the navigation is present and accessible at all tested viewports
- AND check that the collapsed mobile navigation can be toggled open (element exists in DOM)
- AND produce no finding if the adaptation is structurally consistent

#### Scenario: Content disappears at intermediate viewport

- GIVEN a page where a sidebar section is visible at desktop but absent (not just hidden) at tablet viewport
- WHEN qa-visual compares the DOM snapshots across viewports
- THEN it MUST produce a WARNING finding with category `visual-regression`
- AND note which content elements are missing at which viewport
- AND the "Senior Suggestion" SHOULD recommend using responsive CSS (`display: none` with media queries) rather than removing DOM elements

### Requirement: Animation and Transition Audit

The system MUST detect CSS animations and transitions and verify `prefers-reduced-motion` support.

#### Scenario: Animations present without prefers-reduced-motion support

- GIVEN a page with CSS `animation` or `transition` properties applied to visible elements
- AND no `@media (prefers-reduced-motion: reduce)` rule is detected that disables or reduces those animations
- WHEN qa-visual executes Step 8 (animation and transition audit)
- THEN it MUST call `evaluate_script()` to detect elements with non-`none` `animation-name` or non-zero `transition-duration` computed styles
- AND call `evaluate_script()` to check for the presence of `prefers-reduced-motion` media queries in loaded stylesheets
- AND produce a WARNING finding with category `animation`
- AND reference WCAG 2.1 SC 2.3.3 (Animation from Interactions) and the `prefers-reduced-motion` CSS feature
- AND the "Senior Suggestion" MUST include a CSS code snippet wrapping animations in a `prefers-reduced-motion` media query

#### Scenario: No animations detected on page

- GIVEN a page with no CSS animations or transitions on visible elements
- WHEN qa-visual executes Step 8
- THEN it MUST skip this check and record "No animations detected" in the report

### Requirement: Finding Persistence to Engram

The system MUST persist its report to Engram when `artifact_store.mode` is `engram`, using the deterministic naming convention.

#### Scenario: Successful engram persistence of visual report

- GIVEN the artifact store mode is `engram`
- AND the review ID is `2026-03-03-visual-example-com`
- AND the project name is `agent-teams-qa`
- WHEN qa-visual completes all analysis steps and produces findings
- THEN it MUST call `mem_save()` with:
  - `title`: `qase/2026-03-03-visual-example-com/visual-report`
  - `topic_key`: `qase/2026-03-03-visual-example-com/visual-report`
  - `type`: `architecture`
  - `project`: `agent-teams-qa`
  - `content`: the full markdown report including all findings and metadata
- AND it MUST return the observation ID in the `artifacts` field of its structured envelope

#### Scenario: Engram persistence failure degrades gracefully to inline

- GIVEN the artifact store mode is `engram`
- AND the `mem_save()` call fails (Engram unavailable mid-review)
- WHEN qa-visual attempts to persist its report
- THEN it MUST return the full report inline in the structured envelope
- AND set the `artifacts` field to an empty list
- AND include a risk note: "Engram persistence failed — report returned inline only"

#### Scenario: Openspec mode persists to filesystem

- GIVEN the artifact store mode is `openspec`
- AND the review ID is `2026-03-03-visual-example-com`
- WHEN qa-visual completes its analysis
- THEN it MUST write the report to `qaspec/reviews/2026-03-03-visual-example-com/visual.md`
- AND return the file path in the `artifacts` field

#### Scenario: None mode returns inline only

- GIVEN the artifact store mode is `none`
- WHEN qa-visual completes its analysis
- THEN it MUST NOT create or modify any project files
- AND it MUST NOT call any Engram functions
- AND it MUST return the full report inline in the structured envelope

### Requirement: Integration with qa-report

The system MUST produce findings in the standard QASE issue format (Visual Testing Variant) and contribute a verdict that the qa-report consensus engine can consume.

#### Scenario: Visual findings feed into qa-report consensus engine

- GIVEN qa-visual has produced findings for a review
- AND the orchestrator subsequently launches qa-report for the same review ID
- WHEN qa-report retrieves the visual report (via Engram or filesystem)
- THEN qa-report MUST be able to parse the Visual Testing Variant findings
- AND include qa-visual findings in the deduplication pass
- AND respect that qa-visual does NOT have veto power (its BLOCKERs can be overridden by consensus)
- AND include `qa-visual` in the specialist summary table of the final report

#### Scenario: Visual report metadata envelope is machine-parseable

- GIVEN qa-visual produces a report
- THEN the report MUST end with a metadata envelope containing:
  - `agent`: `qa-visual`
  - `review-id`: the review identifier
  - `url-tested`: the target URL
  - `viewports-tested`: list of viewport dimensions checked
  - `findings-count`: total number of findings
  - `blockers`: count of BLOCKER findings
  - `warnings`: count of WARNING findings
  - `infos`: count of INFO findings
  - `verdict-contribution`: one of `CLEAN`, `HAS_WARNINGS`, or `HAS_BLOCKERS`

#### Scenario: Visual Testing Variant finding format

- GIVEN qa-visual produces a finding
- THEN the finding MUST follow the Visual Testing Variant of the issue format:
  - `Agent`: `qa-visual`
  - `URL`: the page URL where the issue was found
  - `Element`: CSS selector or element description identifying the affected element
  - `Category`: one of `design-system`, `visual-regression`, `responsive`, `typography`, `layout`, `color`, `animation`
  - `What Failed`: factual description of the visual issue
  - `Why It Matters`: impact on real users (visual inconsistency, accessibility barrier, poor responsive experience)
  - `Senior Suggestion`: actionable CSS/HTML fix or design system recommendation with code
  - `Evidence`: screenshot reference, computed style values, or measurement data
  - `References`: relevant standard (WCAG, design system guidelines)

### Requirement: Handling Dismissed Patterns from qa-feedback

The system MUST respect dismissed patterns when producing findings.

#### Scenario: PROJECT_RULE dismissed pattern suppresses matching findings

- GIVEN a dismissed pattern exists for qa-visual with type `PROJECT_RULE` and pattern slug `intentional-color-variation`
- AND the pattern matches findings in the `design-system` category for elements matching `*.variant-*` selector pattern
- WHEN qa-visual executes Step 9 (apply dismissed patterns)
- THEN it MUST suppress all findings matching the dismissed pattern
- AND NOT include them in the final report
- AND NOT count them toward the findings total in the metadata

#### Scenario: FALSE_POSITIVE dismissed pattern suppresses matching findings

- GIVEN a dismissed pattern exists for qa-visual with type `FALSE_POSITIVE` and pattern slug `logo-contrast`
- WHEN qa-visual encounters a contrast finding for the logo element matching that pattern
- THEN it MUST suppress the finding entirely

#### Scenario: ONE_TIME dismissed pattern includes but marks the finding

- GIVEN a dismissed pattern exists for qa-visual with type `ONE_TIME` and pattern slug `legacy-font-fallback`
- WHEN qa-visual encounters a typography finding matching that pattern
- THEN it MUST include the finding in the report
- AND mark it with a note: "Previously dismissed (ONE_TIME) — re-evaluate"

#### Scenario: No dismissed patterns exist for qa-visual

- GIVEN no dismissed patterns exist for the qa-visual agent
- WHEN qa-visual executes Step 9
- THEN it MUST include all findings without suppression
- AND proceed normally to report production

#### Scenario: Loading dismissed patterns from Engram

- GIVEN the artifact store mode is `engram`
- AND the project name is `agent-teams-qa`
- WHEN qa-visual needs to load dismissed patterns
- THEN it MUST call `mem_search(query: "qase/agent-teams-qa/feedback/qa-visual/", project: "agent-teams-qa")`
- AND for each result, call `mem_get_observation(id)` to retrieve the full dismissed pattern content
- AND apply each pattern during Step 9

### Requirement: Safety Constraints

The system MUST operate in read-only mode, MUST NOT modify the application state, and MUST NOT navigate to external domains.

#### Scenario: Read-only operation — no DOM modifications

- GIVEN qa-visual is connected to a live application
- WHEN it executes any analysis step
- THEN it MUST NOT call any function that modifies the DOM (no `click()`, `fill()`, `fill_form()`, `type_text()`)
- AND it MUST only use read-only MCP tools: `navigate_page()` (to the target URL only), `take_screenshot()`, `take_snapshot()`, `evaluate_script()` (for reading computed styles and measurements only), `resize_page()`, `emulate()`, `list_console_messages()`, `list_network_requests()`
- AND `evaluate_script()` calls MUST NOT modify the DOM, add elements, remove elements, or change styles

#### Scenario: No external navigation

- GIVEN the target URL is `https://example.com`
- AND the page contains links to `https://external-site.com`
- WHEN qa-visual performs analysis
- THEN it MUST NOT call `navigate_page()` with any URL on a different origin than the target
- AND it MUST NOT follow redirects that lead to a different origin

#### Scenario: No destructive interactions

- GIVEN qa-visual is analyzing a page
- WHEN it encounters interactive elements (buttons, forms, links)
- THEN it MUST NOT click, submit, or interact with any element
- AND it MUST only observe and measure their visual properties (size, color, position, computed styles)

#### Scenario: Script injection limited to measurement only

- GIVEN qa-visual calls `evaluate_script()` during analysis
- THEN the script MUST only read values (computed styles, dimensions, font metrics, color values, animation properties)
- AND the script MUST NOT write to `document`, `window`, or any DOM element
- AND the script MUST NOT make network requests (no `fetch()`, `XMLHttpRequest`, or dynamic script loading)
- AND the script MUST NOT access `localStorage`, `sessionStorage`, or cookies

### Requirement: Depth Controls

The system MUST respect the detail level parameter to control analysis scope and output verbosity.

#### Scenario: Concise depth — desktop only, minimal output

- GIVEN the detail level is `concise`
- WHEN qa-visual executes the analysis pipeline
- THEN it MUST execute Steps 1 through 5 only (baseline, design system, typography, color/contrast, layout)
- AND all checks MUST be performed at desktop viewport (1440x900) only
- AND Steps 6 (responsive sweep), 7 (cross-viewport consistency), and 8 (animation audit) MUST be skipped
- AND the report MUST include only BLOCKER and WARNING findings
- AND limit element analysis to at most 3 elements per component type

#### Scenario: Standard depth — all breakpoints with element limits

- GIVEN the detail level is `standard`
- WHEN qa-visual executes the analysis pipeline
- THEN it MUST execute all 10 analysis steps
- AND limit analysis to at most 10 elements per component type at each step
- AND the report MUST include BLOCKER and WARNING findings with code suggestions

#### Scenario: Deep depth — full audit without limits

- GIVEN the detail level is `deep`
- WHEN qa-visual executes the analysis pipeline
- THEN it MUST execute all 10 analysis steps
- AND remove element-per-type limits, analyzing all visible elements
- AND MAY test additional viewports beyond the three standard breakpoints
- AND the report MUST include all findings (BLOCKER, WARNING, and INFO) with full code suggestions and references

### Requirement: Report Format

The system MUST produce a report following the QASE specialist report structure adapted for visual analysis.

#### Scenario: Complete visual report structure

- GIVEN qa-visual has completed its analysis
- THEN the report MUST follow this structure:
  - Title: "Visual Inspector Report"
  - Review ID, URL tested, viewports tested, philosophy quote
  - Findings grouped by severity: BLOCKERs, WARNINGs, INFOs (deep only)
  - Visual Health Summary table with categories: Design System Consistency, Typography, Color & Contrast, Layout Integrity, Responsive Design, Cross-Viewport Consistency, Animations
  - Each category with status (`CONSISTENT`/`ISSUES`/`CRITICAL` or `COMPLIANT`/`VIOLATIONS`/`CRITICAL`) and finding count
  - Metadata envelope at the end

#### Scenario: Empty report when no issues found

- GIVEN qa-visual completes analysis and finds zero issues
- THEN it MUST produce a report with:
  - `Verdict`: `CLEAN`
  - `Findings`: 0
  - `verdict_contribution`: `CLEAN`
  - A summary noting that no visual issues were found in the reviewed scope

### Requirement: Finding Categories

All findings produced by qa-visual MUST use exactly one of the defined finding categories.

#### Scenario: Each finding uses a valid category

- GIVEN qa-visual produces any finding
- THEN the `Category` field MUST be one of: `design-system`, `visual-regression`, `responsive`, `typography`, `layout`, `color`, `animation`
- AND MUST NOT use any category from other specialists (e.g., `console-errors`, `network`, `interaction`)

### Requirement: Overlap Boundary with qa-browser

The system MUST NOT duplicate the functional and interactive testing responsibilities of qa-browser.

#### Scenario: qa-visual does not test interactive behavior

- GIVEN qa-visual and qa-browser both analyze the same URL
- WHEN qa-visual performs its analysis
- THEN qa-visual MUST focus on visual properties: styles, spacing, alignment, color, contrast, typography, responsive layout appearance
- AND qa-visual MUST NOT test interactive behavior: clicking buttons, submitting forms, following links, testing keyboard navigation
- AND qa-visual MUST NOT inject axe-core (that is qa-browser Step 4)
- AND qa-visual MUST NOT measure Core Web Vitals (that is qa-browser Step 8)
- AND any contrast findings from qa-visual SHOULD reference WCAG 2.1 SC 1.4.3 using its own computed-style extraction, independent of qa-browser axe-core results
