# Tasks: three-layer-architecture

**Change**: `three-layer-architecture`
**Phase**: tasks
**Spec sources**: agent-layer, capability-boundary, sole-writer-persistence, rule-de-duplication, coherence-lint, multi-tool-distribution
**Verification commands**: `bash scripts/lint_skills.sh` · `bash scripts/install_test.sh`
**Delivery**: single PR with `size:exception`; commit units S1–S5 are the review boundaries.

---

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1 900–2 200 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | single PR with `size:exception` (already decided) |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: size-exception
400-line budget risk: High

### Per-File Estimate

| File / Group | Action | Est. Lines |
|---|---|---|
| `skills/_shared/qase/rule-ownership.md` | New | ~120 |
| `skills/_shared/qase/severity-contract.md` | Delete two duplicate tables + restatement line 15, add oracle reference | ~−55 net |
| `skills/_shared/qase/oracle-contract.md` | Already exists (from runtime-proof-e2e); add tier-ceiling table ownership pointer if missing | ~10 |
| `skills/_shared/qase/persistence-contract.md` | Producer/writer rewording, orchestrator sole-writer section | ~25 |
| `skills/_shared/qase/engram-convention.md` | Writer-identity update | ~10 |
| `skills/_shared/qase/openspec-convention.md` | Writer-identity update | ~10 |
| `agents/qa-security.md` | Remove `Write` + paragraph | ~−5 net |
| `agents/qa-*.md` (11 new) | ~85 lines × 11 | ~935 |
| `skills/qa-*/SKILL.md` (12 files) | Strip 16 write-to-qaspec lines, strip restatements, add pointers, qa-scan ADR-F, qa-init ADR-E′, qa-report Step 3 | ~−100 net + ~80 new = ~400 |
| `examples/claude-code/CLAUDE.md` + 5 orchestrator docs | ADR-E′ probe sequence, sole-writer rule | ~60 |
| `scripts/lib/coherence.sh` | New | ~130 |
| `scripts/lint_skills.sh` | Source coherence.sh, add bijection + tool checks | ~80 |
| `scripts/lib/installer_core.sh` | `install_agents_to_path()` | ~35 |
| `scripts/lib/json_parser.sh` | `get_agents_path()` | ~25 |
| `scripts/install.sh` | `AGENTS_SRC`, `install_custom` agents prompt | ~20 |
| `scripts/install_test.sh` | Agents assertions, `get_agents_path` tests | ~50 |
| `scripts/coherence_test.sh` | New | ~60 |
| `scripts/fixtures/coherence/*` (4 dirs) | New | ~80 |
| `examples/claude-code/qase.json` | `install_agents` block | ~5 |
| `README.md` | Three-layer section, squad count correction | ~40 |
| `.atl/skill-registry.md` | Regenerate (agent layer listed) | ~30 |

**Estimated total changed lines**: ~1 900–2 200 (far above the 400-line budget).

### Suggested Work Units

These are reviewer-guidance commit boundaries inside the single PR, not separate PRs.

| Unit | Goal | Commit boundary | Notes |
|---|---|---|---|
| S1 | Contracts clean — every rule stated once | Commit 1 | Must land before S2/S3 write pointers |
| S2 | 11 new agents + amend qa-security | Commit 2 | Rule-ownership clause names files S1 created |
| S3 | Skills + orchestrators — persistence rewrite | Commit 3 | S3's two halves MUST be atomic (R3) |
| S4 | Tooling — linter, installer, fixtures | Commit 4 | Must come after S1-S3; linter would fail its own corpus otherwise |
| S5 | Docs and registry | Commit 5 | Documents the end state; registry lists agents that exist |

---

## Phase 1: Infrastructure (Contracts and Ownership Registry)

All tasks in this phase MUST be complete before Phase 2 begins. Within the phase, 1.1 is a
prerequisite; 1.2–1.8 are independent of each other and may proceed in parallel once 1.1 is
written.

### [x] 1.1 Create `skills/_shared/qase/rule-ownership.md`

**Specs**: rule-de-duplication §"rule-ownership.md Exists and Is Machine-Readable"; coherence-lint
§"coherence.sh Is a Sourced Module"

Create the file with four `<!-- coherence:table -->` sections (anchored HTML comment markers as
shown in design §"Where the registry lives"):
- `rules` table: `rule_id | owner | literal | scope | allow_regex | allow_count` — one row per
  normative rule string that must appear in exactly one file. At minimum: `veto-ack`
  (`requires explicit user acknowledgment` owned by `severity-contract.md`), `forces-reject`
  (`forces REJECT` owned by `severity-contract.md`), `tier-ceiling-l3i` (WARNING cap for
  L3-inferred, owned by `oracle-contract.md`).
- `forbidden` table: `check_id | token | files | allow_regex | allow_count` — rows for
  `HAS_BLOCKERS` in `skills/qa-visual/SKILL.md` (allow_regex `never HAS_BLOCKERS|intentionally
  absent`, allow_count `2`) and `HAS_BLOCKERS` in `agents/qa-visual.md` (allow_count `0`).
- `placeholders` table: `token | class | derivation_owner | derivation_anchor` — register every
  `{token}` and `<token>` found across agents + SKILL.md + shared contracts. Descriptive tokens
  (`{count}`, `{n}`) have class `descriptive` and empty `derivation_owner`. All others have class
  `derived` and a named owner file + section anchor.
- `capabilities` table: `agent | class` — all 12 agents with class `static`, `runtime`, or
  `aggregator`.
- `classes` table: `class | tools` — static, runtime, aggregator tool sets as shown in design.

Also include a human-readable preamble explaining the conflict protocol (contract wins; specialist
reports WARNING).

---

### [x] 1.2 Edit `skills/_shared/qase/severity-contract.md`

**Specs**: rule-de-duplication §"severity-contract.md:15 self-declared restatement is removed";
rule-de-duplication §"oracle-contract.md Is the Sole Tier Table Owner"

- Delete the sentence at line 15 that says "This section **restates** the ceilings…" and the
  duplicate tier-ceiling table that follows it (lines 13-28 per proposal measurement).
- Delete the second duplicate of the same table (lines 108-119 per proposal measurement).
- Replace each deletion site with a pointer: "Tier definitions and the blocking matrix are owned
  by `oracle-contract.md`. Apply them; do not restate them."
- Verify: `rg -n 'restates' skills/_shared/qase/severity-contract.md` returns zero matches after
  edit.

---

### [x] 1.3 Edit `skills/_shared/qase/persistence-contract.md`

**Specs**: sole-writer-persistence §"Orchestrator Is the Sole Filesystem Writer";
sole-writer-persistence §"qa-init Producer-vs-Writer Distinction"

- Add a new `## Sole Writer` section naming the orchestrator as the only entity that writes review
  artifacts (`qaspec/reviews/**`) and the only writer of `qaspec/preflight-cache.yaml` in openspec
  mode. Distinguish "producer" (specialist returns the payload) from "writer" (orchestrator persists
  it).
- Amend line 54 (current text: "`qa-init` is the ONLY writer of the preflight cache") to read:
  "`qa-init` is the sole **producer** of the preflight cache payload; the orchestrator is the sole
  **writer** of `qaspec/preflight-cache.yaml` (openspec mode) or the engram key
  `qa-init/{project}/preflight` (engram mode)."
- Apply the same producer/writer distinction to `qa-feedback` dismissal patterns and `qa-report`
  final-report and actionable-issues artifacts.

---

### [x] 1.4 Edit `skills/_shared/qase/engram-convention.md`

**Specs**: sole-writer-persistence §"Orchestrator Is the Sole Engram Writer for Review Artifacts"

- Update the "Writer identity" for every `qase/{review-id}/*` key from the specialist name to
  "orchestrator". The key names and `topic_key` patterns are unchanged; only the actor changes.
- Keep the preflight cache key's writer as "orchestrator" (consistent with 1.3).
- Add a pointer to `rule-ownership.md` for the capability class per agent.

---

### [x] 1.5 Edit `skills/_shared/qase/openspec-convention.md`

**Specs**: sole-writer-persistence §"Orchestrator Is the Sole Filesystem Writer"

- Update the "Writer" column for every `qaspec/reviews/**` path from the specialist name to
  "orchestrator". Key names and path patterns unchanged; actor changes only.
- Verify: the writers column for `qaspec/reviews/{review-id}/*.md` names "orchestrator" for all
  entries after the edit.

---

### [x] 1.6 Verify `skills/_shared/qase/oracle-contract.md` owns the tier-ceiling table

**Specs**: rule-de-duplication §"oracle-contract.md Is the Sole Tier Table Owner"

- Confirm `oracle-contract.md` exists (created by `runtime-proof-e2e`) and contains the canonical
  tier-ceiling table with rows for L1, L2, L3-schema, L3-inferred, L4 and max-severity column.
- If the file exists and the table is present, no edit needed — record PASS.
- If the table is missing or the file does not exist, create/edit it now with the table content
  from `runtime-proof-e2e` design §"The Four Tiers". This task is a guard, not a guaranteed write.

---

### [x] 1.7 Edit `skills/_shared/qase/routing-rules.md`

**Specs**: rule-de-duplication §"Referencing Files Cite Rather Than Restate"

- Remove the inline `qa-scan/SKILL.md` activation matrix that restates routing logic. Replace with
  a pointer: "Activation rules and the out-of-band declaration are owned by `routing-rules.md`.
  Apply them; do not restate them." (The routing-rules.md content itself is the owner; the SKILL.md
  copy is the duplicate to remove.)
- The "out-of-band" declaration for `qa-browser` and `qa-visual` stays in `routing-rules.md` (it
  is not being changed semantically — only the duplicate copy in `qa-scan/SKILL.md` is removed).

---

### [x] 1.8 Strip restatement bullets from `skills/_shared/qase/oracle-contract.md`

**Specs**: rule-de-duplication §"oracle-contract.md Is the Sole Tier Table Owner"

- `oracle-contract.md` may currently contain "Oracle-Tier-Aware Routing" bullets 2-3 that duplicate
  `routing-rules.md`. If present, remove them and replace with a pointer to `routing-rules.md`.
- Verify `rg -c 'Oracle Tier' skills/` count has decreased from 60 across 7 files after S1 is
  complete.

---

## Phase 2: Implementation (Agent Layer + Skills + Orchestrators)

### Commit S2: 11 new agent files + amend qa-security

Tasks 2.1–2.12 are independent of each other within the commit and may be written in parallel.
All of them depend on Phase 1 being complete (rule-ownership clause must name files that already
own the rules).

---

### [x] 2.1 Amend `agents/qa-security.md` — remove Write

**Specs**: capability-boundary §"Write Is Removed from All Specialist Agents";
capability-boundary §"qa-security amended paragraph is absent"

- Line 9: remove `Write` from the `tools:` list. Result: `tools: Read, Grep, Glob,
  mcp__plugin_engram_engram__mem_search, mcp__plugin_engram_engram__mem_get_observation,
  mcp__plugin_engram_engram__mem_save`
- Lines 50-52 (the "Your `Write` access exists for exactly ONE purpose" paragraph): delete
  entirely, including any blank line before it.
- Verify: `rg -n 'Write access exists' agents/qa-security.md` returns zero matches.

---

### [x] 2.2 Create `agents/qa-scan.md`

**Specs**: agent-layer (all requirements); capability-boundary §"Static reviewer grants only read
tools"

Following the `agents/qa-security.md` reference pattern and `sdd-verify.md` thin-agent shape:
- Frontmatter: `name: qa-scan`, `description`: non-empty trigger clause naming the condition
  (e.g., "Use when scope must be resolved and routed to appropriate specialists; receives a
  pre-resolved diff from the orchestrator and classifies it."), `model: sonnet`,
  `tools: Read, Grep, Glob, mem_*` (no Bash, no Write, no Edit).
- Body: executor boundary ("Do NOT call Task, Do NOT launch sub-agents"), ordered contract pointer
  list (SKILL.md path, `persistence-contract.md`, `severity-contract.md`, `issue-format.md`),
  startup guard with path-retry and `status: blocked` on failure, rule-ownership clause ("Do not
  restate rules; cite the owner file"), capability boundary note (no Bash — diff is supplied by
  orchestrator per ADR-F), result contract envelope.
- Line count MUST be ≤ 120.

---

### [x] 2.3 Create `agents/qa-architect.md`

**Specs**: agent-layer (all requirements); capability-boundary §"Static reviewer grants only read
tools"

Same shape as 2.2. Key specifics:
- `description`: trigger clause naming SOLID analysis and architectural BLOCKER/veto power.
- `tools`: Read, Grep, Glob, mem_* (no Bash).
- Body references `skills/qa-architect/SKILL.md` and `persistence-contract.md`.
- Capability boundary note: no Bash — SOLID analysis is reading only.

---

### [x] 2.4 Create `agents/qa-advocate.md`

**Specs**: agent-layer; capability-boundary

- `description`: trigger clause naming resilience/chaos analysis.
- `tools`: Read, Grep, Glob, mem_* (no Bash).

---

### [x] 2.5 Create `agents/qa-inclusion.md`

**Specs**: agent-layer; capability-boundary

- `description`: trigger clause naming WCAG/a11y static analysis; runtime a11y belongs to
  `qa-browser`.
- `tools`: Read, Grep, Glob, mem_* (no Bash).

---

### [x] 2.6 Create `agents/qa-performance.md`

**Specs**: agent-layer; capability-boundary

- `description`: trigger clause naming complexity and query-shape analysis; measurement belongs
  to `qa-browser`.
- `tools`: Read, Grep, Glob, mem_* (no Bash).

---

### [x] 2.7 Create `agents/qa-test-strategy.md`

**Specs**: agent-layer; capability-boundary

- `description`: trigger clause naming test strategy analysis; does NOT execute suites (R6).
- `tools`: Read, Grep, Glob, mem_* (no Bash).

---

### [x] 2.8 Create `agents/qa-browser.md`

**Specs**: agent-layer; capability-boundary §"Runtime specialist grants Bash"

- `description`: trigger clause naming runtime browser testing via `agent-browser` CLI.
- `tools`: Read, Grep, Glob, **Bash**, mem_* (no Write).
- Capability boundary note: Bash required — `agent-browser` CLI is the only backend; without
  Bash, runtime QA is impossible.

---

### [x] 2.9 Create `agents/qa-visual.md`

**Specs**: agent-layer; capability-boundary §"qa-visual grants Bash, not Write"

- `description`: trigger clause naming visual regression and design system compliance.
- `tools`: Read, Grep, Glob, **Bash**, mem_* (no Write, no Edit).
- `verdict-contribution` boundary note: `qa-visual` MUST NOT declare `HAS_BLOCKERS` per
  `severity-contract.md` (link to `rule-ownership.md` forbidden table).

---

### [x] 2.10 Create `agents/qa-report.md`

**Specs**: agent-layer; capability-boundary

- `description`: trigger clause naming consensus engine; receives returned findings from
  specialists, never searches raw artifacts.
- `tools`: Read, Glob, mem_* (no Grep — B4 boundary from design; `qa-report` must never search
  raw artifacts). No Bash, no Write.

---

### [x] 2.11 Create `agents/qa-init.md`

**Specs**: agent-layer; capability-boundary

- `description`: trigger clause naming stack detection and environment context bootstrap.
- `tools`: Read, Grep, Glob, mem_* (no Bash — runtime probing is orchestrator-owned per ADR-E′).
- Note: `qa-init` produces the preflight cache payload; the orchestrator writes it (ADR-D).

---

### [x] 2.12 Create `agents/qa-feedback.md`

**Specs**: agent-layer; capability-boundary

- `description`: trigger clause naming dismissal pattern recording; reads report + user dismissals,
  produces patterns; orchestrator writes them.
- `tools`: Read, Grep, Glob, mem_* (no Bash, no Write).

---

### Commit S3: Skills + Orchestrators (same commit — R3 constraint)

Tasks 2.13–2.26 MUST be committed atomically with 2.27 (the 6 orchestrator documents). A specialist
that stops writing before the orchestrator starts writing loses artifacts silently.

---

### [x] 2.13 Rewrite "Execution and Persistence Contract" in `skills/qa-architect/SKILL.md`

**Specs**: sole-writer-persistence §"Specialist Return Shape"; rule-de-duplication §"Ownership
Pointers in SKILL.md Files"

- Change all 16 "Write to `qaspec/…`" lines (measured across 11 files) from write-to-disk
  instructions to return instructions: "Return the report payload in your result envelope. The
  orchestrator writes it to `qaspec/{path}` (openspec mode) or persists it via `mem_save` to the
  review artifact key (engram mode)."
- Add rule-ownership section citing `severity-contract.md`, `oracle-contract.md`, and
  `persistence-contract.md` as the owners; remove any restatement of those rules from the body.
- Apply the same pattern to the remaining 11 skills in tasks 2.14–2.25 (one task per SKILL.md).

---

### [x] 2.14 Rewrite persistence + strip restatements in `skills/qa-security/SKILL.md`

Same pattern as 2.13. Additionally: remove any inline veto-predicate rule text and replace with
"Veto authority and the veto-bearing predicate are owned by `severity-contract.md`."

---

### [x] 2.15 Rewrite persistence + strip restatements in `skills/qa-advocate/SKILL.md`

Same pattern as 2.13.

---

### [x] 2.16 Rewrite persistence + strip restatements in `skills/qa-inclusion/SKILL.md`

Same pattern as 2.13.

---

### [x] 2.17 Rewrite persistence + strip restatements in `skills/qa-performance/SKILL.md`

Same pattern as 2.13.

---

### [x] 2.18 Rewrite persistence + strip restatements in `skills/qa-test-strategy/SKILL.md`

Same pattern as 2.13.

---

### [x] 2.19 Rewrite persistence + strip restatements in `skills/qa-browser/SKILL.md`

Same pattern as 2.13. Additionally: remove any inline oracle-tier ceiling rules and replace with
"Tier ceilings and the blocking matrix are owned by `oracle-contract.md`."

---

### [x] 2.20 Rewrite persistence + strip restatements in `skills/qa-visual/SKILL.md`

Same pattern as 2.13. Target: ≥ 15% shrink from 803 lines (must reach ≤ 682 lines). Restatements
to remove: five sites of the "qa-visual must not produce BLOCKERs" rule (Rules section, Step 10,
report template, metadata block, frontmatter notes). Replace each with a pointer to
`severity-contract.md` and the `rule-ownership.md` forbidden entry.

---

### [x] 2.21 Rewrite persistence + strip restatements in `skills/qa-report/SKILL.md`

Same pattern as 2.13. Additionally: remove Step 3 inline severity pseudocode and replace with
"Apply the two-gate verdict logic owned by `severity-contract.md`."

---

### [x] 2.22 Rewrite persistence + strip restatements in `skills/qa-scan/SKILL.md` — add ADR-F

**Specs**: sole-writer-persistence; rule-de-duplication; design ADR-F

- Rewrite Step 1 to reflect ADR-F: "Read the pre-resolved diff from your context. The orchestrator
  resolves scope → diff via `git diff` / `gh pr diff`; `qa-scan` classifies and routes only. If no
  diff is supplied, record `confidence: reduced` in the routing manifest and classify by file-path
  patterns only."
- Remove the `git diff HEAD~N` / `gh pr diff N` commands from Step 1.
- Remove the inline routing matrix restatement (per 1.7).
- Target: ≥ 15% shrink from 663 lines is for `qa-browser`; no explicit target for `qa-scan`, but
  every restatement removed helps.

---

### [x] 2.23 Rewrite persistence + strip restatements in `skills/qa-init/SKILL.md` — add ADR-E′

**Specs**: sole-writer-persistence; design ADR-E′

- Rewrite Step 4 ("Runtime Preflight"): change from executing `command -v agent-browser`,
  `agent-browser doctor --json`, and the smoke test to: "Read the probe results supplied in your
  context by the orchestrator. The orchestrator ran `command -v agent-browser`,
  `agent-browser doctor --json`, and the smoke connection test (P0-P3 sequence from the
  orchestrator documents). Produce the preflight cache payload from those results and return it."
- The preflight outcome truth table, cache schema, TTL, and refusal rule (supplied by
  `persistence-contract.md`) are unchanged.

---

### [x] 2.24 Rewrite persistence + strip restatements in `skills/qa-feedback/SKILL.md`

Same pattern as 2.13.

---

### [x] 2.25 Verify `qa-visual/SKILL.md` and `qa-browser/SKILL.md` ≥ 15% shrink

**Specs**: proposal success criterion 12

After 2.19 and 2.20 are complete:
- `wc -l skills/qa-visual/SKILL.md` MUST be ≤ 682 (803 × 0.85).
- `wc -l skills/qa-browser/SKILL.md` MUST be ≤ 563 (663 × 0.85).
- If either falls short, identify the remaining restatements and remove them before committing S3.

---

### [x] 2.26 Verify zero Write-to-qaspec instructions across all SKILL.md files

**Specs**: sole-writer-persistence §"No SKILL.md instructs the specialist to write to qaspec/"

Run: `rg -n 'Write to \`qaspec/' skills/qa-*/SKILL.md`
Expected: zero matches. Any match is a blocker for S3 commit.

---

### [x] 2.27 Update all 6 orchestrator documents (same commit as 2.13–2.26)

**Specs**: sole-writer-persistence §"Orchestrator Is the Sole Filesystem Writer"; design ADR-E′

Files: `examples/claude-code/CLAUDE.md`, `examples/vscode/copilot-instructions.md`,
`examples/cursor/.cursorrules`, `examples/opencode/.opencode/rules.md`,
`examples/codex/AGENTS.md` (or equivalent), `examples/antigravity/` orchestrator document.

For each:
- Add the orchestrator write pattern: after receiving a specialist's returned report, the
  orchestrator writes it to `qaspec/reviews/{review-id}/{specialist}.md` (openspec mode) or calls
  `mem_save(topic_key: "qase/{review-id}/{specialist}-report", content: {returned-report})` (engram
  mode).
- Add the ADR-E′ runtime probing sequence for the preflight phase: orchestrator runs
  `command -v agent-browser`, `agent-browser doctor --json`, and the smoke test, then passes results
  to `qa-init` in the context block.
- Update `subagent_type: 'general-purpose'` to reference the named agent for Claude Code; leave
  other tools unchanged (they have no native agent mechanism).

---

## Phase 3: Tooling (Enforcement Layer)

Phase 3 MUST begin after S1–S3 are committed. A linter that lands before the corpus is clean will
fail its own repository (criterion 15 is unsatisfiable until S1–S3 are done).

Tasks 3.1–3.4 are independent and may proceed in parallel. Task 3.5 (wiring) depends on 3.1–3.2.
Tasks 3.6–3.9 depend on 3.5. Tasks 3.10–3.11 depend on 3.3. Task 3.12 (install_test assertions)
depends on 3.10–3.11.

---

### [x] 3.1 Create `scripts/lib/coherence.sh`

**Specs**: coherence-lint §"coherence.sh Is a Sourced Module"

Create the file as a function library (no top-level executable code). It calls the caller-provided
`pass`/`fail`/`warn` functions, consistent with the existing `installer_core.sh` pattern. Implement:
- `coh_table()` — parses a named `<!-- coherence:table X -->` block from a file and emits TSV rows
  (awk implementation from design §"Where the registry lives").
- `check_c1_forbidden_token()` — forbidden-token check using `coh_table forbidden` and
  `grep -cF` + `grep -Ec allow_re` pattern (design §"Check C1").
- `check_c2_undefined_placeholder()` — extract `{token}` and `<token>` patterns from the corpus,
  compare to the `placeholders` table, emit FAIL for undeclared tokens, WARN for declared-but-unused
  (design §"Check C2"). Regex anchored to lowercase `[a-z][a-z0-9_-]*` to avoid shell expansions,
  HTML fragments, and autolinks.
- `check_c3_derivation_anchor()` — for each `class: derived` placeholder, verify the anchor
  heading exists in the owner file and the section body is non-empty (design §"Check C3").
- `check_c4_single_source()` — for each row in the `rules` table, `grep -rlF` the literal across
  the declared scope; fail if count ≠ 1 (design §"Check C4").
- `run_coherence_checks()` — calls C1–C4 in order. Accepts a corpus root parameter.

---

### [x] 3.2 Create `scripts/fixtures/coherence/` with 4 fixture corpora

**Specs**: coherence-lint §"Negative fixture proves the linter can fail"; proposal criterion 16

Create the directory `scripts/fixtures/coherence/` and four sub-corpora:

- `positive/` — minimal well-formed corpus (a stub rule-ownership.md, a stub SKILL.md with no
  violations, a stub shared contract). Running coherence checks over this MUST exit 0.
- `neg-forbidden-token/` — copy of `skills/qa-visual/SKILL.md` with `HAS_BLOCKERS` inserted in a
  plain prose line (not in a negation context). Running C1 MUST exit 1 with message naming
  `HAS_BLOCKERS`.
- `neg-undefined-placeholder/` — stub SKILL.md containing `<evid>` used three times, rule-ownership.md
  placeholders table with no entry for `<evid>`. Running C2 MUST exit 1 naming `<evid>`.
- `neg-missing-derivation/` — stub SKILL.md containing `{page-slug}`, rule-ownership.md
  placeholders table declaring `{page-slug}` as `class: derived` with an anchor that does not exist
  in the owner file. Running C3 MUST exit 1 naming `{page-slug}`.

---

### [x] 3.3 Create `scripts/coherence_test.sh`

**Specs**: coherence-lint §"Negative fixture proves the linter can fail"

Create the script that runs each fixture and asserts BOTH the exit code AND the failing check id.
A fixture that fails for the wrong reason is a false green and MUST be caught.

- Run the coherence checks over `positive/` — assert exit 0.
- Run C1 check over `neg-forbidden-token/` — assert exit 1 AND output contains `C1`.
- Run C2 check over `neg-undefined-placeholder/` — assert exit 1 AND output contains `C2`.
- Run C3 check over `neg-missing-derivation/` — assert exit 1 AND output contains `C3`.
- Print PASS/FAIL per fixture. Exit 1 if any fixture produces the wrong outcome.

---

### [x] 3.4 Extend `scripts/lint_skills.sh` — source coherence.sh and add structural checks

**Specs**: coherence-lint §"lint_skills.sh sources coherence.sh"; agent-layer §"bijection check";
capability-boundary (all grep assertions)

- Add `source "$LIB_DIR/coherence.sh"` after the existing lib sources.
- Add **C5 bijection check**: compare `basename agents/qa-*.md .md` set with
  `basename skills/qa-*/` set. Report orphans in both directions. FAIL if count ≠ 12.
- Add **C6 agent-shape check**: for each `agents/qa-*.md` — frontmatter has `name`, `description`,
  `model`, `tools`; `name` == filename stem == matching skill directory; `wc -l ≤ 120`; body
  contains `SKILL.md` and `persistence-contract.md`; body contains "Do NOT call the Task tool"
  (or equivalent); `description` is non-empty and matches `Use when|Trigger:`.
- Add **C7 capability check**: `rg '^tools:.*\b(Write|Edit|MultiEdit|NotebookEdit)\b' agents/` →
  0; `rg -l '^tools:.*\bBash\b' agents/` → exactly `qa-browser.md` and `qa-visual.md`.
- Add **C8 no-self-write check**: `rg -n 'Write to \`qaspec/' skills/qa-*/SKILL.md` → 0.
- Wire all four new structural checks into the main linter loop, reusing the existing `pass`/`fail`/
  `warn` functions.
- Call `run_coherence_checks "$PROJECT_DIR"` after the per-skill loop.

---

### [x] 3.5 Add `get_agents_path()` to `scripts/lib/json_parser.sh`

**Specs**: multi-tool-distribution §"installer_core.sh Gains install_agents_to_path()"

- Add `get_agents_path(file, os_key)` mirroring `get_install_path()` but targeting the
  `"install_agents":` block. The function MUST use `/"install_agents":/,/}/p` to avoid collision
  with `/"install":/` (design §"Installer flow"). Return empty string (exit 1) if the block or OS
  key is absent. This is the contract for the skills-only case.

---

### [x] 3.6 Add `install_agents_to_path()` to `scripts/lib/installer_core.sh`

**Specs**: multi-tool-distribution §"installer_core.sh Gains install_agents_to_path()"

- Add `install_agents_to_path(target_dir, tool_name, agents_src)` mirroring
  `install_skills_to_path()`. The function: `mkdir -p "$target_dir"`, checks write permission,
  copies `agents/qa-*.md` files only (not subdirectories), logs count and target path. Reuse
  `make_writable`. Warn if count ≠ 12 but do not exit non-zero for count mismatch (optional layer).

---

### [x] 3.7 Extend `scripts/install.sh` — AGENTS_SRC and agent distribution

**Specs**: multi-tool-distribution §"install.sh Distributes agents/ When Declared"

- Add `AGENTS_SRC="$REPO_DIR/agents"` near the existing `SKILLS_SRC` declaration.
- In `install_tool()`: after calling `install_skills_to_path`, call `get_agents_path "$json_path"
  "$OS" || true`. If the result is non-empty, call `install_agents_to_path(resolved_agents_path,
  tool_name, AGENTS_SRC)`. If empty, print "Agents: not supported by <tool> — skills-only install"
  and continue (exit 0 unchanged).
- In `install_custom()`: prompt for an optional agents path and call `install_agents_to_path` if
  non-empty.

---

### [x] 3.8 Add `install_agents` block to `examples/claude-code/qase.json`

**Specs**: multi-tool-distribution §"claude-code qase.json declares install_agents"

- Add the `install_agents` object with `linux`, `macos`, `wsl`, and `windows` keys following the
  same shape as the existing `install` object:
  ```json
  "install_agents": {
    "linux": "$HOME/.claude/agents",
    "macos": "$HOME/.claude/agents",
    "wsl": "$HOME/.claude/agents",
    "windows": "$USERPROFILE/.claude/agents"
  }
  ```
- Leave all seven other `examples/*/qase.json` files unchanged (no `install_agents` block).

---

### [x] 3.9 Extend `scripts/install_test.sh` — agents assertions

**Specs**: multi-tool-distribution §"install_test.sh asserts agents land at declared target";
proposal criterion 17

- Add `test_agent_installer()` function mirroring `test_installer_core()` using a synthetic
  `$TMP_DIR` agents source.
- Add a test asserting `install_agents_to_path` copies 12 files to the target.
- Add a test asserting `install_agents_to_path` creates the target directory if absent.
- Add a test asserting `get_agents_path` returns empty for a `qase.json` without `install_agents`.
- Add a test asserting that no installed agent grants `Write`:
  `rg -l '^tools:.*\bWrite\b' "$AGENTS_TARGET"` MUST return zero matches.

---

## Phase 4: Testing and Verification

Tasks 4.1–4.8 are independent mechanical checks and may run in parallel. Task 4.9 (system test) is
the gate that precedes any commit of S4.

---

### [x] 4.1 Verify linter exits 0 on the delivered corpus (criterion 15)

Run `bash scripts/lint_skills.sh`. Expected: ALL PASSED, exit 0. Any FAIL entry is a blocker.

---

### [x] 4.2 Verify zero Write grants across all agents (criterion 5)

Run: `rg -n '^tools:.*\bWrite\b' agents/`
Expected: zero matches.

---

### [x] 4.3 Verify exactly two Bash grants (criterion 6)

Run: `rg -l '^tools:.*\bBash\b' agents/`
Expected: exactly two files — `agents/qa-browser.md` and `agents/qa-visual.md`.

---

### [x] 4.4 Verify zero Edit-family grants (criterion 7)

Run: `rg -n '^tools:.*\b(Edit|MultiEdit|NotebookEdit)\b' agents/`
Expected: zero matches.

---

### [x] 4.5 Verify bijection — 12 agents ↔ 12 skills (criteria 1 and 2)

- `ls agents/qa-*.md | wc -l` MUST equal 12.
- Every stem in `agents/qa-*.md` MUST have a matching `skills/qa-{stem}/SKILL.md`.
- No orphan in either direction.
- `wc -l agents/qa-*.md` MUST show each file ≤ 120 lines.

---

### [x] 4.6 Verify severity-contract.md no longer contains "restates" (criterion 11, rule-ded. spec)

Run: `rg -n 'restates' skills/_shared/qase/severity-contract.md`
Expected: zero matches.

---

### [x] 4.7 Verify veto rule string appears only in severity-contract.md (criterion 10)

Run: `rg -n 'requires explicit user acknowledgment|forces REJECT' skills/qa-*/SKILL.md`
Expected: zero matches.

---

### [x] 4.8 Verify coherence fixture tests all pass (criterion 16)

Run `bash scripts/coherence_test.sh`.
Expected: all four fixture outcomes (1 pass + 3 expected-fail) are correct. Exit 0.

---

### [x] 4.9 Run full install_test.sh (criterion 17)

Run `bash scripts/install_test.sh`.
Expected: exit 0. All assertions including the new agents tests pass.

---

## Phase 5: Documentation and Registry

Tasks 5.1 and 5.2 are independent. Task 5.3 depends on 5.1 and 5.2 (documents the final state).

---

### [x] 5.1 Update `README.md`

**Specs**: proposal criterion 19

- Add "Three-Layer Architecture" section with the L0–L4 diagram from design.
- Change "The Squad (7 Static + 2 Runtime Specialists)" (proposal wording) to list all 12
  specialists with their capability class.
- Add installation note: Claude Code installs both skills and agents; other tools install skills
  only.

---

### [x] 5.2 Regenerate `.atl/skill-registry.md`

**Specs**: proposal criterion 20

- Regenerate the registry to list all 12 skills AND the 12 agents in a new "Agent Layer" section.
- Each agent entry: name, description (from frontmatter), capability class, tools summary.
- Verify the registry lists exactly 12 skills and 12 agents with matching stems.

---

### [x] 5.3 Final linter + install-test gate (post-docs)

Run `bash scripts/lint_skills.sh && bash scripts/install_test.sh`.
Both MUST exit 0. This is the final green gate before the PR is marked ready for review.

---

## Phase Summary

| Phase | Tasks | Parallelism |
|---|---|---|
| 1 — Infrastructure | 1.1–1.8 | 1.1 first; 1.2–1.8 may proceed in parallel after 1.1 |
| 2 — Implementation | 2.1–2.27 | 2.1–2.12 in parallel (S2 commit); 2.13–2.27 parallel within S3 commit |
| 3 — Tooling | 3.1–3.9 | 3.1–3.4 parallel; 3.5 before 3.6–3.7; 3.8–3.9 independent |
| 4 — Testing | 4.1–4.9 | 4.1–4.8 parallel; 4.9 after all of Phase 3 |
| 5 — Docs | 5.1–5.3 | 5.1 and 5.2 parallel; 5.3 after both |

**Total tasks: 42** (8 infrastructure + 27 implementation + 9 tooling + 9 testing + 3 docs).

---

## Known Risks and Mitigations

| Risk | Task scope | Mitigation |
|---|---|---|
| **Deny-list false positives** (design §"Stated limitation"): `skills/qa-visual/SKILL.md:696` and `:732` contain `HAS_BLOCKERS` as correct negations. | 1.1, 3.1 | `rule-ownership.md` `forbidden` table declares `allow_regex: never HAS_BLOCKERS\|intentionally absent` and `allow_count: 2`; the exemption is itself drift-detectable because a third occurrence fails even if it matches the negation pattern. |
| **`severity-contract.md` duplicate table appears twice** (lines 13-28 AND 108-119). Proposal named only line 15. | 1.2 | Task 1.2 explicitly targets both sites. |
| **Token registry bootstrap is real work**: 59 distinct `{token}` / `<token>` matches in `qa-browser/SKILL.md` alone. | 1.1 | If the full corpus is too heavy for S1, scope C2 initially to `agents/**` + `skills/_shared/qase/**` (design Open Questions §"Registry bootstrap cost") and record the scope limit in `rule-ownership.md`. Extend to `skills/qa-*/` in a follow-up. |
| **Same-commit constraint** (R3): SKILL.md persistence rewrite and orchestrator-side writer changes must land together. | 2.13–2.27 | Tasks 2.13–2.27 are one commit (S3). Task 2.26 is a pre-commit gate. |
| **`persistence-contract.md:54`** currently calls `qa-init` "the ONLY writer". | 1.3 | Task 1.3 explicitly rewrites line 54 with producer/writer language. |
| **`~/.claude/agents/review-readability.md` has no `model` field** while `sdd-verify.md` does. | 3.4 (C6 check) | C6 checks whether `model` is present in QASE agents. If `review-readability.md` is the only agent without `model`, consider whether `model` should be REQUIRED or OPTIONAL in the C6 check. Decide before S4 commit and make the check match reality — do not write a check that fails the only reference agent. Record the decision in `rule-ownership.md`. |
| **ADR-E′ confirmation pending** (design Open Questions). | 2.23, 2.27 | If ADR-E′ is rejected, restore `qa-init` Step 4 probing, add `Bash` to `agents/qa-init.md`, and amend criterion 6 to "exactly three" Bash files. The task boundary is 2.11 + 2.23 + 2.27 — contained. |
