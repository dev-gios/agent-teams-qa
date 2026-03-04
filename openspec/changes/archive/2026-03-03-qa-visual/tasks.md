# Tasks: QA Visual Specialist

## Phase 1: Infrastructure (Shared Contract Updates)

- [x] 1.1 Add `qa-visual` row to the Out-of-Band Specialists table in `skills/_shared/qase/routing-rules.md`
  - Add row: `| qa-visual | /qa-visual <url> | Visual regression and design system compliance testing via Chrome DevTools, not source code diffs |`
  - Location: under the existing `qa-browser` row in the "Out-of-Band Specialists" table

- [x] 1.2 Add `visual-report` to the Artifact Types table in `skills/_shared/qase/engram-convention.md`
  - Add row: `| visual-report | qa-visual | Visual regression and design system compliance findings |`
  - Location: after the `browser-report` row in the "Artifact Types (exact strings)" table

- [x] 1.3 Add `visual.md` file path to `skills/_shared/qase/openspec-convention.md`
  - Add row to Artifact File Paths table: `| qa-visual | Creates | qaspec/reviews/{review-id}/visual.md |`
  - Add `│       ├── visual.md       <- from qa-visual` to the directory structure diagram (after `browser.md`)

- [x] 1.4 Add Visual Testing Variant section to `skills/_shared/qase/issue-format.md`
  - Add a new "## Visual Testing Variant" section after the existing "## Browser Testing Variant" section
  - Template fields: Agent (`qa-visual`), URL, Element, Viewport (`{widthxheight}`), Category (`design-system | visual-regression | responsive | typography | layout | color | animation`)
  - Include What Failed, Why It Matters, Senior Suggestion, Evidence, References subsections
  - Document key differences from Browser Testing Variant: added Viewport field, visual-specific categories, emphasis on computed style evidence

## Phase 2: Core Implementation (SKILL.md)

- [x] 2.1 Create directory `skills/qa-visual/` and create `skills/qa-visual/SKILL.md` with YAML frontmatter
  - Frontmatter: `name: qa-visual`, `description: Visual Inspector`, `metadata.framework: QASE`, `metadata.veto_power: false`, `metadata.author: dev-gios`, `metadata.version: "1.0"`
  - Add Purpose section: "You are the Visual Inspector" role definition

- [x] 2.2 Write "What You Receive" and "Execution and Persistence Contract" sections in `skills/qa-visual/SKILL.md`
  - Input contract: Review ID, URL, optional auth, depth level, dismissed patterns, artifact store mode
  - Persistence references: `persistence-contract.md`, `severity-contract.md`, `issue-format.md` (Visual Testing Variant)
  - Engram artifact type: `visual-report`; OpenSpec path: `qaspec/reviews/{review-id}/visual.md`

- [x] 2.3 Write Step 1 (Establish Connection + Visual Baseline) in `skills/qa-visual/SKILL.md`
  - MCP calls: `navigate_page(url)`, `wait_for("load")`, `take_screenshot()`, `take_snapshot()`
  - Error handling: unreachable URL produces BLOCKER and halts; Chrome DevTools MCP unavailable produces BLOCKER and halts; partial load produces WARNING and continues
  - Record baseline screenshot as desktop viewport evidence (1440x900)

- [x] 2.4 Write Step 2 (Design System Compliance) in `skills/qa-visual/SKILL.md`
  - `evaluate_script()` to extract computed styles (color, font-family, font-size, font-weight, padding, margin, border-radius, box-shadow, background-color)
  - Component grouping heuristic: group by `(tagName, role, classPrefix)`
  - Compare computed styles within each group; flag divergences as `design-system` findings
  - Depth limits: concise=buttons/headings/links/inputs (max 10/type), standard=all groups (max 10/type), deep=all groups (no limit)

- [x] 2.5 Write Step 3 (Typography Audit) in `skills/qa-visual/SKILL.md`
  - `evaluate_script()` to check `document.fonts.check()` for font loading
  - Detect text overflow: `scrollWidth > clientWidth` or `scrollHeight > clientHeight` without overflow handling
  - Check line-height < 1.5 for body text (WCAG 2.1 SC 1.4.12 reference)
  - Finding category: `typography`

- [x] 2.6 Write Step 4 (Color and Contrast Audit) in `skills/qa-visual/SKILL.md`
  - `evaluate_script()` to implement WCAG 2.1 relative luminance algorithm (~30 lines inline JS)
  - Extract foreground/background color pairs, compute contrast ratios
  - BLOCKER for normal text below 4.5:1, large text threshold 3:1 per WCAG 2.1 SC 1.4.3
  - Detect color-only information conveyance (WARNING, WCAG 2.1 SC 1.4.1)
  - Extract full color palette with usage counts; depth limits on pair count (concise=20, standard=50, deep=all)

- [x] 2.7 Write Step 5 (Layout Integrity) in `skills/qa-visual/SKILL.md`
  - `evaluate_script()` to compute bounding rectangles via `getBoundingClientRect()`
  - Detect overlapping positioned elements (WARNING, category `layout`)
  - Detect large whitespace gaps >200px (INFO, category `layout`)
  - Check z-index stacking issues

- [x] 2.8 Write Step 6 (Responsive Viewport Sweep) in `skills/qa-visual/SKILL.md`
  - Breakpoints: mobile (375x812), tablet (768x1024), desktop (1440x900); deep adds 320x568 and 1920x1080
  - Per breakpoint: `resize_page()`, `wait_for("load")`, `take_screenshot()`, `evaluate_script()` for overflow/visibility
  - Mobile-first sweep order
  - Concise depth: skip Steps 6-8 entirely; note in report metadata
  - Reset to 1440x900 after completing

- [x] 2.9 Write Step 7 (Cross-Viewport Visual Consistency) in `skills/qa-visual/SKILL.md`
  - Compare structural patterns across viewport captures
  - Verify navigation presence/collapse across viewports
  - Detect content disappearing at intermediate viewports (WARNING, category `visual-regression`)
  - Uses data from Step 6 viewport screenshots and DOM snapshots

- [x] 2.10 Write Step 8 (Animation and Transition Audit) in `skills/qa-visual/SKILL.md`
  - `evaluate_script()` to detect non-`none` `animation-name` or non-zero `transition-duration`
  - Check for `prefers-reduced-motion` media queries in loaded stylesheets
  - WARNING if animations present without `prefers-reduced-motion` support (WCAG 2.1 SC 2.3.3)
  - Deep mode: `emulate()` to test `prefers-reduced-motion: reduce`
  - Skip if no animations detected; record "No animations detected"

- [x] 2.11 Write Step 9 (Apply Dismissed Patterns) in `skills/qa-visual/SKILL.md`
  - Load dismissed patterns from Engram: `mem_search(query: "qase/{project}/feedback/qa-visual/", project: "{project}")`
  - For each result: `mem_get_observation(id)` to retrieve full pattern
  - PROJECT_RULE and FALSE_POSITIVE: suppress matching findings
  - ONE_TIME: include but mark as "Previously dismissed (ONE_TIME) -- re-evaluate"
  - No patterns: include all findings without suppression

- [x] 2.12 Write Step 10 (Produce Report + Persist) in `skills/qa-visual/SKILL.md`
  - Report format: Visual Inspector Report with Visual Health Summary table (7 categories)
  - Color Palette Extracted table and Contrast Audit Summary table
  - Metadata envelope with agent, review-id, url-tested, viewports-tested, findings-count, blockers, warnings, infos, verdict-contribution
  - Persistence: engram with topic_key `qase/{review-id}/visual-report`; openspec to `qaspec/reviews/{review-id}/visual.md`; none returns inline

- [x] 2.13 Write Depth Controls table in `skills/qa-visual/SKILL.md`
  - concise: Steps 1-5 only, desktop only, max 5 component groups, max 3 elements/group, max 20 contrast pairs, BLOCKER+WARNING only
  - standard: all 10 steps, 3 breakpoints, max 10 groups, max 10 elements/group, max 50 contrast pairs
  - deep: all 10 steps, 5 breakpoints, all groups, no element limits, all contrast pairs, include INFOs

- [x] 2.14 Write Safety Rules and Rules sections in `skills/qa-visual/SKILL.md`
  - Read-only operation: no DOM modifications, no click/fill/fill_form/type_text
  - Allowed MCP tools: navigate_page (target URL only), take_screenshot, take_snapshot, evaluate_script (read-only), resize_page, emulate, list_console_messages, list_network_requests
  - No external navigation (same-origin only)
  - evaluate_script MUST NOT write to document/window/DOM, make network requests, or access storage
  - Behavioral guidelines matching qa-browser pattern
  - Return structured envelope with status, executive_summary, artifacts, verdict_contribution, risks

## Phase 3: Integration (Orchestrator + qa-report)

- [x] 3.1 Update QASE Commands table in `~/.claude/CLAUDE.md` to add `/qa-visual [url]` command
  - Add row: `| /qa-visual [url] | Solo: Visual regression and design system compliance testing |`
  - Add to Command -> Skill Mapping table: `| /qa-visual [url] | qa-visual (solo, skip scan) |`

- [x] 3.2 Update Available Skills list in `~/.claude/CLAUDE.md` QASE section
  - Add: `- qa-visual/SKILL.md -- Visual regression + design system compliance`

- [x] 3.3 Update Solo Commands pipeline description in `~/.claude/CLAUDE.md` to reference qa-visual
  - Ensure the "Pipeline: Solo Commands" section explicitly lists qa-visual alongside qa-architect, qa-security, etc.

## Phase 4: Testing & Validation

- [x] 4.1 Run `bash scripts/lint_skills.sh` and verify `skills/qa-visual/SKILL.md` passes all lint checks
  - Expected: valid YAML frontmatter, required sections present, no lint errors
  - Result: 108 PASS, 0 FAIL, 0 WARN — ALL PASSED (qa-visual: frontmatter, name, description, license, Purpose, Execution and Persistence Contract, What to Do, Rules, persistence-contract.md reference)

- [x] 4.2 Verify all shared contract references in `skills/qa-visual/SKILL.md` resolve correctly
  - Check that `skills/_shared/qase/persistence-contract.md` is referenced
  - Check that `skills/_shared/qase/severity-contract.md` is referenced
  - Check that `skills/_shared/qase/issue-format.md` is referenced with "Visual Testing Variant"
  - Check that `skills/_shared/qase/engram-convention.md` is referenced with artifact type `visual-report`
  - Result: All 5 references verified (persistence-contract, severity-contract, issue-format w/ Visual Testing Variant, engram-convention w/ visual-report, openspec-convention w/ visual.md path)

- [x] 4.3 Verify routing-rules.md update: `qa-visual` appears in Out-of-Band Specialists table with correct format
  - Confirm qa-visual is NOT in the routing matrix (it is out-of-band only)
  - Confirm the entry follows the same pattern as qa-browser
  - Result: qa-visual at line 101 in Out-of-Band table, NOT in routing matrix, format consistent with qa-browser at line 100

- [x] 4.4 Verify engram-convention.md update: `visual-report` appears in Artifact Types table
  - Confirm the row format matches existing entries (artifact type, produced by, description)
  - Result: visual-report at line 49, format matches browser-report at line 48 (artifact-type | produced-by | description)

- [x] 4.5 Verify openspec-convention.md update: `visual.md` appears in both directory tree and file paths table
  - Confirm the directory tree shows `visual.md` after `browser.md`
  - Confirm the Artifact File Paths table has a qa-visual row
  - Result: Directory tree line 19 (after browser.md at line 18), File Paths table line 40 (after qa-browser at line 39)

- [x] 4.6 Verify issue-format.md update: Visual Testing Variant section is complete and well-formed
  - Confirm all fields are documented (Agent, URL, Element, Viewport, Category)
  - Confirm the 7 categories match spec: design-system, visual-regression, responsive, typography, layout, color, animation
  - Confirm key differences from Browser Testing Variant are documented
  - Result: All 5 fields present, all 7 categories listed at line 94, 3 key differences documented (Viewport added, visual-specific categories, evidence emphasis on computed styles)

- [ ] 4.7 Manual test: invoke `/qa-visual <url>` at `concise` depth and verify Steps 1-5 execute, Steps 6-8 are skipped — deferred (requires live URL)
  - Verify only BLOCKER and WARNING findings appear in the report
  - Verify desktop viewport (1440x900) only is used

- [ ] 4.8 Manual test: invoke `/qa-visual <url>` at `standard` depth and verify all 10 steps execute — deferred (requires live URL)
  - Verify responsive sweep at 3 breakpoints (375x812, 768x1024, 1440x900)
  - Verify element limits are respected (max 10 per component type)

- [ ] 4.9 Manual test: invoke `/qa-visual <url>` at `deep` depth and verify full audit without limits — deferred (requires live URL)
  - Verify 5 breakpoints tested (including 320x568 and 1920x1080)
  - Verify INFO findings are included in the report

- [ ] 4.10 Manual test: invoke `/qa-visual` against an unreachable URL and verify BLOCKER + immediate halt — deferred (requires live URL)
  - Verify report contains single BLOCKER: "Application unreachable at {url}"
  - Verify verdict_contribution is `HAS_BLOCKERS`
