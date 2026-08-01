# QASE Rule Ownership Registry

This file serves two purposes simultaneously:

1. **Human ownership index** — For every normative rule in QASE, the table below names the one
   file that owns it. Everywhere else, that rule is cited by pointer, never restated.
2. **Linter registry** — `scripts/lib/coherence.sh` parses the tables below using `awk` anchored
   to the `<!-- coherence:table X -->` markers. Table shape changes break the parser; column
   renames are amendments, not refactors.

## Conflict protocol

When a specialist's procedure appears to conflict with a shared contract, **the contract wins**.
The specialist reports the conflict as a WARNING finding against the QASE installation so it is
fixed at the source, and proceeds using the contract. This protocol is not restated here — it is
owned by `severity-contract.md` and referenced from every agent's rule-ownership clause.

## Model assignment

Each QASE agent's `model:` field is set once in the agent file and justified below in the
`capabilities` table. Static reviewers use `sonnet` (analysis, no long reasoning chains needed).
Runtime specialists use `sonnet` (they drive a CLI, not reason over large codebases). The
aggregator (`qa-report`) uses `sonnet` (structured consensus). All assignments are deliberate;
changing a model is an amendment to this registry and to the agent file in the same commit.

## C7 capability decision: `model` field is REQUIRED for QASE agents

The `sdd-verify.md` reference agent carries `model`. The `review-readability.md` reference agent
does not. C6 in `lint_skills.sh` enforces `model` as REQUIRED for `agents/qa-*.md` because:

- QASE agents are spawned by the orchestrator in automated pipelines; without `model`, the host
  picks a default that may change between releases.
- `review-readability.md` is a single-purpose agent with no pipeline contract; its default is
  intentional. QASE agents have an explicit contract. They are different classes.

This decision is recorded here so the C6 check rationale is findable without reading the
linter source.

## C2 scope

C2 (undefined-placeholder) is scoped to `agents/**`, `skills/_shared/qase/**`, and
`skills/qa-*/SKILL.md`. The placeholders table below declares every token used across all three
directories. When adding a new token to a SKILL.md, also add it here — the linter will fail the
positive fixture otherwise.

---

<!-- coherence:table rules -->
| rule_id | owner | literal | scope | allow_regex | allow_count |
|---------|-------|---------|-------|-------------|-------------|
| veto-ack | skills/_shared/qase/severity-contract.md | requires explicit user acknowledgment | skills/**,agents/** | — | 0 |
| forces-reject | skills/_shared/qase/severity-contract.md | forces REJECT | skills/**,agents/** | — | 0 |
| forces-reject-verdict | skills/_shared/qase/severity-contract.md | force a REJECT verdict | skills/**,agents/** | — | 0 |
| tier-ceiling-l3i | skills/_shared/qase/oracle-contract.md | A BLOCKER arriving at L3-inferred | skills/**,agents/** | — | 0 |
| no-auto-start | skills/_shared/qase/routing-rules.md | MUST NOT execute detected_start_hints | skills/**,agents/**,examples/** | — | 0 |
| static-only-qualifier | skills/_shared/qase/severity-contract.md | (STATIC ONLY) | skills/**,agents/** | — | 0 |
<!-- /coherence:table -->

<!-- coherence:table required -->
| check_id | literal | files | min_count |
|----------|---------|-------|-----------|
| orch-no-auto-start | never starts the application | examples/claude-code/CLAUDE.md,examples/vscode/copilot-instructions.md,examples/cursor/.cursorrules,examples/gemini-cli/GEMINI.md,examples/codex/agents.md,examples/antigravity/qase-orchestrator.md,examples/opencode/opencode.json | 1 |
| orch-url-flag | --url | examples/claude-code/CLAUDE.md,examples/vscode/copilot-instructions.md,examples/cursor/.cursorrules,examples/gemini-cli/GEMINI.md,examples/codex/agents.md,examples/antigravity/qase-orchestrator.md,examples/opencode/opencode.json | 1 |
| orch-url-scope-syntax | Base URL for runtime verification | examples/claude-code/CLAUDE.md,examples/vscode/copilot-instructions.md,examples/cursor/.cursorrules,examples/gemini-cli/GEMINI.md,examples/codex/agents.md,examples/antigravity/qase-orchestrator.md,examples/opencode/opencode.json | 1 |
| orch-url-precedence | ### Runtime URL Resolution (ADR-C) | examples/claude-code/CLAUDE.md,examples/vscode/copilot-instructions.md,examples/cursor/.cursorrules,examples/gemini-cli/GEMINI.md,examples/codex/agents.md,examples/antigravity/qase-orchestrator.md,examples/opencode/opencode.json | 1 |
| orch-runtime-step | Step 2b | examples/claude-code/CLAUDE.md,examples/vscode/copilot-instructions.md,examples/cursor/.cursorrules,examples/gemini-cli/GEMINI.md,examples/codex/agents.md,examples/antigravity/qase-orchestrator.md,examples/opencode/opencode.json | 1 |
| orch-runtime-suffix | {runtime_suffix} | examples/claude-code/CLAUDE.md,examples/vscode/copilot-instructions.md,examples/cursor/.cursorrules,examples/gemini-cli/GEMINI.md,examples/codex/agents.md,examples/antigravity/qase-orchestrator.md,examples/opencode/opencode.json | 1 |
| orch-probe-exit-code | Key off the exit code | examples/claude-code/CLAUDE.md,examples/vscode/copilot-instructions.md,examples/cursor/.cursorrules,examples/gemini-cli/GEMINI.md,examples/codex/agents.md,examples/antigravity/qase-orchestrator.md,examples/opencode/opencode.json | 1 |
<!-- /coherence:table -->

<!-- coherence:table forbidden -->
| check_id | token | files | allow_regex | allow_count |
|----------|-------|-------|-------------|-------------|
| visual-no-blockers | HAS_BLOCKERS | skills/qa-visual/SKILL.md | never HAS_BLOCKERS\|intentionally absent | 1 |
| visual-agent-no-blockers | HAS_BLOCKERS | agents/qa-visual.md | MUST NOT declare HAS_BLOCKERS\|never HAS_BLOCKERS | 2 |
<!-- /coherence:table -->

<!-- coherence:table placeholders -->
| token | class | derivation_owner | derivation_anchor |
|-------|-------|------------------|-------------------|
| {review-id} | derived | skills/_shared/qase/openspec-convention.md | ## Review ID Format |
| {flow-slug} | derived | skills/_shared/qase/openspec-convention.md | ### `{flow-slug}` — from a flow name |
| {page-slug} | derived | skills/_shared/qase/openspec-convention.md | ### `{page-slug}` — from a URL |
| {agent} | descriptive | — | — |
| {agent-name} | descriptive | — | — |
| {artifact-type} | descriptive | — | — |
| {category} | descriptive | — | — |
| {count} | descriptive | — | — |
| {detected} | descriptive | — | — |
| {end} | descriptive | — | — |
| {file} | descriptive | — | — |
| {file1} | descriptive | — | — |
| {file2} | descriptive | — | — |
| {file-path} | descriptive | — | — |
| {flow-name} | descriptive | — | — |
| {language} | descriptive | — | — |
| {line} | descriptive | — | — |
| {n} | descriptive | — | — |
| {observation-id} | descriptive | — | — |
| {page-url} | descriptive | — | — |
| {path} | descriptive | — | — |
| {pattern-slug} | descriptive | — | — |
| {project} | descriptive | — | — |
| {project-name} | descriptive | — | — |
| {report} | descriptive | — | — |
| {scope} | descriptive | — | — |
| {scope-slug} | descriptive | — | — |
| {session-id} | descriptive | — | — |
| {slug} | descriptive | — | — |
| {specialist} | descriptive | — | — |
| {start} | descriptive | — | — |
| {total} | descriptive | — | — |
| {url} | descriptive | — | — |
| <url> | descriptive | — | — |
| {viewport} | descriptive | — | — |
| {widthxheight} | descriptive | — | — |
| {agents} | descriptive | — | — |
| {behavior} | descriptive | — | — |
| {brief} | descriptive | — | — |
| {categories} | descriptive | — | — |
| {condition} | descriptive | — | — |
| {date} | descriptive | — | — |
| {description} | descriptive | — | — |
| {findings} | descriptive | — | — |
| {function} | descriptive | — | — |
| {generalized-issue-slug} | descriptive | — | — |
| {height} | descriptive | — | — |
| {id} | descriptive | — | — |
| {lines} | descriptive | — | — |
| {list} | descriptive | — | — |
| {payload} | descriptive | — | — |
| {reason} | descriptive | — | — |
| {returned-manifest} | descriptive | — | — |
| {returned-pattern} | descriptive | — | — |
| {returned-report} | descriptive | — | — |
| {title} | descriptive | — | — |
| {unavailable_reason} | descriptive | — | — |
| {unit} | descriptive | — | — |
| {url-pattern} | descriptive | — | — |
| {verdict} | descriptive | — | — |
| {runtime_suffix} | derived | skills/_shared/qase/severity-contract.md | ### Runtime Coverage Suffix |
| {triggering-categories} | descriptive | — | — |
| {runtime-reason} | descriptive | — | — |
| {viewport_a} | descriptive | — | — |
| {viewport_b} | descriptive | — | — |
| {width} | descriptive | — | — |
| <article> | descriptive | — | — |
| <aside> | descriptive | — | — |
| <button> | descriptive | — | — |
| <file> | descriptive | — | — |
| <flow-name> | descriptive | — | — |
| <footer> | descriptive | — | — |
| <h> | descriptive | — | — |
| <h1> | descriptive | — | — |
| <header> | descriptive | — | — |
| <height> | descriptive | — | — |
| <href> | descriptive | — | — |
| <id> | descriptive | — | — |
| <label> | descriptive | — | — |
| <li> | descriptive | — | — |
| <main> | descriptive | — | — |
| <name> | descriptive | — | — |
| <nav> | descriptive | — | — |
| <ol> | descriptive | — | — |
| <path> | descriptive | — | — |
| <section> | descriptive | — | — |
| <sel> | descriptive | — | — |
| <selector> | descriptive | — | — |
| <stdout> | descriptive | — | — |
| <test-data> | descriptive | — | — |
| <text> | descriptive | — | — |
| <th> | descriptive | — | — |
| <ul> | descriptive | — | — |
| <value> | descriptive | — | — |
| <w> | descriptive | — | — |
| <width> | descriptive | — | — |
<!-- /coherence:table -->

<!-- coherence:table capabilities -->
| agent | class | model |
|-------|-------|-------|
| qa-scan | static | sonnet |
| qa-architect | static | sonnet |
| qa-security | static | sonnet |
| qa-advocate | static | sonnet |
| qa-inclusion | static | sonnet |
| qa-performance | static | sonnet |
| qa-test-strategy | static | sonnet |
| qa-browser | runtime | sonnet |
| qa-visual | runtime | sonnet |
| qa-report | aggregator | sonnet |
| qa-init | static | sonnet |
| qa-feedback | static | sonnet |
<!-- /coherence:table -->

<!-- coherence:table classes -->
| class | tools |
|-------|-------|
| static | Read, Grep, Glob, mem_search, mem_get_observation, mem_save |
| runtime | Read, Grep, Glob, Bash, mem_search, mem_get_observation, mem_save |
| aggregator | Read, Glob, mem_search, mem_get_observation, mem_save |
<!-- /coherence:table -->
