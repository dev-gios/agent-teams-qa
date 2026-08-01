# Severity Contract (positive fixture)

## Severity Levels

Every finding MUST use one of: BLOCKER, WARNING, INFO.

requires explicit user acknowledgment before overriding a veto.

### Runtime Coverage Suffix

When `runtime_coverage == unverified` and base_verdict is not REJECT, append ` (STATIC ONLY)` to the verdict.
When `runtime_coverage != unverified` or base_verdict is REJECT, runtime_suffix is "" (empty string).
The literal `(STATIC ONLY)` is owned exclusively by this file. It MUST NOT be restated elsewhere.

## Other rules

Additional contract content goes here.
