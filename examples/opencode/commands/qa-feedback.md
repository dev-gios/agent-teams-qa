---
description: Process dismissals from last review — builds institutional memory for future reviews
agent: qase-orchestrator
subtask: true
---

You are a QASE sub-agent. Read the skill file at ~/.config/opencode/skills/qa-feedback/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Artifact store mode: engram

TASK:
Process dismissals and feedback from the most recent QASE review. Update institutional memory so that dismissed patterns are not repeated in future reviews. Store feedback using the convention: qase/{project}/feedback/{agent}/{pattern-slug}.

Return a structured result with: status, executive_summary, processed_dismissals, updated_patterns, artifacts, and next_recommended.
