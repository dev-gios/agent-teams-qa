# Runtime Veto Specification

## Purpose

Define the tier-gated veto mechanism for `qa-browser`, its synchronization invariant with `severity-contract.md`, and the behavior of `qa-report`'s consensus engine when a third veto holder is present. This spec covers Decision A from the proposal and resolves Risk R11 explicitly.

---

## Requirement: qa-browser Frontmatter and Veto Power

After this change is applied, `qa-browser` MUST carry veto power. The frontmatter and the severity contract veto table MUST agree and MUST be updated in the same change.

### Scenario: qa-browser SKILL.md frontmatter declares veto_power: true

- GIVEN the `skills/qa-browser/SKILL.md` file after this change is applied
- WHEN the YAML frontmatter is inspected
- THEN the field `veto_power` MUST be `true`
- AND `rg -n "veto_power: true" skills/` MUST return exactly three matches: `qa-security`, `qa-architect`, and `qa-browser`
- AND any count other than three MUST be treated as a failing verification

### Scenario: severity-contract.md veto table contains a row for qa-browser

- GIVEN the `skills/_shared/qase/severity-contract.md` file after this change is applied
- WHEN the veto table is inspected
- THEN it MUST contain a row for `qa-browser`
- AND that row's `Veto Scope` column MUST state in substance: "BLOCKERs carrying Oracle Tier L1, L2, or L3-schema only"
- AND the row MUST explicitly state that findings at `L3-inferred` or `L4` NEVER carry veto and NEVER produce BLOCKER under the qa-browser veto rule

### Scenario: Frontmatter and veto table are always in sync — invariant

- GIVEN the specification invariant that frontmatter and veto table must agree
- WHEN `sdd-verify` checks this invariant
- THEN it MUST verify that `veto_power: true` in `skills/qa-browser/SKILL.md` is paired with a qa-browser row in `severity-contract.md`'s veto table
- AND it MUST verify the inverse: if `veto_power: true` is absent, the row MUST also be absent
- AND a mismatch in either direction MUST be reported as CRITICAL

---

## Requirement: Which Tiers May Block via qa-browser Veto

The tier gate is the mechanism that prevents flaky selectors and heuristic failures from triggering a veto.

### Scenario: L1 finding from qa-browser triggers veto and forces REJECT

- GIVEN `qa-browser` produces a BLOCKER finding at Oracle Tier `L1`
- WHEN `qa-report` applies veto logic (Step 3)
- THEN the verdict MUST be `REJECT`
- AND the `REJECT` MUST require explicit user acknowledgment to override
- AND the qa-report final report MUST note that the REJECT originates from a qa-browser veto at L1

### Scenario: L2 finding from qa-browser triggers veto and forces REJECT

- GIVEN `qa-browser` produces a BLOCKER finding at Oracle Tier `L2`
- WHEN `qa-report` applies veto logic
- THEN the verdict MUST be `REJECT`
- AND explicit user acknowledgment MUST be required to override

### Scenario: L3-schema finding from qa-browser triggers veto and forces REJECT

- GIVEN `qa-browser` produces a BLOCKER finding at Oracle Tier `L3-schema`
- AND the finding includes the mandatory file/line/literal citation
- WHEN `qa-report` applies veto logic
- THEN the verdict MUST be `REJECT`
- AND explicit user acknowledgment MUST be required to override

### Scenario: L3-inferred finding from qa-browser DOES NOT trigger veto

- GIVEN `qa-browser` produces a finding at Oracle Tier `L3-inferred`
- WHEN `qa-report` evaluates the finding
- THEN the finding's maximum severity MUST be WARNING (capped by oracle-contract.md)
- AND the finding MUST NOT carry veto weight
- AND the finding MUST NOT force a REJECT verdict
- AND the verdict MUST be at most `APPROVE WITH WARNINGS`

### Scenario: L4 finding from qa-browser DOES NOT trigger veto

- GIVEN `qa-browser` produces a finding at Oracle Tier `L4`
- WHEN `qa-report` evaluates the finding
- THEN the finding's maximum severity MUST be WARNING (advisory only per oracle-contract.md)
- AND the finding MUST NOT carry veto weight
- AND the finding MUST NOT force a REJECT verdict

---

## Requirement: qa-report Consensus Behavior with Three Veto Holders (Resolution of Risk R11)

The current `qa-report` Step 3 "Apply Veto Logic" was designed for exactly two veto holders (`qa-security`, `qa-architect`). Adding `qa-browser` as a third veto holder MUST NOT produce unexpected verdict behavior. This requirement resolves R11 explicitly.

### Scenario: qa-report applies veto logic independently per veto holder

- GIVEN three veto holders: `qa-security`, `qa-architect`, and `qa-browser`
- WHEN `qa-report` Step 3 applies veto logic
- THEN each veto holder's BLOCKERs MUST be evaluated independently
- AND the presence of a veto-eligible BLOCKER from ANY single veto holder MUST be sufficient to force `REJECT`
- AND `qa-report` MUST NOT require agreement between veto holders before issuing a REJECT (each holder's veto is independent)
- AND the final report MUST identify WHICH veto holder(s) triggered the REJECT

### Scenario: Consensus of non-veto agents CANNOT override a qa-browser veto

- GIVEN `qa-browser` produces a BLOCKER at L1, L2, or L3-schema
- AND all other non-veto specialists (`qa-advocate`, `qa-inclusion`, `qa-performance`, `qa-test-strategy`) produce clean results
- WHEN `qa-report` calculates the verdict
- THEN the verdict MUST still be `REJECT`
- AND the non-veto consensus MUST NOT override the qa-browser veto
- AND the report MUST note: "qa-browser veto active (Oracle Tier {tier}) — consensus override not permitted"

### Scenario: qa-browser veto and qa-security veto are both active

- GIVEN `qa-browser` produces a BLOCKER at L1 AND `qa-security` produces any BLOCKER
- WHEN `qa-report` calculates the verdict
- THEN the verdict MUST be `REJECT`
- AND the report MUST list both veto holders in the rejection summary
- AND both acknowledgments MUST be required before the verdict can be overridden

### Scenario: qa-browser BLOCKER at L3-inferred or L4 DOES NOT affect qa-report consensus

- GIVEN `qa-browser` produces findings only at `L3-inferred` or `L4`
- AND those findings would be WARNINGs at most
- AND all veto-holding static agents (`qa-security`, `qa-architect`) produce clean results
- WHEN `qa-report` calculates the verdict
- THEN the verdict MUST be `APPROVE WITH WARNINGS` (not `REJECT`)
- AND the qa-browser findings MUST be included in the warning summary

### Scenario: qa-report specialist summary table includes qa-browser as a veto holder

- GIVEN `qa-report` produces its final verdict report after this change is applied
- WHEN the specialist summary table is inspected
- THEN `qa-browser` MUST appear in the table
- AND the `Veto` column for `qa-browser` MUST indicate `yes (tier-gated: L1/L2/L3-schema)`
- AND `qa-visual` MUST remain `no` in the `Veto` column

---

## Requirement: qa-visual Remains Non-Veto

### Scenario: qa-visual veto_power remains false after this change

- GIVEN the `skills/qa-visual/SKILL.md` file after this change is applied
- WHEN the YAML frontmatter is inspected
- THEN the field `veto_power` MUST be `false`
- AND `qa-visual` MUST NOT appear in the severity-contract.md veto table as a veto holder

---

## Requirement: Partial Rollback Preserves Stability

### Scenario: Reverting veto_power to false restores pre-change behavior

- GIVEN that `veto_power: true` is reverted to `veto_power: false` in `skills/qa-browser/SKILL.md`
- AND the qa-browser row is removed from the severity-contract.md veto table in the same operation
- WHEN `qa-report` processes a review
- THEN the verdict logic MUST revert to the pre-change two-veto-holder model
- AND flow evidence and oracle tiers MUST continue to function without requiring veto power
- AND the rollback MUST be verifiable by `rg -n "veto_power: true" skills/` returning exactly two matches
