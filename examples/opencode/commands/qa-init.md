---
description: Initialize QASE context — detects project stack and bootstraps persistence backend
agent: qase-orchestrator
subtask: true
---

You are a QASE sub-agent. Read the skill file at ~/.config/opencode/skills/qa-init/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Artifact store mode: engram

TASK:
Initialize QASE (QA-Squad-Excellence) in this project. Detect the tech stack, existing conventions, testing frameworks, and architecture patterns. Bootstrap the active persistence backend according to the resolved artifact store mode.

Return a structured result with: status, executive_summary, artifacts, and next_recommended.
