# qa-visual SKILL.md (positive fixture)

## Purpose

Visual regression and design system compliance review.

## Notes on verdict

verdict-contribution: {CLEAN | HAS_WARNINGS}  (never HAS_BLOCKERS)

// HAS_BLOCKERS is intentionally absent — qa-visual MUST NOT produce BLOCKERs.

This specialist may emit CLEAN or HAS_WARNINGS only.

## Refusal Branch (when runtime unavailable)

If unable to connect to the browser, return:
verdict_contribution: UNVERIFIED (if launched_under_recommendation: true) | CLEAN (otherwise)

Do NOT fabricate findings from static reading. This is a refusal, not a finding.

## Refusal Branch (when preflight cache missing)

verdict_contribution: UNVERIFIED (if launched_under_recommendation: true) | CLEAN (otherwise)

Do NOT fabricate findings from static reading. This is a refusal, not a finding.

## Refusal Branch (when smoke test failed)

verdict_contribution: UNVERIFIED (if launched_under_recommendation: true) | CLEAN (otherwise)

Do NOT fabricate findings from static reading. This is a refusal, not a finding.
