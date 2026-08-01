# Verification Report — three-layer-architecture

**Change**: `three-layer-architecture`
**Mode**: openspec (+ engram mirror)
**Date**: 2026-07-31
**Mandate**: adversarial. Apply's "42/42 complete" was treated as unproven.
**Verdict**: **FAIL** — 6 CRITICAL, 10 WARNING, 6 SUGGESTION

---

## Executive summary

The architecture is real, not cosmetic. Rule de-duplication genuinely landed, and the coherence
linter genuinely detects: 7 of its 8 checks fired on fresh, never-before-seen violations across an
11-mutation battery. But three things did not land, and one test harness proves less than it claims:

1. The **positive** direction of `coherence_test.sh` is a vacuous assertion — the fixture it calls
   "clean" actually produces 4 FAILs.
2. The **ADR-E′ probe branch table** (P0–P6, including the multi-name Chrome fallback) was deleted
   from `qa-init/SKILL.md` and landed in **zero** orchestrator documents.
3. The **ADR-F diff-resolution mapping** was deleted from `qa-scan/SKILL.md` and landed in **zero**
   orchestrator documents.
4. `skills/qa-report/SKILL.md:229` still instructs the specialist to `mem_save` a review-artifact
   key, contradicting Step 8 of the same file and `engram-convention.md:77`.

---

## Completeness

| Dimension | Result |
|---|---|
| Tasks marked complete in `tasks.md` | 56 `### [x]` headings, 0 unchecked |
| apply-progress claim | 42/42 complete |
| Tasks verified as genuinely done | Most; see CRITICAL-2/3/4 and WARNING-8 for tasks marked done whose deliverable is absent |
| Specs read | all 6 + `design.md` + `proposal.md` |

---

## Runtime evidence

All commands run by this verifier in this session (isolated copies under `/tmp`, working tree not
mutated; one stray `./.vscode` created by the vscode install probe was removed).

### Baseline (independent re-run, isolated copy)

```
$ cd /tmp/qase-verify && bash scripts/lint_skills.sh
  PASS: 118, FAIL: 0, WARN: 0
RESULT: ALL PASSED
EXIT=0
```

```
$ bash scripts/install_test.sh
  PASS: 15, FAIL: 0
RESULT: ALL PASSED
```

### Mutation battery — does the linter actually detect?

Each mutation applied to a fresh untouched copy of `agents/ skills/ scripts/ examples/`.

| # | Fresh violation injected | Result |
|---|---|---|
| 1 | Registered literal `requires explicit user acknowledgment` duplicated into `skills/qa-security/SKILL.md` | **DETECTED** — `FAIL C4 veto-ack: literal found in 2 files` |
| 2 | `Write` added to `agents/qa-architect.md` `tools:` | **DETECTED** — `FAIL C7 capability: Write/Edit/MultiEdit/NotebookEdit found in: agents/qa-architect.md` |
| 3 | New undefined `{frobnicator-id}` in `agents/qa-report.md` | **DETECTED** — `FAIL C2: token(s) used but not declared` |
| 4 | New undefined `{frobnicator-id}` **and** `<evid>` in `skills/qa-visual/SKILL.md` | **MISSED** — `PASS: 118, FAIL: 0`, exit 0 → CRITICAL-1 |
| 5 | `description:` removed from `agents/qa-advocate.md` | **DETECTED** — `FAIL C6 qa-advocate: missing frontmatter field 'description'` |
| 6 | `name:` desynced from filename stem in `agents/qa-scan.md` | **DETECTED** — `FAIL C6 qa-scan: frontmatter name 'qa-scanner' != filename stem` |
| 7 | `Do NOT call the Task tool.` removed from `agents/qa-inclusion.md` | **DETECTED** — `FAIL C6 qa-inclusion: body does not contain executor boundary` |
| 8 | `persistence-contract.md` reference removed from `agents/qa-performance.md` | **DETECTED** — `FAIL C6 qa-performance: body does not reference persistence-contract.md` |
| 9 | Orphan agent `agents/qa-orphan.md` | **DETECTED** — `FAIL C5 bijection: agents without matching skill: qa-orphan` |
| 10 | Orphan skill dir `skills/qa-orphan/` | **DETECTED** — `FAIL C5 bijection: skills without matching agent: qa-orphan` |
| 11 | `agents/qa-feedback.md` padded past 120 lines | **DETECTED** — `FAIL C6 qa-feedback: file has 137 lines (max 120)` |
| 12 | `HAS_BLOCKERS` injected in prose into `skills/qa-visual/SKILL.md` | **DETECTED** — `FAIL C1 visual-no-blockers: forbidden token 'HAS_BLOCKERS' appears 1 non-exempt time(s)` |
| 13 | Derivation anchor `### \`{page-slug}\` — from a URL` renamed in `openspec-convention.md` | **DETECTED** — `FAIL C3 {page-slug}: anchor not found` |
| 14 | `Write to \`qaspec/` reintroduced in `skills/qa-security/SKILL.md` | **DETECTED** — `FAIL C8 no-self-write` |
| 15 | Bash granted to `agents/qa-security.md` | **DETECTED** — `FAIL C7 capability: Bash grants expected {qa-browser, qa-visual}, found: qa-browser` |
| 16 | **Paraphrased** veto rule ("mandates REJECT and demands explicit user sign-off") added to `skills/qa-architect/SKILL.md` | **MISSED** — exit 0 → WARNING-2 |

**Conclusion: the linter is not vacuous.** C1, C3, C4, C5, C6, C7, C8 all fire on real, novel
violations. The two misses are the scope gap (C2) and the literal-only matching limitation (C4).

---

## CRITICAL

### CRITICAL-1 — C2 cannot fire in the corpus the spec names as its own test cases

`coherence-lint/spec.md` §Undefined-Placeholder Check: *"Every template variable ... that appears in
a **skill file** or shared contract MUST be defined..."* Its two concrete test cases are both in
`skills/qa-visual/SKILL.md` (`<evid>` used 3× defined 0×; `{page-slug}` with no derivation).

`scripts/lib/coherence.sh:105` scopes the C2 corpus to `agents/` and `skills/_shared/qase/` only.
`skills/qa-*/SKILL.md` — 12 files, the largest part of the corpus — is never scanned.

Proof:

```
$ printf '\nCapture evidence at <evid> and store under {frobnicator-id}.\n' >> skills/qa-visual/SKILL.md
$ bash scripts/lint_skills.sh
  PASS: 118, FAIL: 0, WARN: 0
RESULT: ALL PASSED
REAL_EXIT=0
```

`rule-ownership.md:39-44` documents the narrowing as a deferral, but the spec was never amended, so
the shipped implementation does not satisfy its own requirement. Two spec scenarios
("Undefined placeholder detected", "Template variable with cited derivation algorithm passes") are
satisfied only by an `agents/` fixture, never against a skill file.

**Fix**: widen the C2 corpus to `skills/qa-*/SKILL.md` and bootstrap the remaining tokens, or amend
the spec to state the narrowed scope.

### CRITICAL-2 — the "clean passes" direction of `coherence_test.sh` is a vacuous assertion

`scripts/coherence_test.sh:86-98` (`run_all_checks`):

```bash
output=$(bash --norc --noprofile -c "...")  || true
local exit_code=$?          # <-- $? is the exit of `|| true`, i.e. always 0
...
return "$exit_code"         # <-- always 0
```

The function can never return non-zero. Fixture 1 (`assert_pass "positive corpus..."`) therefore
passes unconditionally. Proof of mechanism:

```
$ f() { local o; o=$(bash -c 'exit 7') || true; local ec=$?; echo "captured=$ec"; return "$ec"; }
$ f; echo "returned: $?"
captured=0
returned: 0
```

Proof that the positive fixture is in fact **broken**:

```
$ run_coherence_checks scripts/fixtures/coherence/positive
FAIL C2: token(s) used but not declared: {flow-slug} {page-slug} {pr-number} {short-sha}
FAIL C5 bijection: skills without matching agent: qa-visual
FAIL C5 bijection: expected 12 agents, found 0
FAIL C7 capability: Bash grants expected {qa-browser, qa-visual}, found:
---- FAIL_COUNT=4
REAL EXIT=4
```

The orchestrator's pre-verified statement *"coherence_test.sh → 4 PASS / 0 FAIL, both directions
(fixtures fail, clean passes)"* is **false for the "clean passes" direction**. Only the three
negative fixtures are real (they bypass `run_all_checks` and capture `$?` directly).

`coherence-lint/spec.md` §"Negative fixture proves the linter can fail" is half-unproven: the
linter's ability to *not* fail on a clean corpus is untested.

**Fix**: capture the exit code before `|| true` (`output=$(...); local ec=$?`), and repair the
positive fixture so it contains 12 agents/12 skills or scope the positive assertion to C1–C4.

### CRITICAL-3 — ADR-E′ P0–P6 branch table deleted from both sides

`design.md:589` (ADR-E′ Consequences): *"the probe command sequence **and the P0-P6 branch table**
move into the orchestrator documents (all 6)."*

`git diff skills/qa-init/SKILL.md` → **7 insertions, 84 deletions**. Deleted and never relocated:

- **P2b — Chrome binary fallback probe**: `command -v chromium` / `google-chrome-stable` /
  `google-chrome` / `chrome`, "Stop at the first hit", and the explicit R4 mitigation
  *"NEVER probe a single name only — false-negative risk on working environments"*.
- The smoke-test assertion detail: `get url --json` returns the url **nested under `data`**, not at
  the top level — a specific gotcha recorded from live execution.
- The branch→field mapping producing `unavailable_reason` values `bash-unavailable`,
  `agent-browser-not-installed`, `no-chrome-binary`, `smoke-test-failed`.

Decisive greps against the whole shipped corpus (`skills/ agents/ examples/ scripts/`):

```
$ rg -n 'google-chrome-stable' skills/ agents/ examples/ scripts/
skills/_shared/qase/persistence-contract.md:76:    name: "chromium" | "google-chrome-stable" | ... | null
        (schema enum only — no procedure anywhere runs the probe)

$ rg -n 'agent-browser-not-installed|no-chrome-binary|smoke-test-failed' skills/ agents/ examples/
        (zero matches)
```

Consequence: `persistence-contract.md:82` declares `detection_mechanism: "chrome-probe-fallback"` as
a legal value that **no file now instructs anyone to produce**. `qa-init` is told to "produce the
cache payload from the supplied probe results" with no branch table to map results to fields, and
the orchestrator has no P2b step to run. The schema/TTL/refusal rule did survive
(`persistence-contract.md:50-92`) — the *procedure* did not.

**Fix**: relocate the P0–P6 branch table (including P2b and the `about:blank`/`data` assertion) into
all six orchestrator documents, or restore it to `qa-init/SKILL.md` as payload-derivation rules.

### CRITICAL-4 — ADR-E′ probe sequence landed fully in only 1 of 6 orchestrator documents

| Orchestrator doc | lines added | `# P0..P3` blocks | `command -v agent-browser` | smoke `session id` |
|---|---|---|---|---|
| `examples/claude-code/CLAUDE.md` | 35 | **4** | 1 | 1 |
| `examples/vscode/copilot-instructions.md` | 20 | 0 | 1 | 1 |
| `examples/cursor/.cursorrules` | 10 | 0 | 1 | 1 |
| `examples/codex/agents.md` | 10 | 0 | 1 | **0** |
| `examples/antigravity/qase-orchestrator.md` | 10 | 0 | 1 | **0** |
| `examples/gemini-cli/GEMINI.md` | 10 | 0 | 1 | **0** |

What gemini-cli actually received, verbatim:

```
### Runtime Preflight for qa-init (ADR-E')

Before launching qa-init, run `command -v agent-browser`, `agent-browser doctor --json`, and the
smoke test, then pass all output to qa-init in its context.
```

"the smoke test" is never defined in that document. There is no P0 bash-availability probe in any of
the five. `qa-init` on those five toolchains receives an incomplete probe set and must produce
`bash_available` with no input for it. This degrades `runtime-proof-e2e` preflight for 5 of 6
orchestrators and directly undercuts the multi-tool-distribution §"Skills-Only Remains a Complete
and Supported Configuration" requirement (*"No feature of QASE that is currently available via
skills-only MUST be removed by this change"*).

### CRITICAL-5 — ADR-F orchestrator half never landed

`qa-scan/SKILL.md` Step 1 correctly became *"Read the diff supplied in your context by the
orchestrator"* (line 53-55). Deleted from it:

```
-### Step 1: Resolve Scope to Diff
-├── HEAD~N           → git diff HEAD~N
-├── --staged         → git diff --staged
-├── file.ts          → git diff HEAD -- file.ts (or read file if no git history)
-├── src/auth/        → git diff HEAD -- src/auth/
-├── --pr N           → gh pr diff N
-├── (no scope)       → git diff --staged (default: staged changes)
```

Search across all six orchestrator documents for any diff-resolution instruction:

```
$ rg -i 'gh pr diff|git diff|resolve.*scope' examples/*/CLAUDE.md examples/*/*.md examples/cursor/.cursorrules
```

returns only the pre-existing *scope vocabulary* table (`| HEAD~3 | Last 3 commits |`,
`| --staged | Staged changes only |`). **The scope→command mapping exists nowhere.** No document
tells the orchestrator that `--pr N` means `gh pr diff N`, or that a bare file path means
`git diff HEAD -- <path>` with a read-the-file fallback when there is no git history.

Design ADR-F assumed *"the orchestrator already owns scope"* — it owns the vocabulary, not the
resolution algorithm. The first agent of every pipeline now depends on an input nothing specifies
how to produce.

### CRITICAL-6 — sole-writer rule violated inside `qa-report`, and self-contradictory

`skills/qa-report/SKILL.md` Step 7, line 229:

```
├── Persist: mem_save(topic_key: "qase/{review-id}/actionable-issues", ...)
└── Include the observation ID in the structured envelope
```

`qase/{review-id}/actionable-issues` is a review-artifact key. `sole-writer-persistence/spec.md`
§"Orchestrator Is the Sole Engram Writer for Review Artifacts": *"Specialists MUST NOT call
`mem_save` with those keys."* `agents/qa-report.md:10` grants `mem_save`, so this is executable.

It contradicts two other places:

- Same file, Step 8, line 253-254: `actionable-issues: {returned inline — orchestrator persists}`
- `skills/_shared/qase/engram-convention.md:77`: `| actionable-issues | qa-report | **Orchestrator** |`

This is precisely the incoherence class the change was built to eliminate, surviving in the shipped
result. `C8` only greps `Write to \`qaspec/` — no check covers Engram-side specialist self-writes,
so the linter cannot see it.

---

## WARNING

**W-1 — `neg-undefined-placeholder` fixture fires for the wrong reason.** Its registry path
`scripts/fixtures/coherence/neg-undefined-placeholder/skills/_shared/qase/rule-ownership.md` **does
not exist** (the directory is empty). Running the check emits
`awk: fatal: cannot open file ... No such file or directory` before failing. The declared-token set
is empty, so *any* token would fail. Proof it is the missing file and not the omitted entry:
supplying a registry that declares `<evid>` flips the result to `PASS C2 undefined-placeholder: all
tokens declared`. `coherence_test.sh` only asserts the substring `"C2"` appears, so it cannot
distinguish detection from registry-load failure.

**W-2 — C4 is literal-exact; paraphrases escape, and one is already shipped.** A fresh paraphrase
("mandates REJECT and demands explicit user sign-off") added to `qa-architect/SKILL.md` yields exit
0. A real paraphrase already exists in the delivered corpus: `skills/qa-report/SKILL.md:130` and
`:199` say *"require explicit acknowledgment"* where the registered literal is *"requires explicit
user acknowledgment"*. `rule-de-duplication/spec.md` §"Referencing Files Cite Rather Than Restate"
forbids *"reproducing **or paraphrasing** the rule text"*. Only exact reproduction is enforced.

**W-3 — `rule-de-duplication` §"Ownership Pointers in SKILL.md Files" is unmet in 10 of 12 skills.**
The scenario requires every `skills/qa-*/SKILL.md` to reference *at least* `severity-contract.md`,
`oracle-contract.md`, **and** `persistence-contract.md`:

| SKILL | severity | oracle | persistence |
|---|---|---|---|
| qa-advocate | 1 | **0** | 1 |
| qa-architect | 2 | **0** | 1 |
| qa-browser | 2 | 18 | 1 |
| qa-feedback | **0** | **0** | 1 |
| qa-inclusion | 1 | **0** | 1 |
| qa-init | **0** | **0** | 3 |
| qa-performance | 1 | **0** | 1 |
| qa-report | 2 | 1 | 1 |
| qa-scan | **0** | **0** | 1 |
| qa-security | 2 | **0** | 1 |
| qa-test-strategy | 1 | **0** | 1 |
| qa-visual | 5 | 8 | 1 |

No linter check covers this scenario.

**W-4 — registry does not meet its own coverage requirement.** `rule-de-duplication/spec.md`
§"rule-ownership.md Exists and Is Machine-Readable": *"the registry MUST contain at least one entry
for each shared contract file."* Actual entries per contract: `severity-contract` 3,
`openspec-convention` 3, `oracle-contract` 1, and **zero** for `persistence-contract.md`,
`engram-convention.md`, `routing-rules.md`, `issue-format.md`. The C4 `rules` table holds only
3 literals total, so single-source enforcement covers a small slice of the normative surface.

**W-5 — dangling cross-reference created by this change.** `severity-contract.md:29` reads
*"capped at WARNING by the L4 severity ceiling **(see Oracle Tier table above)**"*. The table above
was deleted by task 1.2. A reader following the pointer finds nothing.

**W-6 — `install_test.sh` does not implement its spec scenario.** `multi-tool-distribution/spec.md`
§"install_test.sh asserts agents land at declared target": *"AND it MUST verify that no installed
agent grants `Write`."* `rg -i 'write' scripts/install_test.sh` → **zero matches**. The shipped
`test_agent_installer()` tests `get_agents_path` extraction/absence and `install_agents_to_path`
file copying against a synthetic JSON; it never performs a fresh tool install nor inspects installed
agent frontmatter.

**W-7 — design criterion 12 (≥15% shrink) not met.** `qa-visual/SKILL.md` 775 lines (target ≤682);
`qa-browser/SKILL.md` 622 (target ≤563). Self-reported by apply-progress; recorded here because the
design listed it as an acceptance criterion.

**W-8 — task 5.1 marked complete but its deliverable is partly absent.** `design.md:620` (S5):
*"`README.md` (three layers; **delete "7 Static + 2 Runtime"** — there are 12)"*. The new
Three-Layer section was added (README.md:360, :383), but README.md:54 still reads
`## The Squad (7 Static + 2 Runtime Specialists)`.

**W-9 — `{specialist}` in the orchestrator write path is undefined and likely wrong.** All six
orchestrator docs instruct `write the returned report to qaspec/reviews/{review-id}/{specialist}.md`.
`openspec-convention.md:56-65` declares the paths as `security.md`, `architect.md`, `scan.md` — bare
names, not `qa-security.md`. If `{specialist}` resolves to the agent name, every openspec artifact
lands at the wrong path. `examples/` is outside C2's corpus, so nothing catches it.

**W-10 — tier-ceiling semantics still live in two places.** `oracle-contract.md:21` owns the tier
table; `severity-contract.md:41-49` restates the same ceilings as Gate 1 pseudocode (`L4 → cap at
WARNING`, `L3-inferred → cap at WARNING`, `L3-schema` without citation → downgrade). The literal
text differs so C4 cannot see it. The tables were removed; the semantics were not de-duplicated.

---

## SUGGESTION

- **S-1** Fixture tree contains junk that also breaks the positive corpus: duplicated
  `skills/skills/...` nesting in all three negative fixtures,
  `neg-forbidden-token/agents/agents/` (empty), `positive/agents/` (empty → causes the C5/C7 FAILs
  in CRITICAL-2).
- **S-2** `scripts/lint_skills.sh:14` declares `AGENTS_DIR` and never uses it.
- **S-3** Enum inconsistency in `persistence-contract.md`: `chrome_binary.detection:
  "probe-fallback"` (line 77) vs `detection_mechanism: "chrome-probe-fallback"` (line 82).
- **S-4** `check_c1_forbidden_token` uses `grep -cF`, which counts matching **lines**, not
  occurrences. Two forbidden tokens on one line count as one.
- **S-5** `check_c6_agent_shape` only asserts the body contains the substring `SKILL.md`, not the
  agent's *own* skill path. All 12 are correct today (verified individually), but a copy-paste error
  would pass.
- **S-6** `run_check()` (`coherence_test.sh:59-79`) carries the same exit-swallow bug as
  `run_all_checks` and is dead code — never called.

---

## What was verified and is genuinely correct

Stated explicitly so remediation does not re-open settled ground.

| Claim | Evidence |
|---|---|
| Linter detects real violations | 13 of 16 fresh mutations detected; C1/C3/C4/C5/C6/C7/C8 all fire |
| `severity-contract.md` de-duplication is real, not cosmetic | `git diff` → +2/−24; the `"This section restates the ceilings"` sentence and **both** tier tables (13-28, 108-119) deleted; `rg -c 'restates' skills/ agents/` → 0; no surviving copy of either table anywhere |
| Sole-writer, specialist side | 11 of 12 SKILL.md correctly rewritten to `orchestrator calls mem_save(...)` / `orchestrator writes ...`; `rg 'Write to \`qaspec/' skills/` → 0. Only `qa-report` Step 7 remains (CRITICAL-6) |
| Sole-writer, orchestrator side | all 6 orchestrator docs carry an operational ADR-B block naming mode, path, key, and a retry-then-surface failure rule |
| `persistence-contract.md` producer/writer rewrite | line 54 now reads *"`qa-init` is the sole **producer** ... the orchestrator is the sole **writer**"*; §Sole Writer added at line 102 with a Producer/Writer table |
| Capability boundary | `Write`/`Edit`/`MultiEdit`/`NotebookEdit` → 0 agents; `Bash` → exactly `qa-browser`, `qa-visual`; `qa-report` correctly has no `Grep` |
| Bijection & agent shape | 12 agents ↔ 12 skills; max 76 lines (limit 120); all 12 declare `status`, `executive_summary`, `artifacts`, `verdict_contribution`, `risks`, `skill_resolution`; all 12 have a startup guard; all 12 reference their **own** SKILL.md |
| Agent/skill tool sufficiency | No static SKILL.md instructs Bash execution or Write/Edit; `qa-report` requires no Grep; runtime skip protocol (`status: skipped`, `verdict_contribution: CLEAN`) present in both runtime agents and skills |
| Skills-only "Works everywhere" | Live isolated-`HOME` installs: codex, cursor, gemini-cli, opencode, antigravity each → **12 skills + 8 shared contracts, 0 agents dir, exit 0, no agents-related error**. `install_agents` present in `examples/claude-code/qase.json` only, as scoped |
| claude-code agent distribution | Live install → 12 agents at `~/.claude/agents` + 12 skills; `rg -l '^tools:.*Write'` on installed agents → zero |
| `get_agents_path` absence contract | returns empty stdout, exit 1 (spec asked for empty string — satisfied) |
| Task 1.7 guard claim | Honest: `qa-scan/SKILL.md` already cites `routing-rules.md` at lines 31, 73, 87, 98 with no inline matrix |
| Task 1.8 acceptance | `rg -c 'Oracle Tier' skills/` → 55 across 7 files, down from 60. Decreased as required |

---

## UNVERIFIED

| Item | Reason |
|---|---|
| Agent-layer §Startup Guard runtime scenarios (blocked on unreadable SKILL.md / contract) | Requires spawning a real sub-agent with a broken install. Only the *declaration* was verified statically in all 12 agents. |
| Agent-layer §"Agent does not invoke Task during execution" | Behavioural; requires live agent execution. Declaration verified. |
| Capability-boundary §"Static reviewer cannot execute — reports limitation as INFO, `status: partial`" | Behavioural; no test harness exists for specialist runtime behaviour. |
| Sole-writer §"Orchestrator calls mem_save for specialist reports in engram mode" | Behavioural; requires a live pipeline run. Documentation on both sides verified. |
| `examples/mock-tool` and `examples/vscode` install anomalies (`mock-tool` not in discovery; `vscode` installs to relative `./.vscode/skills`, not `$HOME`) | Reproduced but confirmed **pre-existing**, not introduced by this change. Not counted as findings. |
| Whether the `runtime-proof-e2e` preflight still passes end-to-end against a real `agent-browser` install | No `agent-browser` runtime available in this verification context. |

---

## Verdict

**FAIL.** Four of the six CRITICALs are missing halves of decisions the design explicitly recorded
(ADR-E′ probe table, ADR-E′ multi-tool parity, ADR-F diff mapping, sole-writer for
`actionable-issues`). Two are enforcement-integrity defects (C2 scope, vacuous positive fixture).
None require re-litigating an architectural decision; all are completion or wiring work.

**Next**: `sdd-apply` to remediate CRITICAL-1 through CRITICAL-6. Do not archive.
