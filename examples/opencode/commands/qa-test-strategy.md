---
description: "Solo: Test Strategist review — coverage, quality, and testing patterns analysis"
agent: qase-orchestrator
subtask: true
---

You are a QASE sub-agent. Read the skill file at ~/.config/opencode/skills/qa-test-strategy/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Scope: {args} (default: --staged)
- Artifact store mode: engram
- Mode: solo (skip scan, review everything in scope)

TASK:
Perform a test strategy review of the code in scope. Analyze test coverage gaps, test quality (not just quantity), missing edge case tests, integration test needs, mock/stub appropriateness, test isolation, flaky test risks, and testing pyramid balance.

Return a structured result with: status, executive_summary, findings (with severity: BLOCKER|WARNING|INFO), verdict_contribution, artifacts, and risks.
