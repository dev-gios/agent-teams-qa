# Severity Contract (shared across all QASE skills)

## Severity Levels

Every finding produced by a QASE specialist MUST use exactly one of these severity levels:

| Severity | Meaning | Verdict Impact | Display |
|----------|---------|----------------|---------|
| `BLOCKER` | Must fix before merge | Forces **REJECT** | Always shown |
| `WARNING` | Should fix, risk accepted if not | Contributes to **APPROVE WITH WARNINGS** | Always shown |
| `INFO` | Suggestion, no verdict impact | None | Only shown in `--deep` mode |

## Veto Power

Two specialists have **veto power** — their BLOCKERs carry extra weight:

| Agent | Veto Scope |
|-------|-----------|
| `qa-security` | Any BLOCKER finding automatically forces REJECT and requires explicit user acknowledgment before it can be overridden |
| `qa-architect` | Any BLOCKER finding automatically forces REJECT and requires explicit user acknowledgment before it can be overridden |

Non-veto agents (advocate, inclusion, performance, test-strategy) can produce BLOCKERs, but these can be overridden by the consensus engine without explicit acknowledgment.

## Verdict Logic (used by qa-report)

```
IF any BLOCKER exists from ANY agent:
  → REJECT
  IF BLOCKER is from veto agent (security, architect):
    → REJECT (requires explicit acknowledgment to override)
  ELSE:
    → REJECT (can be overridden by consensus if other agents found no issues)

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

## Rules

- NEVER inflate severity to get attention — be honest about impact
- NEVER downplay severity to be nice — protect the codebase
- When in doubt between two levels, choose the HIGHER one and explain why
- Each finding MUST include a justification for its severity level
- Duplicate findings across agents are expected — qa-report handles deduplication
