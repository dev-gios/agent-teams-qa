# runtime-recommendation Specification

## Purpose

Define the `runtime_recommendation` block that `qa-scan` appends to its routing manifest when
detected categories indicate that a runtime specialist should be consulted. The block is a
signal only — it does NOT activate any specialist and does NOT become a routing-matrix column.

---

## Requirements

### Requirement: Category-to-Runtime Trigger Table

`qa-scan` MUST evaluate the detected categories against the following trigger table and populate
`runtime_recommendation` accordingly. The table is authoritative; `routing-rules.md` is the sole
owner.

| Category | Recommends Runtime | Specialists |
|---|:---:|---|
| `ui` | yes | `qa-browser`, `qa-visual` |
| `api` | yes | `qa-browser` only |
| `auth` | yes | `qa-browser` only |
| `business` | **no** | — (explicit non-trigger; `business` is the fallback category) |
| all others | no | — |

#### Scenario: ui category triggers both runtime specialists

- GIVEN a diff where at least one file is classified as `ui`
- WHEN `qa-scan` produces its routing manifest
- THEN `runtime_recommendation.recommended` MUST be `true`
- AND `runtime_recommendation.triggering_categories` MUST include `ui`
- AND `runtime_recommendation.specialists` MUST include `qa-browser` and `qa-visual`

#### Scenario: api category triggers qa-browser only

- GIVEN a diff where at least one file is classified as `api` and none as `ui`
- WHEN `qa-scan` produces its routing manifest
- THEN `runtime_recommendation.recommended` MUST be `true`
- AND `runtime_recommendation.specialists` MUST include `qa-browser`
- AND `runtime_recommendation.specialists` MUST NOT include `qa-visual`

#### Scenario: auth category triggers qa-browser only

- GIVEN a diff where at least one file is classified as `auth`
- WHEN `qa-scan` produces its routing manifest
- THEN `runtime_recommendation.recommended` MUST be `true`
- AND `runtime_recommendation.triggering_categories` MUST include `auth`
- AND `runtime_recommendation.specialists` MUST NOT include `qa-visual`

#### Scenario: business category is an explicit non-trigger

- GIVEN a diff where all files fall through to the `business` default category
- AND no `ui`, `api`, or `auth` categories are detected
- WHEN `qa-scan` produces its routing manifest
- THEN `runtime_recommendation.recommended` MUST be `false`
- AND `runtime_recommendation.specialists` MUST be empty

---

### Requirement: Runtime Recommendation Block Schema

When `runtime_recommendation.recommended` is `true`, `qa-scan` MUST emit a block with exactly the
following keys: `recommended`, `reason`, `triggering_categories`, `specialists`, and
`candidate_targets`. The `candidate_targets` list is advisory only and MUST NOT be auto-navigated.

#### Scenario: Manifest block includes all required keys

- GIVEN a diff with at least one triggering category
- WHEN `qa-scan` returns its manifest
- THEN the `runtime_recommendation` block MUST contain `recommended: true`
- AND MUST contain a non-empty `reason` string naming the triggering categories and file counts
- AND MUST contain `triggering_categories` listing every category that fired
- AND MUST contain `specialists` listing the recommended specialists
- AND MUST contain `candidate_targets` (MAY be an empty list)

#### Scenario: candidate_targets are advisory, never auto-navigated

- GIVEN a manifest with one or more `candidate_targets` entries
- WHEN the orchestrator reads the manifest
- THEN the orchestrator MUST present the targets to the user as suggestions
- AND the orchestrator MUST NOT automatically navigate to any target URL
- AND a `candidate_target` that 404s MUST NOT produce any finding

---

### Requirement: qa-scan Has No Bash and No Environment Access

`qa-scan` MUST NOT assert runtime availability, resolve a URL, or probe any network endpoint.
These facts are unknowable from a diff. The recommendation block contains only diff-derived
information.

#### Scenario: Manifest does not assert runtime is available

- GIVEN any diff with triggering categories
- WHEN `qa-scan` produces its manifest
- THEN the manifest MUST NOT contain any field asserting `runtime_available: true` or `false`
- AND the manifest MUST NOT contain a resolved application URL

#### Scenario: No Bash in qa-scan

- GIVEN the `qa-scan` skill
- WHEN its tool class is inspected in `rule-ownership.md`
- THEN the class MUST be `static` (tools: Read, Grep, Glob, mem_search, mem_get_observation, mem_save)
- AND `Bash` MUST NOT appear in the allowed tools for `qa-scan`
