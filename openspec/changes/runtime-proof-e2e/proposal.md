# Proposal: runtime-proof-e2e

**Change**: `runtime-proof-e2e`
**Phase**: proposal
**Input**: `openspec/changes/runtime-proof-e2e/exploration.md`
**Status**: ready for spec and design

---

## 1. Why

### The business problem

QASE exists to stop broken work from reaching a human. It currently fails at that job in a specific, repeatable way: **it produces confident static opinions that pass review while the delivered feature does not actually work.**

The lived failure is not hypothetical. SDD-delivered work passes a QASE review, the verdict says APPROVE, and then a human opens the feature and it breaks. The review was not wrong about the code it read — it simply never ran the thing.

Three structural facts cause this:

1. **Ten of twelve specialists never execute anything.** They read source with Read/Grep and reason about it. Reasoning about source cannot detect that a validation rule the code declares is never reached at runtime, that a button throws on click, or that an API failure produces a blank screen.
2. **The two specialists that do execute have no authority.** `skills/qa-browser/SKILL.md:12` and `skills/qa-visual/SKILL.md:13` are both `veto_power: false`.
3. **The two specialists that can block delivery never execute anything.** `veto_power: true` appears only in `skills/qa-security/SKILL.md:13` and `skills/qa-architect/SKILL.md:12`.

That is an inverted authority model: **unexecuted opinion can block delivery; executed evidence cannot.** Every incentive in the current design points reviewers toward the cheapest, least grounded form of judgment.

### What "reliability of delivered work" means here

The cost is not tooling elegance. It is that a QASE APPROVE currently carries an unknown amount of information. A user cannot distinguish "we ran the login flow and it worked" from "we read the login component and it looked fine", because the report format does not record the difference. Trust in the verdict degrades to trust in the model's mood that day.

The fix is to make every runtime verdict a **proof**: a step-by-step record of what was clicked, what was observed, what was expected, and **where that expectation came from**. An expectation without a stated source is an opinion. An expectation with a cited source is evidence.

### Why now

- `qa-browser` and `qa-visual` are already pinned to Chrome DevTools MCP tool names that are being replaced. The backend has to move regardless; doing the authority and evidence work in the same slice avoids touching these files twice.
- `agent-browser@0.32.2` is installed on the reference machine and ships a version-matched usage guide, so command correctness is verifiable today rather than guessed.
- QASE is being used on real SDD deliveries now. Every review shipped under the current model spends trust the framework has not earned.

### Why it must work on any project

QASE is not an internal tool for one repo. It must produce grounded verdicts on a project with no SDD change, no test suite, and no QASE history. A verification model that only works when an `openspec/` spec exists is a model that works on almost nothing. That constraint is what forces the tiered oracle below, and specifically **L3 (code contract)**, which is available always.

---

## 2. What changes

QASE gains the ability to **execute a real user flow and report tier-attributed evidence for every step**, and that evidence gains the authority to block delivery when — and only when — it rests on a strong oracle.

### In scope (first slice)

1. **Runtime backend migration.** `qa-browser` and `qa-visual` drop every Chrome DevTools MCP tool reference and drive `agent-browser` through the CLI via Bash. Chrome DevTools MCP is removed as a QASE dependency. The agent-browser **MCP `core` tools profile is explicitly not a supported backend** — it is a curated subset and lacks network, state, and debug capabilities this change depends on.
2. **End-to-end user-flow verification** with the step-by-step flow evidence format (action / observed / expected / oracle tier / status / artifact) as the primary deliverable of a runtime review.
3. **The 4-tier oracle contract** in a new `skills/_shared/qase/oracle-contract.md`, threaded into severity, issue format, and persistence.
4. **Tier-gated veto power** for the runtime flow specialist (Decision A).
5. **`qa-init` runtime preflight** that proves browser connectivity rather than presence, and caches the result.
6. **Authenticated flow support** via named sessions and state restore, so protected pages are testable and repeatable.
7. **Network interception** (`network route --abort` / `--body`) so failure hypotheses become executable rather than argued.
8. **Per-step console and error capture**, with buffers cleared between steps so every step owns its own diagnostics.
9. **Video and HAR evidence** for the flow as a whole.
10. **Test-data and dirty-state policy** for write flows (Decision D).

### Explicitly deferred — do not design these

- API / endpoint contract testing as a standalone capability
- Database / SQL verification
- Live endpoint probing as an L3 source (exploration Approach C) — it overlaps deferred API testing and has side effects
- Extraction of a separate `qa-flow` skill (Decision B records the trigger for revisiting this)
- React DevTools integration (`react tree|inspect|renders|suspense`)
- React DevTools deep integration beyond what the migration already covers

### Affected modules

All changes are Markdown. No shell scripts, no binaries, no infrastructure.

| File | Change |
|------|--------|
| `skills/qa-browser/SKILL.md` | Primary target. Replace all MCP tool references with agent-browser CLI commands; add flow-evidence execution and reporting; add network interception; add session/auth handling; per-step console+errors capture; oracle tier on every finding; `veto_power: true` (tier-gated) |
| `skills/qa-visual/SKILL.md` | Replace MCP tool references with CLI equivalents; adopt `vitals --json`; oracle tier on every finding; remains `veto_power: false` |
| `skills/qa-init/SKILL.md` | New final step before the return summary: **Runtime Preflight (Browser Backend)** — detect, smoke-test, cache; plus start-command hint detection (suggest, never execute) |
| `skills/_shared/qase/oracle-contract.md` | **NEW.** Defines L1–L4, how each tier is populated, evidence-citation requirements, degradation rules, and the blocking matrix |
| `skills/_shared/qase/severity-contract.md` | New "Oracle Tier and Verdict" section; veto table gains a tier-scoped entry for `qa-browser` |
| `skills/_shared/qase/issue-format.md` | Add `Oracle Tier` field to the Browser Testing and Visual Testing variants; add `oracle_tier_breakdown` to the metadata envelope |
| `skills/_shared/qase/persistence-contract.md` | Add the runtime preflight cache schema and resolution rules |
| `skills/_shared/qase/engram-convention.md` | Add `flow-evidence` and `preflight-cache` artifact types |
| `skills/_shared/qase/openspec-convention.md` | Add `qaspec/reviews/{review-id}/flow-evidence/{flow-slug}.md` and `qaspec/preflight-cache.yaml` |
| `skills/_shared/qase/routing-rules.md` | Oracle-tier-aware routing for the runtime specialists |
| `.atl/skill-registry.md` | Regenerate — `qa-browser` and `qa-visual` descriptions currently say "via Chrome DevTools MCP" (lines 92 and 101) and will be stale |

`README.md` will also need its runtime-specialist and MCP-prerequisite sections corrected (added in commit `a99fc67`), since Chrome DevTools MCP stops being a prerequisite.

---

## 3. The four decisions

### Decision A — Veto power: grant it, tier-gated

**Decision: option (a). `qa-browser` becomes `veto_power: true`, and its veto is scoped in `severity-contract.md` to findings whose Oracle Tier is L1, L2, or L3-schema.**

Rationale:

- The inversion in the frontmatter **is** the problem statement. `veto_power: false` on the only skill that executes anything is the machine-readable form of "we do not trust what we observed". Leaving it in place while claiming the change fixes authority would be cosmetic.
- `qa-report` Step 3 is literally named "Apply Veto Logic" and reads the veto table. Routing authority through severity alone (option b) means the consensus engine still classifies executed L1 failures as overridable-by-consensus. A flow that provably does not complete should not be outvoted by static agents that read the same code and liked it.
- The danger of a blanket veto — a flaky selector or an L4 heuristic taking down a release — is removed by the gate, not by withholding the flag. **A tier gate is a stronger safety property than a false flag**, because it is stated in the contract and auditable per finding rather than being an all-or-nothing switch.
- Cost of being wrong is bounded and reversible: it is one YAML line plus one table row.

Concrete shape:

- `skills/qa-browser/SKILL.md` frontmatter: `veto_power: true`
- `skills/_shared/qase/severity-contract.md` veto table gains a row whose **Veto Scope** column reads, in substance: *BLOCKERs carrying Oracle Tier L1, L2, or L3-schema only. Findings at L3-inferred or L4 never carry veto and never produce BLOCKER.*
- Both places MUST be changed in the same commit. The spec phase must state this as an invariant, and `sdd-verify` must check it.
- `qa-visual` stays `veto_power: false`. Its findings are overwhelmingly L4 (contrast ratios, spacing, motion heuristics) and it does not execute flows. Granting it veto would grant an authority it cannot ground.

Rejected — option (b), escalate via severity rules only:

- Cheaper and lower-risk, and it does produce REJECT on L1/L2 failures.
- Rejected because it leaves the metadata lying. A reader, an orchestrator, or a future contributor inspecting frontmatter would still see the runtime specialist marked as non-authoritative, and `qa-report`'s override path would still treat executed evidence as second-class. It fixes the symptom in one file and preserves the cause in another.

Rejected — grant veto to all runtime skills:

- Rejected because `qa-visual` has no oracle strong enough to justify it, and blanket grants are exactly the unexamined authority this change is correcting.

### Decision B — Skill topology: extend `qa-browser` in place

**Decision: Option A. Flow evidence, network interception, session management, and oracle tiers land inside `skills/qa-browser/SKILL.md`. No `qa-flow` skill in this slice.**

Rationale:

- `qa-browser` already has **Step 9: User Flow Testing** (`skills/qa-browser/SKILL.md:244`). The capability is not new territory; it is currently a stub that "executes the action" and "verifies step completed" with no oracle and no evidence record. This change fills in a section that already exists and already has the right name.
- This slice already changes the browser backend, introduces a new shared contract, rewires severity and veto, and adds a preflight to `qa-init`. Adding a new skill on top of that means new routing rules, a new registry entry, a new issue-format variant, new engram topic keys, and a second orchestrator command surface — all landing simultaneously with a backend migration. That is how a slice becomes unreviewable.
- Weighed against Decision A, extending in place is also the **smaller** authority change: it moves one existing agent from non-veto to tier-gated veto, rather than introducing a brand-new veto-holding agent into a consensus engine that has only ever had two.
- The tier gate does most of the separation-of-concerns work that Option B was reaching for. Passive inspection (accessibility, CWV, responsive) is L4 and advisory by construction; active flow execution is L1–L3 and authoritative. The split is enforced by the oracle contract rather than by file boundaries.

Rejected — Option B, new `qa-flow` skill:

- Genuinely cleaner conceptually, and the earlier exploration pass was right that mixing passive inspection with active flow execution in one file is a smell.
- Rejected **for this slice only**, on sequencing grounds: it multiplies the surface at the exact moment three other contracts are changing underneath it.

Rejected — Option C, split and rename:

- Breaking change to orchestrator commands and engram topic keys, for conceptual clarity that Option B already delivers at lower cost.

**Extraction trigger (committed, not vague).** `qa-flow` will be extracted in a later change when **any** of these becomes true:

1. `skills/qa-browser/SKILL.md` exceeds ~600 lines (it is 370 today);
2. flow execution needs to be invocable independently of runtime health inspection;
3. deferred API/DB verification lands and needs an oracle-bearing host that is not browser-shaped.

Recording the trigger is what makes this a deferral rather than a decision to never revisit.

### Decision C — L3 extraction: confirmed, with three tightenings

**Decision: confirm schema-first (Approach A) as primary, static-pattern (Approach B) as fallback, annotated `L3-schema` versus `L3-inferred`, with `L3-inferred` capped at WARNING.** Three additions:

1. **Citation is mandatory for `L3-schema`.** A finding may claim `L3-schema` only if it cites file path, line, and the literal contract text (for example: `src/schemas/auth.ts:14` — `z.string().email({ message: "Invalid email address" })`). **A finding claiming `L3-schema` without a citation is downgraded to `L3-inferred`** and therefore loses its ability to BLOCK. This turns the tier from a self-declared label into a checkable claim, and it is the single mechanism that prevents tier inflation from restoring the "confident opinion" failure mode in new clothes.
2. **`L3-inferred` needs corroboration.** A pattern-derived contract must be supported by at least two independent signals (for example a validation regex *and* a matching error-message literal on the same path). A single unsupported pattern match drops to L4. This targets the dead-code and feature-flag false positives that Approach B is known to produce.
3. **Absence must be stated, not implied.** When no L3 source exists for a step, the finding falls to L4 **and the evidence record says so explicitly** ("no code contract found for this path"). Silent degradation is how a weak oracle gets mistaken for a strong one.

Rejected — Approach C, live endpoint probing:

- Ground truth and always current, but requires the app running for oracle *construction* (not just verification), has side effects on POST, is blocked by auth, and overlaps the deferred API/endpoint testing scope. Deferred, not discarded.

Rejected — pattern extraction as primary:

- Works on every codebase, which is seductive given the universality constraint. Rejected because its false-positive profile is exactly what erodes trust, and trust is the thing this change is buying back. Schemas are unambiguous; patterns are guesses with good posture.

### Decision D — Test data and dirty state: unique identities, opt-in writes, visible ledger

**Decision: Strategy A (unique generated identities) is the mandatory default for any write flow. Strategy B (`--session` isolation) handles client-side state. Strategy C (teardown hook) is used only when `qa-init` detected one. Write flows are opt-in and never run against production.**

Concretely:

1. **Unique identities are mandatory, not optional**, for any flow that creates a record: `qase+{epoch}-{short-random}@example.com` and equivalent for other identity fields. This is what makes run 2 of a signup flow produce the same verdict as run 1. Without it, a second run reports "email already exists" as a product defect — a false BLOCKER, which under Decision A now carries veto weight. **Decision A makes Decision D load-bearing rather than housekeeping.**
2. **Named sessions isolate client state** — cookies, localStorage, sessionStorage, IndexedDB, tabs — per run. Session ids are derived stably rather than hand-built. Sessions do **not** isolate server-side database state, and the contract must say so plainly so nobody mistakes session isolation for cleanup.
3. **Teardown is opportunistic.** `qa-init` records a cleanup endpoint or command if it detects one; `qa-browser` invokes it only when recorded. QASE will not invent cleanup, will not run migrations, and will not truncate tables. Mutating a user's data store to tidy up after itself is outside the mandate, exactly as auto-starting the user's app is.
4. **Write flows are opt-in.** `qa-browser` executes a write flow only when the orchestrator passed it explicitly as a flow. It never discovers a signup form and decides to exercise it. This extends the existing safety rules at `skills/qa-browser/SKILL.md:350-358`, which already forbid destructive clicks and payment submission.
5. **Production is read-only.** When the target URL is identified as production, write flows are refused and reported as SKIPPED with a reason, not silently omitted.
6. **The dirty state is visible.** Each flow evidence document carries a **Test Data Ledger** listing every identity and record the run created. Accumulation is a documented, inspectable limitation rather than an invisible one.

Rejected — session isolation alone:

- It is the tidy answer and it is wrong: it isolates the browser, not the database. Presenting it as the dirty-state solution would create precisely the silent false-positive class this decision exists to prevent.

Rejected — mandatory teardown:

- Would make write-flow verification impossible on the majority of projects, which expose no cleanup endpoint. Universality (the L3 constraint) applies here too.

---

## 4. Runtime preflight: prove connectivity, not presence

An installed-but-broken browser is the failure mode that silently turns runtime QA back into static opinion. The preflight exists to make that failure loud.

**Correction to the exploration.** The exploration specified hand-rolled Chrome binary probing (`chromium`, `google-chrome-stable`, `google-chrome`, `chrome`) as the detection mechanism. The version-matched guide documents a purpose-built command that supersedes it:

```
agent-browser doctor --json        # env, Chrome, daemons, config, providers, network, launch test
agent-browser doctor --offline --quick
agent-browser doctor --fix         # destructive repairs, requires explicit opt-in
```

`doctor` exits `0` when all checks pass (warnings acceptable) and `1` when any check fails, and it auto-cleans stale socket/pid/version sidecar files. It covers binary discovery, daemon health, and an actual launch test in one call.

Preflight order:

1. `agent-browser --version` — presence and version string. Absent → record unavailable and surface install instructions (`npm i -g agent-browser && agent-browser install`; Linux hosts may need `agent-browser install --with-deps`). **Never install without the user's consent.**
2. `agent-browser doctor --json` — authoritative health and connectivity check. This replaces manual binary probing as the primary mechanism.
3. Manual multi-name Chrome probing is retained **only as a fallback diagnostic** when `doctor` is unavailable or its output cannot be parsed. The exploration's warning stands and stays in the contract: `google-chrome` is ABSENT on the reference machine while `chromium` and `google-chrome-stable` are present, so probing a single name yields a false negative on working environments.
4. Real smoke connection — open a trivial page and close it — because a passing `doctor` still does not prove this agent, in this sandbox, can drive a page.
5. **Bash availability check.** agent-browser is CLI-driven. An executor without a Bash tool cannot run any of it, and must record `runtime_available: false` with that reason rather than reporting a browser failure. This exploration itself hit that limit.
6. Persist the cache to the active artifact store (`qaspec/preflight-cache.yaml` or topic key `qa-init/{project}/preflight`), including which mechanism produced the result.

App start commands are **detected and suggested, never executed.** Starting a user's application is a side effect outside the agent's mandate — the same principle as refusing to truncate their database.

---

## 5. Command-correctness discipline

Every agent-browser command written into a skill file MUST be verified against the version-matched guide at
`/home/devgio/.local/share/mise/installs/node/25.9.0/lib/node_modules/agent-browser/skill-data/core`
(`SKILL.md` plus `references/`, ~2649 lines) before it is committed. This is a hard requirement on the spec, design, and apply phases, and `sdd-verify` must check it.

The following corrections were found while writing this proposal and MUST be carried into the spec — the exploration contains all of them in wrong form:

| Wrong (in circulation) | Correct (verified) | Note |
|---|---|---|
| `wait networkidle` | `wait --load networkidle` | The original error this discipline exists to prevent |
| `agent-browser open --session qa-auth --restore <url>` | `agent-browser --session "$S" --restore open <url>` | `--session` and `--restore` are **global** flags and precede the subcommand |
| hand-built session names | `S="$(agent-browser session id --scope worktree --prefix qase)"` | Documented recommendation for agent skills; `--scope worktree` suits parallel agent runs |
| ~~`cookies get` is invalid~~ | `cookies get` IS valid (and is the default operation) | **This correction was itself wrong** — verified via `agent-browser cookies --help`: operations are `get` (default), `set <name> <value> [options]`, `clear` |
| `set media reduced-motion` | `set media dark` / `set media light reduced-motion` | Documented forms pair a scheme with the motion flag |
| inline `eval "<complex js>"` | `eval --stdin` (heredoc) or `eval -b <base64>` | Inline works only for simple expressions; relevant to axe-core injection and viewport checks |

Additional capabilities confirmed in the guide and available to the spec: `errors` / `errors --clear`, `console --clear`, `network har start` / `network har stop <path>`, `record start <file>` / `record stop`, `vitals [url] [--json]`, `batch` for one-turn pre-navigation staging, `--restore-save auto` (default; skips autosave after a failed restore), `--restore-check-url|--restore-check-text|--restore-check-fn` for validating a restored session, and `--allowed-domains` for browser-level navigation containment — which maps directly onto QASE's existing "never leave the origin" safety rule.

---

## 6. Success criteria

Observable and checkable. Not aspirational.

**Contract integrity**

1. `bash scripts/lint_skills.sh` exits `0`. Every touched skill retains its frontmatter delimiters, `name`/`description`/`license` fields, the four required sections, and its `persistence-contract.md` reference.
2. `bash scripts/install_test.sh` exits `0`.
3. `rg -n "veto_power: true" skills/` returns exactly three matches: `qa-security`, `qa-architect`, `qa-browser`. Any other count is a failure.
4. The `qa-browser` veto entry exists in `severity-contract.md` and its scope text names L1, L2, and L3-schema and excludes L3-inferred and L4. Frontmatter and table agree.

**MCP removal is complete**

5. `rg -n "navigate_page|take_snapshot|take_screenshot|evaluate_script|wait_for|resize_page|list_console_messages|list_network_requests|get_network_request|get_console_message|performance_start_trace|performance_stop_trace|performance_analyze_insight|emulate\(" skills/` returns **zero** matches.
6. `rg -ni "chrome devtools mcp" skills/ README.md .atl/skill-registry.md` returns **zero** matches.

**Command correctness**

7. `rg -n "wait networkidle" skills/` returns zero matches, and every `agent-browser wait --load` usage names one of `load`, `domcontentloaded`, `networkidle`.
8. Every `agent-browser` command string in the touched skill files appears in the version-matched guide, with flag order matching (global flags before the subcommand). The verify phase enumerates them and checks each.

**Oracle model is threaded end to end**

9. `skills/_shared/qase/oracle-contract.md` exists and defines L1, L2, L3-schema, L3-inferred, and L4, with a blocking matrix and the citation requirement from Decision C.
10. `issue-format.md` Browser and Visual variants both carry an `Oracle Tier` field, and the metadata envelope carries `oracle_tier_breakdown`.
11. `severity-contract.md` states that L4 never produces BLOCKER and L3-inferred caps at WARNING.
12. All five other shared contracts (`persistence`, `engram`, `openspec`, `routing`, `severity`) reference the oracle contract — no orphaned file.

**Behavioural, on a real target**

13. On a running application, `qa-browser` produces a flow evidence document in which **every** step records action, observed, expected, oracle tier, status, and at least one artifact path. A step missing any field is a failure.
14. Running the same write flow twice in a row produces the same verdict both times (unique-identity policy holds). A run-2 "already exists" BLOCKER is a failure of this change.
15. An intentionally aborted API route (`network route "**/api/..." --abort`) produces a finding with a stated tier, and the tier is L4 unless a spec or code contract covers the failure path.
16. On a project with **no** `openspec/` directory and **no** test suite, a runtime review still produces at least one L3 or L4 finding with a stated oracle. This is the universality criterion — if it fails, the change did not achieve its purpose.
17. With agent-browser absent or Bash unavailable, `qa-init` reports `runtime_available: false` with a specific reason and `qa-browser` refuses to fabricate runtime findings. A silent fallback to static opinion is the exact regression this change exists to prevent.

---

## 7. Rollback plan

Required by `openspec/config.yaml`. Rollback is cheap by construction.

**Blast radius.** Every change is Markdown: nine existing `.md` files, one new `.md` file, plus `README.md` and the regenerated `.atl/skill-registry.md`. No changes to `scripts/install.sh`, `scripts/install_test.sh`, or `scripts/lint_skills.sh`. No binaries, no schema migrations, no persisted state format that outlives a review. The linter discovers skills dynamically via `skills/qa-*/`, so nothing needs registration.

**Full rollback.**

1. `git revert` the change's commit range (or `git revert -m 1 <merge-sha>` if merged as a merge commit). Markdown-only means no conflicts outside the touched files.
2. Run `bash scripts/lint_skills.sh` and `bash scripts/install_test.sh` — both must exit `0`.
3. Delete `skills/_shared/qase/oracle-contract.md` if the revert leaves it behind as an untracked orphan.
4. Regenerate `.atl/skill-registry.md`.
5. Purge stale preflight artifacts: remove `qaspec/preflight-cache.yaml`, and in engram mode the `qa-init/{project}/preflight` topic. Stale caches are the only cross-run state this change introduces.
6. Reinstate Chrome DevTools MCP as a prerequisite in `README.md` if it was removed there.

**Partial rollback — the likely case.** The decisions are independently revertible, which is deliberate:

- **Veto too aggressive?** Revert `veto_power: true` in `skills/qa-browser/SKILL.md` and its row in `severity-contract.md`. Two lines. Flow evidence, oracle tiers, and the CLI migration all keep working; the runtime specialist simply returns to advisory. This is the escape hatch for Decision A, and it is why Decision A is a safe bet rather than a gamble.
- **L3 too noisy?** Tighten `oracle-contract.md` so `L3-inferred` caps at INFO instead of WARNING, or disable Approach B entirely and let L3 mean schema-only. One file.
- **Write flows causing trouble?** Set write flows to refused-by-default in `qa-browser`. Read-only flows keep producing evidence.
- **A specific agent-browser command misbehaving?** Skill files are instructions, not code. Remove or correct the command in place; no rebuild, no reinstall.

**Non-rollbackable side effects.** Test records created in a target application by write flows are not removed by reverting QASE. This is why the Test Data Ledger in Decision D is mandatory — it is the record a human uses to clean up manually.

---

## 8. Risks and mitigations

| # | Risk | Impact | Mitigation |
|---|------|--------|------------|
| R1 | **Bash is mandatory.** agent-browser is CLI-driven; an executor without Bash cannot run any of it | Runtime QA silently degrades to static opinion — the original failure | Preflight step 5 checks Bash explicitly and records `runtime_available: false` with that reason. Success criterion 17 forbids fabricated runtime findings |
| R2 | **Tier inflation.** A model labels a guess `L3-schema` to reach BLOCKER, restoring confident opinion in new clothes | Defeats the entire change | Decision C citation requirement: no file/line/literal → automatic downgrade to `L3-inferred` → cannot BLOCK. Checkable by a reviewer, not just by the author |
| R3 | **False-positive BLOCKER now carries veto** (consequence of Decision A) | A flaky selector could block a release | Tier gate excludes L4 and L3-inferred entirely; L1/L2 require an actual spec scenario or an executed test; Decision D removes the dirty-state false-positive class; two-line rollback available |
| R4 | **Chrome binary name variability.** `google-chrome` absent while `chromium` and `google-chrome-stable` present | False "not found" on working environments | `doctor --json` as primary detection; multi-name probing retained only as fallback; smoke connection is the final authority |
| R5 | **Dirty state from write flows.** Unique identities prevent collisions but data accumulates | Target app fills with test records | Documented as a known limitation; Test Data Ledger makes it visible and cleanable; teardown hook used when detected; production refused outright |
| R6 | **L3 oracle quality varies by project.** No schemas, stale docs, i18n-keyed messages | L3 silently weak on some projects | Explicit "no code contract found" declaration (Decision C item 3); graceful, stated degradation to L4 |
| R7 | ~~`diff screenshot --baseline` is unverified~~ — **RESOLVED, risk withdrawn.** Verified via `agent-browser diff --help`: `diff screenshot --baseline <file>` exists, as do `diff snapshot [-b <file>] [-s <sel>] [-c] [-d <n>]` and `diff url <u1> <u2>` | None — the command exists. Visual baseline regression is **in scope**, not conditional | **Standing lesson**: the version-matched core guide (`skills get core --full`) is NOT exhaustive — `diff` is absent from it yet present in the CLI. Per-subcommand `--help` is the most complete source of truth. Verify commands there, not only in the guide |
| R8 | **Daemon lifecycle.** The agent-browser daemon persists between calls but may time out on long sessions | Mid-flow failure misread as an application defect | Skills must detect connection loss, reconnect, and mark the step INCONCLUSIVE rather than FAIL. `doctor` auto-cleans stale sidecar files |
| R9 | **`qa-browser` SKILL.md grows unwieldy** (consequence of Decision B) | Maintenance and comprehension cost | Explicit extraction trigger recorded in Decision B (~600 lines / independent invocability / non-browser oracle host) |
| R10 | **Evidence volume.** Video, HAR, per-step screenshots and console dumps per flow | Artifact bloat, token cost | Tie artifact capture to the existing depth controls (`concise` / `standard` / `deep`); video and HAR only at `deep` or on explicit request |
| R11 | **`qa-report` consensus logic assumes two veto agents** | A third veto holder could produce unexpected verdict behaviour | The spec must state `qa-report` Step 3 behaviour with a tier-gated veto holder explicitly; success criterion 3 pins the exact count |

---

## 9. Non-goals

- **Not a test-authoring tool.** QASE does not write tests into the target project. L2 means *executing the project's existing suite and reading its result*, nothing more.
- **Not a fixer.** QASE reports; it does not patch the target application.
- **Not an app runner.** `qa-init` suggests a start command and never executes it.
- **Not a database janitor.** No migrations, no truncation, no seed scripts.
- **Not a replacement for the static specialists.** The ten static skills stay. This change adds a grounded floor beneath them; it does not claim runtime evidence subsumes architectural or security review.
- **Not a performance-testing framework.** `vitals` gives Core Web Vitals for a page. Load testing, soak testing, and stress testing are out of scope permanently.
- **Not a general browser-automation product.** QASE drives agent-browser for verification only. Scraping, RPA, and workflow automation are not use cases.
- **Not a Chrome DevTools MCP compatibility layer.** MCP support is removed, not abstracted behind an adapter. Two backends means two sets of command bugs.

---

## 10. Assumptions stated plainly

Where the exploration or this proposal had to assume rather than verify, the assumption is named here so it can be corrected rather than inherited silently.

1. **agent-browser stays at 0.32.x for this change.** Command syntax is verified against the guide shipped with the installed version. A major upgrade mid-change invalidates the verification and requires a re-check pass.
2. **The executor running `qa-browser` has a Bash tool.** Enforced by preflight rather than assumed, but if the common case turns out to be Bash-less executors, the whole approach needs revisiting before spec.
3. **L1 means an SDD spec in `openspec/changes/*/specs/**/*.md`.** Other spec formats (Gherkin feature files, Cucumber, standalone acceptance docs) are not L1 sources in this slice.
4. **L2 means the project's own test runner, executed, with its output read.** Not "tests exist"; not "tests look thorough".
5. **Reviews are single-run.** No flake-detection by re-running a failing step N times. If flakiness proves material under Decision A's veto, retry policy becomes a follow-up change.
6. **Flow definitions come from the orchestrator.** `qa-browser` does not autonomously discover and invent user flows in this slice; discovery-driven flow generation is a later question.

---

## 11. Proposal question round

The four assigned decisions are made above and are not being handed back. These are confirm-or-correct checks on judgement calls that shape scope, plus the assumptions most likely to be wrong. Answering is optional; silence means the proposal stands as written.

1. **Veto blast radius (Decision A).** Tier-gated veto means an L1 or L3-schema flow failure forces REJECT and requires explicit acknowledgment to override — including on a change where every static specialist approved. Is that the intended level of authority for run-1 of a new capability, or should the first slice ship veto-capable but flagged off, and be enabled after a few real reviews?
2. **Write flows and real applications (Decision D).** Write flows create real records that reverting QASE cannot undo. Is opt-in-per-flow plus a Test Data Ledger the right default, or should the first slice restrict runtime verification to read-only flows entirely and add writes once the evidence format has proven itself?
3. **`qa-visual` scope.** This proposal keeps `qa-visual` at `veto_power: false` and gives it the CLI migration plus oracle tiers, but no flow execution. Is that the right split, or should `qa-visual` be limited to the backend migration only in this slice, deferring its oracle threading?

---

## 12. Next phases

- `sdd-spec` — Given/When/Then scenarios with RFC 2119 keywords for the oracle contract, the preflight, the flow evidence format, and the veto gate. **Must** verify every agent-browser command via per-subcommand `--help` (e.g. `agent-browser diff --help`) before writing it. The version-matched core guide is a useful companion but is NOT exhaustive — two commands in this change were wrongly declared nonexistent because only the guide was consulted.
- `sdd-design` — sequence diagrams for the preflight flow and the flow-execution loop (including console/error buffer clearing and daemon reconnection), plus architecture decision records for A–D.

These two can run in parallel; both depend only on this proposal.
