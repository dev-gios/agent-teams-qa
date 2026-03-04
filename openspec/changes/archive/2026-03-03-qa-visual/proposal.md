# Proposal: QA Visual Specialist

## Intent

QASE currently has two categories of specialists: static-analysis agents that review source code diffs (architect, security, advocate, inclusion, performance, test-strategy) and one runtime agent (qa-browser) that tests a live application for functional correctness. There is no specialist that answers "does the app LOOK correct?" -- visual regression, design system compliance, responsive design quality, and visual accessibility are completely unaddressed. Visual bugs are among the most common user-facing defects, yet they are invisible to both static analysis and functional runtime testing. qa-visual fills this gap as the second runtime specialist, complementing qa-browser with a visual-first perspective.

## Scope

### In Scope
- Create `skills/qa-visual/SKILL.md` -- the full specialist skill definition following the qa-browser pattern (solo runtime specialist, URL-based scope, Chrome DevTools MCP).
- Define five analysis steps: (1) visual baseline capture at multiple viewports, (2) design system compliance checks via computed style extraction, (3) responsive design validation across mobile/tablet/desktop breakpoints, (4) visual accessibility auditing (contrast ratios, text rendering, color combinations), and (5) cross-viewport visual consistency via screenshot evidence.
- Define the Browser Testing Variant of issue-format for qa-visual with categories: `design-system`, `visual-regression`, `responsive`, `typography`, `layout`, `color`, `animation`.
- Register qa-visual as an out-of-band specialist in the routing-rules (same pattern as qa-browser -- not activated by qa-scan, launched directly via `/qa-visual <url>`).
- Update the engram-convention artifact type table with `visual-report`.
- Update the openspec-convention file path table with `qaspec/reviews/{review-id}/visual.md`.
- Update CLAUDE.md QASE command table with `/qa-visual [url]`.

### Out of Scope
- Pixel-perfect image diffing (requires external tooling like Percy/Chromatic -- future integration point).
- Design token file parsing (reading Figma tokens, Style Dictionary files) -- the specialist inspects the rendered DOM, not design source files.
- Animation performance profiling (covered by qa-performance via performance traces).
- Automated Figma-to-DOM comparison (requires Figma API integration).
- CSS source-code analysis (covered by existing static-analysis specialists).

## Approach

Model qa-visual after the established qa-browser pattern:

1. **Solo runtime specialist**: Not part of the qa-scan routing pipeline. Launched directly via `/qa-visual <url>` with the same scope syntax (URL target, optional auth, detail level).

2. **Chrome DevTools MCP toolchain**: Uses the same MCP tools as qa-browser -- `take_screenshot()` for visual evidence, `resize_page()` for viewport testing, `evaluate_script()` for computed style extraction and design metric measurement, `take_snapshot()` for DOM/accessibility tree inspection, and `emulate()` for device-specific rendering.

3. **Analysis pipeline** (10 steps):
   - Step 1: Establish connection and capture visual baseline (desktop).
   - Step 2: Design system compliance -- extract computed styles (colors, fonts, spacing, border-radius, shadows) and check for consistency across similar components.
   - Step 3: Typography audit -- font loading, fallback rendering, text overflow, line height, and readability.
   - Step 4: Color and contrast audit -- extract color palette, check WCAG contrast ratios for all text-background combinations, verify color-only information conveyance.
   - Step 5: Layout integrity -- check for overlapping elements, broken grid alignment, unexpected whitespace, z-index stacking issues.
   - Step 6: Responsive viewport sweep -- resize to mobile (375x812), tablet (768x1024), and desktop (1440x900), capturing screenshots and checking layout at each breakpoint.
   - Step 7: Visual consistency cross-check -- compare structural patterns across viewports (navigation collapses, content reflows, images scale).
   - Step 8: Animation and transition audit -- detect CSS animations/transitions, check for `prefers-reduced-motion` support, verify no janky/broken animations.
   - Step 9: Apply dismissed patterns and filter findings.
   - Step 10: Produce report and persist.

4. **Integration points**: Uses the shared contracts (severity-contract, issue-format with Browser Testing Variant, persistence-contract, engram-convention). Feeds findings into qa-report consensus engine. Respects qa-feedback dismissed patterns.

5. **Safety model**: Identical to qa-browser -- read-only, no modifications, no external navigation, no destructive actions.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `skills/qa-visual/SKILL.md` | New | The complete specialist skill definition |
| `skills/_shared/qase/routing-rules.md` | Modified | Add qa-visual to out-of-band specialists table |
| `skills/_shared/qase/engram-convention.md` | Modified | Add `visual-report` artifact type |
| `skills/_shared/qase/openspec-convention.md` | Modified | Add `visual.md` file path for qa-visual |
| `skills/_shared/qase/issue-format.md` | Modified | Add Visual Testing Variant (adapted from Browser Testing Variant) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Chrome DevTools screenshot quality varies by environment | Medium | Document minimum viewport requirements; use PNG format; note environment in report metadata |
| Design system compliance checks produce false positives on intentional style variations | Medium | Use component grouping heuristic (same tag + similar class patterns); provide `--design-tokens` optional input for explicit token definitions |
| Contrast ratio calculations differ from axe-core results in qa-browser | Low | qa-visual uses WCAG 2.1 algorithm directly via `evaluate_script()`; document overlap with qa-browser a11y and let qa-report deduplicate |
| Responsive checks overlap with qa-browser Step 7 (responsive audit) | Medium | qa-browser checks functional accessibility at viewports (overflow, touch targets); qa-visual checks visual quality (spacing, alignment, typography). Document the boundary clearly in both skills. |
| Large pages with many components slow down the analysis | Low | Apply depth controls (concise/standard/deep) with element limits matching qa-browser pattern |

## Rollback Plan

1. Delete `skills/qa-visual/SKILL.md` (single new file).
2. Revert modifications to shared contracts using `git checkout -- skills/_shared/qase/routing-rules.md skills/_shared/qase/engram-convention.md skills/_shared/qase/openspec-convention.md skills/_shared/qase/issue-format.md`.
3. Revert CLAUDE.md command table entry.
4. No database migrations, no infrastructure changes, no script modifications -- rollback is a clean file revert.

## Dependencies

- Chrome DevTools MCP server must be available in the session (same requirement as qa-browser).
- Shared QASE contracts must be at their current version (severity-contract, issue-format, persistence-contract, engram-convention, openspec-convention, routing-rules).
- qa-browser SKILL.md serves as the reference implementation for the solo runtime specialist pattern.

## Success Criteria

- [ ] `skills/qa-visual/SKILL.md` exists and passes `scripts/lint_skills.sh`.
- [ ] qa-visual follows the same structural pattern as qa-browser (frontmatter, purpose, input contract, step-by-step execution, depth controls, safety rules, report format, persistence).
- [ ] Finding categories are distinct from qa-browser: `design-system`, `visual-regression`, `responsive`, `typography`, `layout`, `color`, `animation`.
- [ ] Shared contracts updated: routing-rules (out-of-band table), engram-convention (artifact type), openspec-convention (file path), issue-format (Visual Testing Variant).
- [ ] Overlap with qa-browser is clearly documented -- qa-browser owns functional/interactive testing at viewports, qa-visual owns visual quality testing at viewports.
- [ ] Solo command `/qa-visual <url>` is registered in orchestrator command table.
- [ ] Final QASE review of the changes returns an `APPROVE` verdict.
