# qa-browser SKILL.md (neg-unverified-as-clean fixture)
# C10b violation: refusal branch still returns bare CLEAN (should be UNVERIFIED under recommendation).

## Refusal Branch (when runtime unavailable)

If unable to connect to the browser, return:
verdict_contribution: CLEAN

Do NOT fabricate findings from static reading. This is a refusal, not a finding.

## Refusal Branch (when preflight cache missing)

verdict_contribution: CLEAN

Do NOT fabricate findings from static reading. This is a refusal, not a finding.

## Refusal Branch (when smoke test failed)

verdict_contribution: CLEAN

Do NOT fabricate findings from static reading. This is a refusal, not a finding.
