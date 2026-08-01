# qa-browser SKILL.md (positive fixture)

## Purpose

qa-browser specialist — minimal stub for positive fixture testing.

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
