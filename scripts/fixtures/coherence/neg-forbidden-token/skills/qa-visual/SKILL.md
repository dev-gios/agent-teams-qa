# qa-visual SKILL.md (neg-forbidden-token fixture)

## Purpose

Visual regression and design system compliance review.

## Notes on verdict

verdict-contribution: {CLEAN | HAS_WARNINGS}  (never HAS_BLOCKERS)

// HAS_BLOCKERS is intentionally absent — qa-visual MUST NOT produce BLOCKERs.

## BUG INJECTED FOR FIXTURE

This specialist MUST return HAS_BLOCKERS when a critical design violation is found.

This line contains an unguarded HAS_BLOCKERS that should be caught by C1.
