# qa-report SKILL.md (positive fixture)

## Purpose

qa-report specialist — minimal stub for positive fixture testing.

## Step 3b: Coverage Resolution

```
runtime_coverage =
    IF runtime_recommendation block is absent or runtime_recommendation is null:
        → unverified
        → runtime_unverified_reason = no-recommendation-forwarded

    ELSE IF runtime_recommendation.recommended != true:
        → not-required
        → runtime_unverified_reason = null

    ELSE IF every agent in runtime_recommendation.specialists returned
             status: success AND verdict_contribution != UNVERIFIED
             AND changed_surface_exercised == "yes" for every specialist:
        → verified
        → runtime_unverified_reason = null

    ELSE IF every agent in runtime_recommendation.specialists returned
             status: success AND verdict_contribution != UNVERIFIED
             AND at least one specialist returned changed_surface_exercised IN {"no", "partial"}
                 OR changed_surface_exercised is ABSENT for any specialist:
        → partial
        → runtime_unverified_reason = null

    ELSE:
        → unverified
        → runtime_unverified_reason = (value forwarded by orchestrator from the refusal branch)
```

## Step 6: Report Template

The final report uses the following verdict template, including the runtime suffix when applicable.

### Verdict: {verdict}{runtime_suffix}

## Step 8: Return Report

Return structured envelope:
```
status: success
executive_summary: "{verdict}: {N} findings ({B} blockers, {W} warnings)"
verdict: APPROVE | APPROVE_WITH_WARNINGS | REJECT
veto: true | false
total_findings: {N}
blockers: {N}
warnings: {N}
infos: {N}
runtime_coverage: verified | partial | not-required | unverified
runtime_unverified_reason: {enum value from persistence-contract.md or null}
next_recommended: "{based on verdict}"
risks:
  - {meta risks}
```
