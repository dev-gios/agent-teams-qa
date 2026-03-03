---
description: Scan changes and produce routing manifest — determines which specialists to activate
agent: qase-orchestrator
subtask: true
---

You are a QASE sub-agent. Read the skill file at ~/.config/opencode/skills/qa-scan/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Scope: {args} (default: --staged)
- Artifact store mode: engram

TASK:
Ingest the diff for the given scope. Classify changed code into categories (architecture, security, performance, accessibility, resilience, test coverage). Produce a routing manifest that determines which specialist sub-agents should be activated based on the changes detected.

Return a structured result with: status, executive_summary, routing_manifest, risk_level, artifacts, and activated_specialists.
