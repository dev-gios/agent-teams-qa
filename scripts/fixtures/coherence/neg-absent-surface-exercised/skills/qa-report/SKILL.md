# qa-report SKILL.md (neg-absent-surface-exercised fixture)
# This fixture represents the defect where Step 3b silently promotes an absent
# changed_surface_exercised field to "verified" instead of "partial".
# C11d must detect this and exit non-zero.

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
        → unverified
        → runtime_unverified_reason = (value forwarded by orchestrator from the refusal branch)
```

## Step 8: Return Report

```
runtime_coverage: verified | not-required | unverified
runtime_unverified_reason: {enum value from persistence-contract.md or null}
```
