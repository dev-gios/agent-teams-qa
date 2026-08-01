# Proposal: three-layer-architecture

**Change**: `three-layer-architecture`
**Phase**: proposal
**Input**: direct user brief (no exploration artifact exists for this change)
**Status**: ready for spec and design

---

## 1. Why

### The business problem

QASE exists to catch what a human reviewer would miss. It currently cannot, because **QASE has no isolation**: the repository ships 12 skills and zero agents. `/qa-review` loads every specialist into one shared context. The "squad" is a single mind performing six voices.

The consequences are not theoretical:

- **No independence.** What the architect concluded colours what the security reviewer then sees. Six agreeing voices in one context are one opinion reported six times.
- **No real parallelism.** Fan-out is nominal; there is one context doing sequential work.
- **No capability boundary.** Every specialist inherits whatever tools the host session has. A security reviewer can run shell commands and write into the repository it is auditing.

**Empirical proof, this session.** A fresh-context `review-readability` agent found three defects the fully-contexted orchestrator had missed:

1. a triple contradiction about whether `qa-visual` may emit BLOCKERs,
2. an `<evid>` variable used three times and never defined,
3. a `{page-slug}` template token used with no derivation algorithm.

The orchestrator missed them **because** it knew the design intent and therefore read what it expected to read. Independence is not a token optimisation. It is the source of review value.

### The root cause of four failed repair rounds

The same normative rule is written in five places. "qa-visual must not produce BLOCKERs" lives in its Rules section, its Step 10 verdict logic, its report template, its metadata block, and `severity-contract.md`. Each repair round fixed one site and left the others, so every round produced a new contradiction.

Measured today:

| Symptom | Measurement |
|---|---|
| `veto` appears across | 14 files (45 occurrences), 11 of them `skills/qa-*/SKILL.md` |
| `Oracle Tier` appears across | 7 files (60 occurrences) |
| `severity-contract.md:15` | literally says *"This section **restates** the ceilings"* — a declared second source of truth |
| `skills/qa-visual/SKILL.md` | 730 → **803** lines |
| `skills/qa-browser/SKILL.md` | 595 → **663** lines — past its own recorded ~600-line extraction trigger |

Each fix made the files larger and the contradictions more numerous. That is not sloppy execution. That is duplicated sources of truth behaving exactly as duplicated sources of truth behave.

### Why now

- The defect class is now proven, reproduced, and greppable. All three BLOCKERs the fresh review found are detectable by a script. If they are not made mechanically detectable now, round five is inevitable.
- `qa-browser` and `qa-visual` have already crossed their size trigger. Further work on them without a home for the rules compounds the problem.
- `agents/qa-security.md` is already written and user-approved. The pattern exists; eleven siblings are missing.

---

## 2. What changes

QASE gains a **three-layer architecture with three distinct owners**, so that every fact has exactly one home.

| Layer | Owns | Changes when |
|---|---|---|
| `agents/qa-*.md` | Isolation, `tools` (the capability boundary), routing — the `description` field is what makes an orchestrator select the agent | Who may do what changes |
| `skills/qa-*/SKILL.md` | The procedure only | How the work is done changes |
| `skills/_shared/qase/*.md` | Normative rules (severity, oracle tier, veto, persistence, routing) stated exactly **once** | What blocks delivery changes |

### In scope

1. **Author `agents/*.md` for all 12 specialists** — `qa-scan`, `qa-architect`, `qa-security` (amend), `qa-advocate`, `qa-inclusion`, `qa-performance`, `qa-test-strategy`, `qa-browser`, `qa-visual`, `qa-report`, `qa-init`, `qa-feedback`.
2. **Thin agents only** — frontmatter, "read your SKILL.md and shared contracts and follow them exactly", rule-ownership clause, capability boundary, result contract. No procedure, no rules. (Decision A.)
3. **`tools:` as a real capability boundary.** Only `qa-browser` and `qa-visual` get Bash, because driving the `agent-browser` CLI is the one job that cannot be done any other way. Every other specialist is Bash-free.

   Two specialists appear to need shell and do not, resolved by **ADR-E′** and **ADR-F** in `design.md` — both CONFIRMED:

   - `qa-init` needs `command -v agent-browser`, `agent-browser doctor --json`, and a smoke connection for the `runtime-proof-e2e` preflight. The **orchestrator** runs those four short probes and passes the results down; `qa-init` produces the cache payload from them. Precedent already in the repo: `persistence-contract.md:17` — *"The orchestrator is responsible for detecting Engram availability BEFORE launching any sub-agents."* Environment-capability detection is resolved once per pipeline and passed down; this makes the two detections consistent instead of split across layers. `qa-init` remains the sole **producer** of the cache — `runtime-proof-e2e` ADR-E survives intact (one prober, one truth).
   - `qa-scan` maps scope via `git diff` / `gh pr diff` (`skills/qa-scan/SKILL.md:59-64`). The **orchestrator** resolves scope to a diff and passes it in; `qa-scan` classifies and routes. It already owns scope resolution by convention, and `qa-scan` runs in *every* review — granting it shell would hand a shell to the first agent of every pipeline.

   An orchestrator ruling mid-apply briefly reversed this to "Bash (4)" on the grounds that the preflight would break. That was decided from a risk summary without reading the ADRs, and was wrong: the probes move, the preflight does not break. Reverted here so the artifact, not a prompt, remains the source of truth.
4. **No specialist writes files.** `Write` is removed from every specialist agent; the orchestrator is the sole filesystem writer. Requires rewriting the "Execution and Persistence Contract" section of all 12 SKILL.md files and `persistence-contract.md`. (Decision B.)
5. **De-duplicate normative rules** — each stated once in `skills/_shared/qase/`, referenced but never restated elsewhere, with ownership declared in a new `rule-ownership.md`.
6. **Extend `scripts/install.sh`** to distribute `agents/`. It currently installs only `SKILLS_SRC="$REPO_DIR/skills"` and would not ship the new layer at all.
7. **Extend `scripts/lint_skills.sh` with coherence checks** — forbidden-token, undefined-placeholder, and single-source-of-truth. Registry-driven, not heuristic. (Decision C.)
8. **Update `README.md`** and the per-tool orchestrator documents to describe the three-layer architecture and the new sole-writer rule.

### Explicitly deferred — do not design these

- **Making `qa-scan` route the runtime specialists.** `routing-rules.md:96-106` declares `qa-browser` and `qa-visual` out-of-band and NOT activated by `qa-scan`, so `/qa-review --pr 42` never opens a browser. This is a real gap and a separate change.
- Any change to severity, veto, or oracle **semantics**. This change relocates rules; it does not alter what they say.
- New specialists, new commands, CI wiring, model re-tuning.
- Extraction of `qa-flow` from `qa-browser` (recorded trigger in `runtime-proof-e2e` Decision B).

### Affected modules

**New — 11 agent files**

`agents/qa-scan.md`, `agents/qa-architect.md`, `agents/qa-advocate.md`, `agents/qa-inclusion.md`, `agents/qa-performance.md`, `agents/qa-test-strategy.md`, `agents/qa-browser.md`, `agents/qa-visual.md`, `agents/qa-report.md`, `agents/qa-init.md`, `agents/qa-feedback.md`

**New — contracts and tooling**

| File | Purpose |
|---|---|
| `skills/_shared/qase/rule-ownership.md` | **NEW.** Names the canonical owner file for every normative rule. The registry the linter reads. |
| `scripts/lib/coherence.sh` | **NEW.** Coherence check implementations, sourced by the linter (matches the existing `scripts/lib/` modular pattern). |

**Modified**

| File | Change |
|---|---|
| `agents/qa-security.md` | Remove `Write` from `tools:`; delete the "Your `Write` access exists for exactly ONE purpose" paragraph, which Decision B forbids |
| `skills/qa-*/SKILL.md` (all 12) | Rewrite "Execution and Persistence Contract" to *return, not write*; strip restated normative rules and replace with ownership pointers |
| `skills/_shared/qase/persistence-contract.md` | Orchestrator becomes sole filesystem writer; preflight-cache single-writer rule reworded producer-vs-writer |
| `skills/_shared/qase/severity-contract.md` | Delete the self-declared restatement at line 15 and the duplicated tier-ceiling table; reference `oracle-contract.md` instead. Becomes sole owner of severity, veto, verdict logic |
| `skills/_shared/qase/oracle-contract.md` | Becomes sole owner of tier definitions, citation rules, blocking matrix |
| `skills/_shared/qase/issue-format.md` | Sole owner of finding structure and metadata envelope |
| `skills/_shared/qase/routing-rules.md` | Sole owner of activation and out-of-band rules |
| `skills/_shared/qase/engram-convention.md`, `openspec-convention.md` | Writer identity changes: paths and keys stay, the actor becomes the orchestrator |
| `scripts/install.sh` | Add `AGENTS_SRC`; resolve an agents target per tool |
| `scripts/lib/installer_core.sh` | Add `install_agents_to_path()` alongside `install_skills_to_path()` |
| `scripts/lint_skills.sh` | Source `coherence.sh`; add agent/skill bijection and `tools:` checks |
| `scripts/install_test.sh` | Assert agents are installed and that no agent grants `Write` |
| `examples/*/qase.json` (7 real tools + `mock-tool`) | Optional `install_agents.<os>` block |
| `examples/claude-code/CLAUDE.md` and the other 5 orchestrator documents | `subagent_type: 'general-purpose'` becomes the named agent; document the sole-writer rule |
| `README.md` | Three-layer architecture section; correct "The Squad (7 Static + 2 Runtime Specialists)" (there are 12); Project Structure; Installation |
| `.atl/skill-registry.md` | Regenerate |

**Assumption stated plainly**: `examples/mock-tool/` is a test fixture, not a shipped tool, and gets the agents block only if `install_test.sh` needs it.

---

## 3. Decisions

### Decision A — Thin agents, following the `sdd-verify` pattern

**Decision: agents contain frontmatter, a pointer to the SKILL.md and shared contracts, a rule-ownership clause, a capability boundary, and a result contract. Nothing else.** `agents/qa-security.md` is the approved reference for the other eleven.

Rationale:

- **The skills ARE the product.** The README promises "Zero dependencies. Pure Markdown. Works everywhere." Moving procedure or rules into `agents/` ties QASE to Claude Code's agent format and breaks the promise for Codex, Gemini CLI, OpenCode, VS Code, Cursor, and Antigravity.
- **Self-contained agents would create a thirteenth and fourteenth copy** of rules that already drift across five sites. The change would import the exact pathology it exists to remove.
- The agent layer earns its keep with three things a skill file cannot express: process isolation, a `tools` capability boundary, and a `description` that makes an orchestrator select it. Those are the only three things it should hold.

Rejected — the `review-readability` pattern (rules self-contained in the agent):

- Genuinely simpler to read: one file, no indirection, no startup guard.
- Rejected because `review-readability` is a single-purpose Claude Code agent with no distributable artifact behind it. QASE's skills are shipped to seven toolchains. An agent-resident rule is invisible to six of them.

Rejected — status quo, skills only:

- Rejected by the empirical result in §1: the defects were found by an isolated context and missed by a shared one.

### Decision B — Specialists return; the orchestrator writes

**Decision (made by the user; recorded here, not re-opened): specialists MUST NOT persist their own filesystem artifacts. They return their report; the orchestrator writes it. `Write` is removed from all 12 specialist agents.**

Rationale: `tools:` cannot be path-restricted. A `Write` grant is repo-wide. A security reviewer able to write into the repository it audits is a larger attack surface than the code it is protecting — the same argument that already removed Bash from it.

Three consequences this proposal resolves rather than leaves implicit:

1. **Engram persistence stays with the specialist.** `mem_save` is retained. The stated rationale is repo mutation, and `mem_save` writes to a memory store outside the audited repository. Removing it would force every full specialist report through the orchestrator's context — the exact context bloat that delegation exists to prevent. The already-approved `agents/qa-security.md` retains `mem_save`, and this reading keeps it correct. *Flagged in the question round.*
2. **`qa-init` no longer writes the preflight cache.** `persistence-contract.md:54` currently makes `qa-init` "the ONLY writer". It becomes the sole **producer** of the cache payload; the orchestrator is the sole **writer**. Same for `qa-feedback` dismissal patterns and `qa-report` final-report and actionable-issues artifacts.
3. **`agents/qa-security.md` must be amended by this change.** It currently lists `Write` in `tools:` and carries a paragraph justifying it. The approved reference contradicts the decision it is meant to illustrate; the amendment is in scope.

Rejected — path-restricted write:

- Not expressible. `tools:` accepts tool names, not paths. A restriction the platform cannot enforce is documentation, not a boundary.

Rejected — remove `mem_save` too, for a literal single-writer rule:

- Conceptually cleanest. Rejected because it routes 12 full reports through the orchestrator context and makes engram mode more expensive than no persistence at all.

### Decision C — Rule de-duplication is enforced mechanically, not by convention

**Decision: `skills/_shared/qase/rule-ownership.md` declares the canonical owner of every normative rule, and `scripts/lint_skills.sh` fails the build when a rule appears outside its owner.**

Rationale: four consecutive rounds of human-and-model review failed to hold this invariant. A fifth round of the same method has no reason to succeed. All three BLOCKERs the fresh review found were greppable:

| Defect found | Check class |
|---|---|
| `HAS_BLOCKERS` present in a file declaring it cannot emit BLOCKERs | **Forbidden token** — per-skill deny-list |
| `<evid>` used three times, never defined | **Undefined placeholder** — every `<token>` / `{token}` used must be defined in the file or a referenced contract |
| `{page-slug}` used with no derivation algorithm | **Undefined placeholder**, same check |
| `severity-contract.md:15` restating `oracle-contract.md` | **Single source** — a registered rule string must match in exactly one file |

This is QASE applying QASE to itself: the framework that demands evidence-backed findings gets a linter that produces them about its own contracts.

Rejected — convention plus code review:

- Zero implementation cost. Rejected on evidence: it is the method that produced four contradictory rounds.

Rejected — a single monolithic contract file:

- Removes cross-file duplication by construction. Rejected because it makes every specialist read every rule, and the file becomes the next 800-line artifact.

### Decision D — Agents are distributed as an optional per-tool layer

**Decision: `qase.json` gains an optional `install_agents.<os>` map. Tools that declare it get `agents/`; tools that do not get skills only, unchanged.**

Rationale: `agents/` is a Claude-Code-shaped concept. Skills must remain complete and self-sufficient without it, or "Works everywhere" becomes false. The agent layer is an isolation and routing upgrade for hosts that support it, never a prerequisite.

Rejected — derive the agents path from the skills path (`dirname(install)/agents`):

- Convenient and correct for Claude Code. Rejected because it silently guesses a layout for tools whose skills path is not sibling to an agents path, and creates directories a tool will never read.

---

## 4. Success criteria

Observable and mechanically checkable. A criterion a script cannot assert is not on this list.

**Agent layer exists and is thin**

1. `agents/qa-*.md` count is exactly **12**, and the set of stems is a bijection with `skills/qa-*/SKILL.md` directory names. No orphan in either direction.
2. Every agent file is **≤ 120 lines** (`agents/qa-security.md` is 82 today). A longer agent is procedure or rules leaking upward.
3. Every agent frontmatter carries `name`, `description`, `model`, `tools`, and `name` equals the filename stem equals the skill directory name.
4. Every agent body contains a reference to its own `SKILL.md` and to `persistence-contract.md`. An agent that does not point at its procedure has absorbed it.

**Capability boundary is real**

5. `rg -n '^tools:.*\bWrite\b' agents/` returns **zero** matches.
6. `rg -l '^tools:.*\bBash\b' agents/` returns **exactly two** files: `qa-browser`, `qa-visual` (per ADR-E′ and ADR-F, both confirmed).
7. `rg -n '^tools:.*\b(Edit|MultiEdit|NotebookEdit)\b' agents/` returns **zero** matches.

**Rules are stated once**

8. `skills/_shared/qase/rule-ownership.md` exists and registers, for every normative rule, its owner file and the literal string the linter matches on.
9. For every registered rule, `rg -l "<rule-string>" skills/` returns **exactly one** file, and it is the registered owner.
10. `rg -n 'requires explicit user acknowledgment|forces REJECT' skills/qa-*/SKILL.md` returns **zero** matches. That sentence is owned by `severity-contract.md`. (Frontmatter `veto_power:` is metadata, not a restatement, and stays — `runtime-proof-e2e` criterion 3 still pins it to exactly three `true` values.)
11. The tier → max-severity table appears **once**, in `oracle-contract.md`. `severity-contract.md` no longer contains the word "restates".
12. `skills/qa-visual/SKILL.md` and `skills/qa-browser/SKILL.md` each shrink by **≥ 15%** from 803 and 663 lines respectively. This change must reverse the growth curve, not add to it.

**Persistence is orchestrator-owned**

13. No `skills/qa-*/SKILL.md` instructs the specialist to write a file: `rg -n 'Write to \`qaspec/' skills/qa-*/SKILL.md` returns **zero** matches.
14. `persistence-contract.md` contains a sole-writer section naming the orchestrator, and the preflight-cache rule distinguishes producer from writer.

**The linter catches the proven defect class**

15. `bash scripts/lint_skills.sh` exits `0` on the repository as delivered.
16. **Negative fixtures.** Three deliberately broken fixture files each make the linter exit `1`: one reintroducing `HAS_BLOCKERS` into a skill that declares it cannot emit them, one using an undefined `<evid>`, one using `{page-slug}` with no derivation. A linter that has not been shown to fail has not been shown to work.
17. `bash scripts/install_test.sh` exits `0`, and asserts that agents land at the declared target and that no installed agent grants `Write`.

**Distribution and docs**

18. A fresh install for a tool **without** `install_agents` still installs 12 skills and shows no error — skills-only remains a supported, complete configuration.
19. `README.md` documents the three layers with their owners, and no longer describes the squad as "7 Static + 2 Runtime".
20. `.atl/skill-registry.md` is regenerated and lists the agent layer.

---

## 5. Rollback plan

Required by `openspec/config.yaml`. Almost everything here is additive, which makes rollback cheap — with one exception that must not be skipped.

**Blast radius.** 11 new Markdown files, 1 new contract, 1 new shell library, 12 modified SKILL.md files, 7 modified contracts, 4 modified scripts, 8 `qase.json` files, 6 orchestrator documents, `README.md`, `.atl/skill-registry.md`. No binaries. No schema migrations. No persisted state format that outlives a review.

**Full rollback**

1. `git revert` the change's commit range (`git revert -m 1 <merge-sha>` if merged as a merge commit).
2. `git rm -r agents/` if the revert leaves untracked orphans, and delete `skills/_shared/qase/rule-ownership.md` and `scripts/lib/coherence.sh` if orphaned.
3. **Remove installed agent files from every install target** — `rm -f ~/.claude/agents/qa-*.md` and the equivalent for any other tool that declared `install_agents`. **This step is mandatory and is the only non-obvious one.** Reverting the repository does not uninstall previously distributed agents; an installed `qa-security` agent whose `tools:` no longer matches the reverted SKILL.md would run with a contract mismatch — a specialist without its contracts, which is exactly what the startup guard exists to prevent.
4. Run `bash scripts/lint_skills.sh` and `bash scripts/install_test.sh` — both must exit `0`.
5. Regenerate `.atl/skill-registry.md`.

**Partial rollback — the likely case.** The decisions are independently revertible by design:

- **Coherence linter too strict?** Revert `scripts/lib/coherence.sh` and its `source` line in `lint_skills.sh`. The agent layer and the de-duplication both survive; only the guard against regression is lost.
- **Sole-writer rule breaking openspec mode?** Restore `Write` to the affected agent and the `Write to qaspec/...` line in its SKILL.md. Two edits per specialist, and they are independent of each other.
- **A specific agent misrouting?** Agent files are instructions, not code. Correct the `description` in place; no rebuild, no reinstall of the skills layer.
- **Distribution problems for one tool?** Remove that tool's `install_agents` block. It falls back to skills-only, which criterion 18 proves still works.

**Non-rollbackable side effects.** None. This change creates no records in any external system and mutates no user data.

---

## 6. Risks and mitigations

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| R1 | **Scope size.** 12 agents + 12 SKILL.md + 7 contracts + 4 scripts + 8 JSON + 6 orchestrator docs + README + registry is far past the 400-line review budget | Unreviewable PR; the exact failure mode of the four previous rounds | Chained PRs. Natural slices: (1) `rule-ownership.md` + de-duplication of contracts; (2) 11 agent files; (3) SKILL.md persistence rewrite; (4) installer + linter + fixtures; (5) docs and registry. Each is independently verifiable |
| R2 | **De-duplication deletes a rule a reader needed locally**, and the specialist behaves worse without it | Silent quality regression that the linter will report as clean | Never delete silently: every removal leaves an explicit "owned by `<file>`" pointer. `agents/qa-security.md`'s existing mechanism applies — a specialist whose procedure conflicts with a shared contract reports the conflict as a WARNING rather than picking one |
| R3 | **Sole-writer rule lands before the orchestrator docs**, so reports are produced and never persisted | Silent artifact loss in `openspec` mode | Same-slice rule: the SKILL.md persistence rewrite and the orchestrator document update ship in one PR. `install_test.sh` asserts it |
| R4 | **Coherence linter false positives** on legitimate prose that happens to contain a registered string | CI blocked on a non-defect; the linter gets disabled and the guard is lost | Registry-driven with explicit literal strings, not heuristics or regex inference. Documented escape hatch: amend the registry deliberately, with the amendment visible in the diff |
| R5 | **`agents/` is Claude-Code-shaped**; six other toolchains gain nothing and could regress | "Works everywhere" becomes false — a promise regression, not a bug | Decision D makes agents opt-in per tool; criterion 18 proves skills-only still installs and runs |
| R6 | **A static reviewer later genuinely needs Bash** — `qa-test-strategy` executing a suite is the obvious candidate | Capability boundary blocks legitimate work; pressure to widen it globally | Stated assumption: `qa-test-strategy` analyses strategy and does not execute. If execution is needed it becomes a scoped, argued amendment to one agent, not a blanket grant |
| R7 | **The `description` field is the routing mechanism.** A weak description means the orchestrator never selects the agent | Specialist silently never runs; review looks clean because nobody looked | Descriptions derived from the existing skill `description` and registry entries; linter asserts non-empty and that it names the trigger condition |
| R8 | **New duplication is introduced after this change** by any future edit | Round five | That is precisely what the registry-driven linter exists to prevent; `openspec/config.yaml` already requires `lint_skills.sh` in the verify phase |
| R9 | **Twelve isolated agents cost more tokens** than one shared context | Higher per-review cost | Accepted deliberately. §1 shows the shared context misses defects an isolated one finds. Independence is the product; the cost is the price of the product |

---

## 7. Non-goals

- **Not routing the runtime specialists.** Making `qa-scan` activate `qa-browser` and `qa-visual` is out of scope. `routing-rules.md:96-106` declares them out-of-band, which is why `/qa-review --pr 42` never opens a browser. It is a real gap and it is the **next change**, not this one.
- **Not a semantic change to severity, veto, or oracle tiers.** Rules move; they do not change meaning. A rule whose text must change to be de-duplicated is a finding for the design phase, not a licence to rewrite it.
- **Not a migration of skills into agents.** The skills remain the distributable product. The agent layer is additive.
- **Not new specialists, commands, or scopes.** The squad is the same twelve.
- **Not CI wiring.** The linter must run and must fail correctly; where it runs is a separate decision.
- **Not a model-selection pass.** Each agent inherits the model its skill implies; re-tuning is out of scope.
- **Not an uninstaller.** Rollback step 3 is documented manual cleanup, not a new script.

---

## 8. Assumptions stated plainly

1. **`mem_save` survives the sole-writer rule** (Decision B item 1). If the user intends literally zero persistence by specialists, the engram path changes materially and the spec must be told before it is written.
2. **`qa-test-strategy` does not execute tests**, so it needs no Bash. If it must run a suite, that is a scoped amendment, not a reason to relax the static-reviewer boundary.
3. **`examples/mock-tool/` is a test fixture**, not a shipped toolchain.
4. **Claude Code is the only host with a native agents directory today.** Others get skills only until they declare `install_agents`.
5. **The 12 skills are the complete set** for this change. `qa-scan`, `qa-report`, `qa-init`, and `qa-feedback` get agents too, even though they are pipeline roles rather than reviewers, because a pipeline role without a capability boundary is the same hole.
6. **Existing `veto_power:` frontmatter stays.** It is a declaration, not a restatement, and `runtime-proof-e2e` criterion 3 depends on it.

---

## 9. Proposal question round

The brief made the load-bearing decisions and this proposal does not hand them back. These are confirm-or-correct checks on the judgement calls that would be expensive to reverse after spec. Silence means the proposal stands as written.

1. **`mem_save` and the sole-writer rule (Assumption 1).** This proposal reads "specialists MUST NOT persist their own artifacts" as a filesystem rule and keeps `mem_save` on every specialist, matching the approved `agents/qa-security.md`. The alternative — orchestrator-only persistence in both modes — is cleaner but routes 12 full reports through the orchestrator's context. Confirm the filesystem-only reading, or extend it to engram?
2. **`qa-report`'s capability boundary.** The brief says `qa-report` only aggregates, so it receives no Bash and, under Decision B, no `Write`. But `qa-report` is the consensus engine and the producer of the final report and the SDD bridge `actionable-issues` artifact. Confirm it also returns rather than writes, making the orchestrator the writer of the final report as well?
3. **Slice boundary for the first PR (R1).** The proposal recommends de-duplicating the shared contracts first, before authoring the eleven agents, so the agents are written against contracts that already hold the single source of truth. The alternative is agents first, for visible progress. Which order?

---

## 10. Capabilities

> Contract between this proposal and `sdd-spec`.

### New Capabilities

- `agent-layer`: the twelve `agents/qa-*.md` files — thin-agent structure, frontmatter contract, `tools` capability classes, routing `description`, startup guard, result contract.
- `rule-ownership`: `skills/_shared/qase/rule-ownership.md` — the canonical owner registry and the reference-not-restate discipline.
- `coherence-lint`: forbidden-token, undefined-placeholder, single-source, and agent/skill bijection checks, plus the negative fixtures that prove them.

### Modified Capabilities

- `infra`: the installer must discover and distribute `agents/` via optional per-tool `install_agents` paths, and `install_test.sh` must assert it.
- `docs`: `README.md` must document the three layers and stop describing the squad as "7 Static + 2 Runtime".

---

## 11. Next phases

- `sdd-spec` — Given/When/Then scenarios with RFC 2119 keywords for: the thin-agent structure contract, the `tools` capability classes per specialist, the sole-writer persistence rule and its producer/writer split, the rule-ownership registry format, and each coherence check including its negative fixture.
- `sdd-design` — the rule-ownership registry schema, the linter's check pipeline and its `scripts/lib/` module boundary, the installer's agent-discovery flow (sequence diagram, per `openspec/config.yaml`), and architecture decision records for A–D.

Both depend only on this proposal and can run in parallel.
