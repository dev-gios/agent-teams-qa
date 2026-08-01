# Severity Contract (shared across all QASE skills)

## Severity Levels

Every finding produced by a QASE specialist MUST use exactly one of these severity levels:

| Severity | Meaning | Verdict Impact | Display |
|----------|---------|----------------|---------|
| `BLOCKER` | Must fix before merge | Forces **REJECT** | Always shown |
| `WARNING` | Should fix, risk accepted if not | Contributes to **APPROVE WITH WARNINGS** | Always shown |
| `INFO` | Suggestion, no verdict impact | None | Only shown in `--deep` mode |

## Oracle Tier and Verdict

Tier definitions and the blocking matrix are owned by `oracle-contract.md`. Apply them; do not restate them.

## Veto Power

**Three** specialists have **veto power** — one of them conditionally:

| Agent | Veto Scope |
|-------|-----------|
| `qa-security` | Any BLOCKER finding automatically forces REJECT and requires explicit user acknowledgment before it can be overridden |
| `qa-architect` | Any BLOCKER finding automatically forces REJECT and requires explicit user acknowledgment before it can be overridden |
| `qa-browser` | BLOCKERs carrying Oracle Tier L1, L2, or L3-schema only. Findings at L3-inferred or L4 NEVER carry veto and NEVER produce BLOCKER under the qa-browser veto rule. |

Non-veto agents (`qa-advocate`, `qa-inclusion`, `qa-performance`, `qa-test-strategy`) can produce BLOCKERs, but these can be overridden by the consensus engine without explicit acknowledgment. `qa-browser` findings outside the tier gate (L3-inferred and L4) are also non-veto.

**`qa-visual` BLOCKER carve-out**: `qa-visual` is permanently excluded from BLOCKER production regardless of the general non-veto permission above. All `qa-visual` findings are capped at WARNING by the L4 severity ceiling (see Oracle Tier table above). A BLOCKER arriving from `qa-visual` at Gate 1 is a tier-gate violation and MUST be downgraded to WARNING.

**Summary**: a veto-bearing BLOCKER will force a REJECT verdict and requires explicit user acknowledgment. Veto-bearer list and predicate are defined in the veto table above; do not restate them in specialist SKILL.md files — cite this file instead.

## Verdict Logic (used by qa-report)

```
FOR EACH finding:
  # Gate 1 — severity ceiling by tier (authoring-time rule, re-enforced here as defense in depth)
  # Gate 1 applies ONLY to runtime specialists: qa-browser and qa-visual.
  # Static specialists (qa-security, qa-architect, qa-advocate, qa-inclusion,
  # qa-performance, qa-test-strategy) carry NO Oracle Tier and MUST NOT have one
  # inferred. Gate 1 is a NO-OP for static specialist findings — do not apply tier
  # caps, do not infer an Oracle Tier, do not treat their findings as UNGROUNDED.
  IF finding.agent IN {qa-browser, qa-visual}:
    IF finding.oracle_tier IS MISSING        → treat as UNGROUNDED, cap severity at INFO
    IF finding.oracle_tier == L4             → cap severity at WARNING
    IF finding.oracle_tier == L3-inferred    → cap severity at WARNING
    IF finding.oracle_tier == L3-schema AND citation missing
                                             → downgrade to L3-inferred, cap severity at WARNING
    # A BLOCKER arriving at a capped tier is DOWNGRADED, not honoured.
    # Record tier-gate-violation in the report.
  # ELSE (static specialist): no tier ceiling — severity is as authored.

  # Gate 2 — veto-bearing predicate (per finding, not per agent)
  veto_bearing = finding.severity == BLOCKER AND (
        finding.agent IN {qa-security, qa-architect}
     OR (finding.agent == qa-browser AND finding.oracle_tier IN {L1, L2, L3-schema})
  )

VERDICT:
  IF any BLOCKER exists from ANY agent:
    → REJECT
    IF any finding has veto_bearing == true:
      → REJECT (VETO) — requires explicit user acknowledgment
    ELSE:
      → REJECT — standard, can be overridden by consensus

  ELSE IF any WARNING exists:
    → APPROVE WITH WARNINGS

  ELSE:
    → APPROVE
```

## Severity Assignment Guidelines

### BLOCKER — Use when:
- Security vulnerability (injection, auth bypass, data exposure)
- SOLID violation that will cause cascading maintenance problems
- Race condition or data corruption risk
- Missing input validation on external boundaries
- Accessibility barrier that prevents use by entire user groups (e.g., no keyboard nav)

### WARNING — Use when:
- Code smell that increases future maintenance cost
- Performance concern in non-critical path
- Missing error handling for recoverable scenarios
- Partial accessibility compliance
- Test coverage gap for important behavior

### INFO — Use when:
- Style preference or alternative approach suggestion
- Minor optimization opportunity
- Documentation suggestion
- Naming improvement
- Pattern that works but could be more idiomatic

### Runtime findings

Runtime findings (from `qa-browser` and `qa-visual`) carry an Oracle Tier that determines their maximum severity. Tier definitions and the blocking matrix are owned by `oracle-contract.md`. Apply them; do not restate them.

## Rules

- NEVER inflate severity to get attention — be honest about impact
- NEVER downplay severity to be nice — protect the codebase
- When in doubt between two levels, choose the HIGHER one and explain why
  (does NOT apply to runtime findings from `qa-browser` or `qa-visual` — the Oracle Tier ceiling
  is absolute; the resolution algorithm in `oracle-contract.md` determines the tier, and the tier
  determines the severity cap. Choosing a higher severity than the tier permits is a tier-gate
  violation, not a judgment call.)
- Each finding MUST include a justification for its severity level
- Duplicate findings across agents are expected — qa-report handles deduplication
