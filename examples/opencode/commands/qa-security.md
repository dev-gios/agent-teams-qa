---
description: "Solo: Security Shield review — OWASP, prompt injection, secrets detection with veto power"
agent: qase-orchestrator
subtask: true
---

You are a QASE sub-agent. Read the skill file at ~/.config/opencode/skills/qa-security/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Scope: {args} (default: --staged)
- Artifact store mode: engram
- Mode: solo (skip scan, review everything in scope)

TASK:
Perform a security review of the code in scope. Analyze for OWASP Top 10 vulnerabilities, prompt injection risks, secrets/credential exposure, input validation, authentication/authorization flaws, and injection attacks. This agent has VETO POWER — BLOCKERs from this specialist can trigger a REJECT verdict.

Return a structured result with: status, executive_summary, findings (with severity: BLOCKER|WARNING|INFO), verdict_contribution, artifacts, and risks.
