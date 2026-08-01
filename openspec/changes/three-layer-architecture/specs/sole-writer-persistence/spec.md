# Sole-Writer Persistence Specification

## Purpose

Define the producer-vs-writer split: every specialist produces a report payload; the orchestrator
is the sole entity that writes that payload to any persistent backend (filesystem or Engram review
artifacts). `mem_save` for Engram review keys remains with the orchestrator. Engram `mem_save` for
the preflight cache key remains with the orchestrator (qa-init produces the payload; the orchestrator
writes it). Specialists retain `mem_save` only for their own personal memory (non-review keys).

Decision B from the proposal: this is a settled decision. The spec records it, not re-opens it.

---

## Requirements

### Requirement: Specialist Return Shape

Every specialist MUST return a structured result envelope that contains all findings, verdict
contribution, and metadata as text in the return value. It MUST NOT write the report to any
filesystem path or Engram review key. The orchestrator reads the return value and writes the
artifact.

#### Scenario: Specialist returns findings inline, not written to disk

- GIVEN a specialist agent that has completed its analysis in openspec mode
- WHEN the specialist finishes and returns its result
- THEN the result MUST contain the full report text in the `executive_summary` or a `report` field
- AND the specialist MUST NOT have called `Write` to create a file at `qaspec/reviews/{id}/*.md`
- AND `rg -n 'Write to \`qaspec/' skills/qa-*/SKILL.md` MUST return zero matches

#### Scenario: Specialist returns findings inline, not written to Engram review key

- GIVEN a specialist agent running in engram mode
- WHEN the specialist finishes
- THEN the specialist MUST NOT have called `mem_save` with a `topic_key` matching
  `qase/{review-id}/{artifact-type}`
- AND the orchestrator is the entity that calls `mem_save` for that key

---

### Requirement: Orchestrator Is the Sole Filesystem Writer

In openspec mode, the orchestrator MUST write each specialist's returned report to the path declared
in `openspec-convention.md`. No skill file MAY contain an instruction telling a specialist to write
directly to `qaspec/`.

`persistence-contract.md` MUST contain a section explicitly naming the orchestrator as the sole
filesystem writer, and MUST distinguish between the openspec paths that the orchestrator owns and
the binary temp-directory paths that specialists write for ephemeral artifacts (screenshots, .har,
.webm).

#### Scenario: persistence-contract.md names the orchestrator as sole writer

- GIVEN `skills/_shared/qase/persistence-contract.md` after this change is applied
- WHEN the file is inspected
- THEN it MUST contain a statement identifying the orchestrator as the sole writer of review
  artifacts to the filesystem
- AND it MUST distinguish "producer" (specialist) from "writer" (orchestrator)

#### Scenario: No SKILL.md instructs the specialist to write to qaspec/

- GIVEN all files matching `skills/qa-*/SKILL.md`
- WHEN the command `rg -n 'Write to \`qaspec/' skills/qa-*/SKILL.md` is run
- THEN the command MUST return zero matches

---

### Requirement: Orchestrator Is the Sole Engram Writer for Review Artifacts

In engram mode, the orchestrator MUST call `mem_save` for every `qase/{review-id}/{artifact-type}`
key. Specialists MUST NOT call `mem_save` with those keys. Each specialist's return envelope carries
the report content; the orchestrator calls `mem_save(topic_key: "qase/{review-id}/{specialist}-
report", content: {returned report})`.

#### Scenario: Orchestrator calls mem_save for specialist reports in engram mode

- GIVEN a review pipeline running in engram mode
- WHEN `qa-security` returns its report
- THEN the orchestrator MUST call `mem_save(topic_key: "qase/{review-id}/security-report", ...)`
- AND `qa-security` MUST NOT have called `mem_save` with that topic_key itself

---

### Requirement: qa-init Producer-vs-Writer Distinction

`qa-init` is the sole PRODUCER of the preflight cache payload. The orchestrator is the sole WRITER
of that payload to `qaspec/preflight-cache.yaml` (openspec mode) or Engram topic key
`qa-init/{project}/preflight` (engram mode).

`persistence-contract.md:54` currently reads "qa-init is the ONLY writer". After this change, that
line MUST be amended to "qa-init is the sole producer of the preflight cache payload; the
orchestrator is the writer."

The same producer-vs-writer distinction applies to `qa-feedback` dismissal patterns and `qa-report`
final-report and actionable-issues artifacts.

#### Scenario: persistence-contract.md preflight rule uses producer/writer language

- GIVEN `skills/_shared/qase/persistence-contract.md` after this change is applied
- WHEN line 54 (or its equivalent) is inspected
- THEN it MUST NOT read "qa-init is the ONLY writer"
- AND it MUST name qa-init as "sole producer" and the orchestrator as "writer"

#### Scenario: qa-init returns cache payload without writing it

- GIVEN `qa-init` executing in openspec mode
- WHEN qa-init completes environment detection
- THEN qa-init MUST return the preflight cache payload in its result envelope
- AND qa-init MUST NOT have written `qaspec/preflight-cache.yaml` directly
- AND the orchestrator MUST write `qaspec/preflight-cache.yaml` from the returned payload

---

### Requirement: mem_save Survives for Specialists (Settled)

Specialists MAY call `mem_save` for Engram keys that are NOT review artifact keys. The sole-writer
rule is scoped to filesystem artifacts and `qase/{review-id}/*` Engram keys. Engram memory for
project context, personal notes, or non-review keys is outside the boundary.

Rationale: routing 12 full reports through the orchestrator context defeats the purpose of
delegation. `mem_save` to non-review keys does not constitute repo mutation.

The already-approved `agents/qa-security.md` retains its Engram mem_ tools; this reading is
confirmed by the proposal and is not re-opened here.

#### Scenario: Specialist retains Engram mem_ tools in its tool list

- GIVEN any `agents/qa-*.md` file
- WHEN the `tools:` field is inspected
- THEN `mcp__plugin_engram_engram__mem_save` (or its equivalent tool name) MUST be present
- AND its presence does NOT violate the sole-writer rule

#### Scenario: Specialist mem_save is limited to non-review-artifact keys

- GIVEN a specialist that calls `mem_save` during its execution
- WHEN the `topic_key` of that call is inspected
- THEN the key MUST NOT match the pattern `qase/{review-id}/{artifact-type}` for a review artifact
  owned by the orchestrator per `engram-convention.md`
