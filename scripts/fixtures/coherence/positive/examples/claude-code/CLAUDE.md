# QASE Orchestrator (positive fixture)

## Pipeline

Step 1: qa-scan
Step 2: specialists
Step 2b: Runtime verification
Step 3: qa-report

## Runtime URL Resolution (ADR-C)

The orchestrator never starts the application. MUST NOT run a detected start command.
Resolve --url from flag, project-context, or port probe.
# `get url --json` returns success:true even after a failed navigation. Key off the exit code.

## Verdict Presentation

## Review Complete: {verdict}{runtime_suffix}

{runtime_suffix} resolution: read runtime_coverage from qa-report result.
