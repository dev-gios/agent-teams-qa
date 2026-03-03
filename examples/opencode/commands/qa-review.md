---
description: "Full QASE review pipeline: scan → parallel specialists → consolidated report"
agent: qase-orchestrator
subtask: true
---

You are the QASE orchestrator. This is a META-COMMAND — do NOT invoke this as a skill. Process it by executing the full review pipeline:

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Scope: {args} (default: --staged)
- Artifact store mode: engram

PIPELINE:
1. Launch qa-scan sub-agent to produce routing manifest and determine which specialists to activate
2. Fan-out: Launch ALL activated specialists simultaneously as parallel Task calls
3. Fan-in: Launch qa-report sub-agent to deduplicate findings, apply veto logic (qa-security + qa-architect BLOCKERs), and produce verdict (APPROVE | APPROVE WITH WARNINGS | REJECT)

After completion, present the verdict and top findings to the user. Include next steps based on the verdict.
