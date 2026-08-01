# qa-report SKILL.md (neg-step3b-else-verified fixture)
# This fixture represents the semantic core defect: Step 3b ELSE resolves to "verified"
# instead of "unverified". C11a must detect this and exit non-zero.

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
             status: success AND verdict_contribution != UNVERIFIED:
        → verified
        → runtime_unverified_reason = null

    ELSE:
        → verified
        → runtime_unverified_reason = null
```

## Step 8: Return Report

```
runtime_coverage: verified | not-required | unverified
runtime_unverified_reason: {enum value from persistence-contract.md or null}
```
