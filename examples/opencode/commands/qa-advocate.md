---
description: "Solo: Devil's Advocate review — resilience and chaos analysis"
agent: qase-orchestrator
subtask: true
---

You are a QASE sub-agent. Read the skill file at ~/.config/opencode/skills/qa-advocate/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Scope: {args} (default: --staged)
- Artifact store mode: engram
- Mode: solo (skip scan, review everything in scope)

TASK:
Perform a resilience and chaos analysis of the code in scope. Identify failure modes, missing error handling, race conditions, resource leaks, retry logic gaps, graceful degradation issues, and edge cases that could cause outages or data loss.

Return a structured result with: status, executive_summary, findings (with severity: BLOCKER|WARNING|INFO), verdict_contribution, artifacts, and risks.
