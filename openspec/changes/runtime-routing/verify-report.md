# Verification Report: runtime-routing

**Change**: `runtime-routing`
**Phase**: verify (fresh context, adversarial mandate)
**Branch**: `feat/GS-runtime-routing-orchestrator` (PR 2, uncommitted) on top of `a058d8f` (PR 1)
**Artifacts read**: proposal, design, 4 specs, tasks, apply-progress
**Verdict**: **FAIL** — 3 CRITICAL, 7 WARNING, 4 SUGGESTION

---

## 1. Executed Evidence (re-run in this context, not inherited)

| Command | Exit | Result |
|---|---|---|
| `bash scripts/lint_skills.sh` | 0 | PASS 123, FAIL 0, WARN 0 |
| `bash scripts/install_test.sh` | 0 | PASS 22, FAIL 0 (incl. criterion-13 skills-only) |
| `bash scripts/coherence_test.sh` | 0 | 7/7 fixtures PASS |
| byte-identity diff vs `a058d8f` (preflight truth table) | 0 | diff empty, 18 lines |

The gate is green. **The gate being green is the finding**, not the reassurance — see §3.

**Structural caveat (UNVERIFIED)**: this repository is a corpus of Markdown instruction
files. There is no executable pipeline and no test that runs `/qa-review`. Every "test" is a
static linter over text. Per the sdd-verify hard rule *"a spec scenario is compliant only when a
covering test passed at runtime"*, **zero spec scenarios have runtime covering evidence**. All
compliance below is by source inspection plus mutation testing of the linters.

---

## 2. Task Completion

27/27 tasks marked `[x]`. Spot-checked 3.1–3.6, 4.1–4.4, 6.1–6.2 against the code: the claimed
edits are present. Task bookkeeping is **accurate**.

The defect is not in apply. **The plan itself had a scope gap** (CRITICAL-1) that apply
faithfully implemented.

---

## 3. CRITICAL

### CRITICAL-1 — `examples/opencode/opencode.json` is a shipped orchestrator target that received zero runtime-routing wiring

`examples/opencode/qase.json` declares:

```json
"orchestrator": { "source": "opencode.json", "target_label": "~/.config/opencode/opencode.json", "auto_append": false }
```

`README.md:100-102, 487-489, 700` document it as the OpenCode **"Orchestrator agent config"**.
The file contains the full orchestrator prompt: `"You are the ORCHESTRATOR for QASE"`,
`ORCHESTRATOR RULES` 1–10, `SUB-AGENT LAUNCHING PATTERN`, `PIPELINE: /qa-review [scope]`, and
`VERDICT PRESENTATION`.

Measured coverage of every runtime-routing literal:

```
runtime_recommendation           0
Step 2b                          0
Runtime URL Resolution           0
never starts the application     0
runtime_suffix                   0
runtime_coverage                 0
qa-browser                       0
qa-visual                        0
STATIC ONLY                      0
```

Its verdict presentation is, verbatim:

```
## Review Complete: {verdict}
```

**Live failure path** (no mutation required):
`/qa-review --pr 42` on a UI diff, OpenCode install →
qa-scan emits `runtime_recommendation.recommended: true` (PR 1 skill-level, works) →
the OpenCode orchestrator prompt has no Step 2b, so it is ignored →
no runtime specialist launched (`qa-browser`/`qa-visual` are not even in its skills list or
command map) → qa-report Step 3b resolves `runtime_coverage: unverified` →
orchestrator renders `## Review Complete: APPROVE`, **bare**.

This is exactly the failure the change exists to prevent.

**Root cause** — `design.md:471` states:

> `examples/opencode/opencode.json` is **not** an orchestrator document and is not touched. Six documents, not seven.

That premise is false and is contradicted by `qase.json`, `README.md`, and the file's own
contents. `tasks.md` Phase 3 inherited it (6 tasks, 3.1–3.6). C9's `required` table pins exactly
6 paths, so the linter is structurally blind to the 7th.

**Spec violations**: `runtime-coverage-verdict` → *"Impossible to imply runtime verification that
never happened"*; `page-level-scope` → *"UI review completes on skills-only install"* (opencode has
`install_agents=0`, i.e. it is one of the 7 skills-only targets the spec explicitly protects).

---

### CRITICAL-2 — `{runtime_suffix}` is unresolvable in all 6 wired orchestrator documents

This is the answer to *"name the first step where a literal reader would stall or guess"*: it is
the **final rendering step**, `## Review Complete: {verdict}{runtime_suffix}`.

Measured across all 6 docs:

| Doc | `{runtime_suffix}` occurrences | refs to `severity-contract` | `_shared` refs |
|---|:--:|:--:|:--:|
| claude-code/CLAUDE.md:314 | 1 | 0 | 0 |
| vscode/copilot-instructions.md:192 | 1 | 0 | 0 |
| cursor/.cursorrules:180 | 1 | 0 | 0 |
| gemini-cli/GEMINI.md:190 | 1 | 0 | 0 |
| codex/agents.md:190 | 1 | 0 | 0 |
| antigravity/qase-orchestrator.md:183 | 1 | 0 | 0 |

`rg 'STATIC ONLY' examples/ README.md` → **0 matches**.

Every other token in that template is locally resolvable — `{verdict}` is enumerated at Step 3
(`APPROVE | APPROVE WITH WARNINGS | REJECT`), `{runtime_coverage}` is enumerated inline
(`{verified | not-required | unverified}`). `{runtime_suffix}` alone has **no definition, no
enumerated values, and no pointer to its owner file** anywhere in the document the orchestrator
reads. Its only correct expansion, `" (STATIC ONLY)"`, is a single-source literal
(`rule-ownership.md:56`, `allow_count: 0`) whose scope is `skills/**,agents/**` — deliberately
excluding `examples/**`, so the value can never appear where the reader needs it.

M2 registers `{runtime_suffix}` as `class: derived` with anchor `### Runtime Coverage Suffix`, and
C3 enforces that anchor — but C2 (undefined-placeholder) is scoped to `agents/**`,
`skills/_shared/qase/**`, `skills/qa-*/SKILL.md` (`rule-ownership.md:41-42`). **`examples/` is
outside C2's scope**, so an undefined placeholder there is invisible to the linter.

A literal reader hitting an undefined token at render time drops it or guesses. Dropping it
produces `## Review Complete: APPROVE` with `**Runtime coverage**: unverified` three lines below.

---

### CRITICAL-3 — `README.md:220` documents a verdict suffix that does not exist

> 3. **Account** — ... the final verdict line carries a runtime suffix: `### Verdict: {verdict} | UNVERIFIED`.

The contract is `### Verdict: {verdict}{runtime_suffix}` where `runtime_suffix` is `" (STATIC ONLY)"`
(`severity-contract.md:86-91`). `| UNVERIFIED` appears in no skill, no agent, no spec, and satisfies
no spec scenario.

The same sentence also mis-states the trigger: *"If a specialist ran under a recommendation and
returned UNVERIFIED"*. The actual trigger is `runtime_coverage == unverified`, which covers
BRANCH R / D / X where **no specialist ran at all** — 3 of the 4 unverified paths.

README is the only document outside `skills/` that describes the suffix, and it teaches the wrong
one. Combined with CRITICAL-2, a reader who cross-references README to resolve `{runtime_suffix}`
renders `APPROVE | UNVERIFIED`.

---

## 4. WARNING

### WARNING-1 — C10a is defeated by a single `|` character (mutation-proven)

C10a regex (`coherence.sh:473`): `UNVERIFIED[^|]*(->|→|==?|treated as|maps? to|same as|equivalent to)[[:space:]`]*CLEAN`

The `[^|]*` deliberately excludes pipes so the corpus's own legitimate idiom
(`UNVERIFIED (if launched_under_recommendation: true) | CLEAN (otherwise)`) does not self-trip.
That same character is the evasion.

Fresh mutation, appended to `skills/qa-report/SKILL.md`:

```
When aggregating contributions: UNVERIFIED | treated as CLEAN for verdict purposes.
→ lint exit=0, PASS: 123, FAIL: 0    (C10 PASS)
```

Control — identical sentence without the pipe:

```
When aggregating contributions: UNVERIFIED is treated as CLEAN for verdict purposes.
→ lint exit=1
   FAIL C10a: UNVERIFIED equated with CLEAN: skills/qa-report/SKILL.md:331
```

C10a fires only on the naive phrasing.

### WARNING-2 — C10 does not scope `examples/` at all (mutation-proven)

`check_c10_unverified_not_clean` reads only `$root/skills` and `$root/agents`
(`coherence.sh:468, 472`). All verdict rendering the **user actually sees** lives in `examples/`.

Fresh mutation, appended to `examples/claude-code/CLAUDE.md`:

```
When a runtime specialist returns UNVERIFIED, treat it as CLEAN and render a bare APPROVE.
→ lint exit=0, PASS: 123, FAIL: 0   (C9 PASS, C10 PASS)
→ coherence_test exit=0
```

Related: stripping `{runtime_suffix}` from `## Review Complete: {verdict}{runtime_suffix}` in
CLAUDE.md → lint exit 0, 123/0. M3 (C10d) guards `skills/qa-report/SKILL.md` **only**.

### WARNING-3 — C9 is a keyword-bag presence check, not a structural one (mutation-proven)

Deleted the entire 1439-character `### Runtime URL Resolution (ADR-C)` section from
`examples/codex/agents.md` — the whole 5-step precedence, the probe, and the exit-code guidance —
and replaced it with one line:

```html
<!-- keywords: --url ### Runtime URL Resolution (ADR-C) Step 2b ; the orchestrator never starts the application -->
```

Result: `PASS C9 required-literal: all required literals present in all declared files`,
lint exit 0, 123/0.

`min_count: 1` presence over four literals cannot detect a document that lost its routing. The
`--url` row is especially weak — any incidental mention anywhere in the file satisfies it.

C9 also cannot fail on an **unpinned** file: rows list files explicitly, so removing a path from
the `files` column silently stops checking it. The `rows -eq 0` guard only fires when the whole
table is empty. This is the mechanism behind CRITICAL-1.

### WARNING-4 — The probe trap is handled correctly in all 6 docs, but nothing protects it

Verified correct in all six (`CLAUDE.md:203-207` and equivalents):

```
# Exit code of `open` determines reachability — NOT `success` in `get url --json`.
# `get url --json` returns success:true even after a failed navigation. Key off the exit code.
Exit code 0 → RESOLVED. Exit code 1 (connection refused) → fall to step 4.
```

**Check #4 PASSES on current state.** But no `required` row pins this literal. Fresh mutation
reverting `examples/gemini-cli/GEMINI.md` to `success:true -> RESOLVED. success:false -> fall to
step 4.`:

```
lint exit=0, PASS: 123, FAIL: 0
coherence exit=0
```

The single highest-value invariant this change produced is the one with no guard on it.

### WARNING-5 — `Step 2b` BRANCH N is unreachable in all 6 documents

Identical in all six (`CLAUDE.md:254-260` and equivalents):

```
Step 2b: Runtime verification (conditional)
  → IF runtime_recommendation.recommended == true:
    → BRANCH N: recommended == false → runtime_coverage = not-required
    → BRANCH R: ...
```

BRANCH N's guard contradicts its enclosing condition; it can never be taken. When
`recommended == false` the whole block is skipped and BRANCH N still never runs.

Effect is contained — `qa-report` Step 3b independently derives `not-required` from
`runtime_recommendation.recommended != true` (`qa-report/SKILL.md:94-96`), so coverage is still
correct. But this is dead, self-contradicting text in the primary control-flow block of every
orchestrator document, replicated 6×.

### WARNING-6 — "zero findings" is contradicted within the same change

`severity-contract.md:11-12`: UNVERIFIED *"carries **zero** findings and changes only the rendered
verdict scope string, never the severity counts."*
Spec `runtime-coverage-verdict`: *"AND findings MUST be zero"*, *"the UNVERIFIED state MUST NOT
raise the finding count."*

All 3 refusal branches in both `skills/qa-browser/SKILL.md` (58-70) and
`skills/qa-visual/SKILL.md` (55-67) emit:

```
→ one INFO finding: "Runtime backend status unknown — ..."
→ ZERO runtime findings. Do NOT fabricate findings from static reading.
```

"Zero *runtime* findings" ≠ "zero findings". The INFO increments `total-findings` and `infos` in
qa-report metadata (`qa-report/SKILL.md:258, 261`). No verdict impact (INFO is non-contributing),
so this is a contract-text inconsistency rather than a verdict defect — but the two files ship in
the same change stating opposite things.

### WARNING-7 — Unverified Coverage section hardcodes both specialists

`skills/qa-report/SKILL.md:242`:

```
| {triggering-categories} | qa-browser, qa-visual | {runtime-reason} |
```

Spec requires the section *"MUST name the specialists that did not run"*. Per the trigger table,
`api` and `auth` recommend **`qa-browser` only** (`routing-rules.md:106-107`). An api-only review
will report `qa-visual` as "did not run" when it was never recommended — overstating the gap and
contradicting `runtime_recommendation.specialists`.

---

## 5. Checks that PASSED

| # | Check | Result |
|---|---|---|
| 2 | M1 two-token template `### Verdict: {verdict}{runtime_suffix}` | **EXISTS** — `qa-report/SKILL.md:158` |
| 2 | M2 `{runtime_suffix}` registered `class: derived`, C3 anchor | **EXISTS** — `rule-ownership.md:138` → `severity-contract.md:81`; C3 enforces |
| 2 | M3 C10(d) two-token assert + un-suffixed reject | **EXISTS and WORKS** — `coherence.sh:492-497`; `neg-unverified-as-clean` fixture exits 4 with `C10` |
| 3 | `UNVERIFIED` gated on `launched_under_recommendation: true` | **PASS** — 3 branches × 2 skills, all conditional |
| 3 | Solo `/qa-browser` refusal returns `CLEAN` | **PASS** — `\| CLEAN (otherwise)` on all 6 branches (R5 containment) |
| 3 | `UNVERIFIED` never reaches Gate 1 / Gate 2 | **PASS** — gates are per-finding; Step 3b runs *after* veto logic; `severity-contract.md:83` "base_verdict ... is NEVER altered by coverage" |
| 3 | No shipped path maps `UNVERIFIED` → `CLEAN` | **PASS** in current corpus (but see WARNING-1/2 for detectability) |
| 4 | Probe keys off `open` exit code in all 6 docs | **PASS** — verified individually |
| 6 | Skills-only install completes | **PASS** for install mechanics — criterion-13 green, 12 skills, exit 0 |
| — | Preflight truth table byte-identical vs `a058d8f` | **PASS** — diff empty, independently re-run |
| — | `runtime_unverified_reason` 9-value enum, review-scoped | **PASS** — `persistence-contract.md:167-182`; new values absent from preflight enum |
| — | Trigger table matches spec exactly | **PASS** — `routing-rules.md:103-109`; `business` is an explicit non-trigger |

---

## 6. Spec Conformance Matrix

| Spec | Requirement | Status |
|---|---|---|
| runtime-recommendation | Category-to-Runtime Trigger Table (4 scenarios) | COMPLIANT (static) |
| runtime-recommendation | Block Schema, 5 keys | COMPLIANT (static) |
| runtime-recommendation | `candidate_targets` advisory, never auto-navigated | COMPLIANT (static) |
| runtime-recommendation | qa-scan has no Bash / no env access | COMPLIANT — `install_test` capability-boundary asserts Bash only for qa-browser/qa-visual |
| url-resolution | 5-step precedence (5 scenarios) | COMPLIANT in the 6 wired docs; **ABSENT** in opencode |
| url-resolution | **Read-Only Reachability Probe** — *"MUST NOT follow more than one redirect"* | **UNIMPLEMENTED** — probe is `agent-browser open`, a full navigation; no redirect bound, no timeout, in any of the 6 docs. Design §534's "one GET, 3-second cap" was superseded by the agent-browser ruling and the bound was silently dropped |
| url-resolution | No-Auto-Start Prohibition + registered literal | COMPLIANT — `rule-ownership.md:55`, `allow_count: 0`, scope includes `examples/**` |
| url-resolution | `(STATIC ONLY)` registered single-source | COMPLIANT — `rule-ownership.md:56` |
| runtime-coverage-verdict | `runtime_coverage` field, 3 values | COMPLIANT |
| runtime-coverage-verdict | UNVERIFIED contribution, **zero findings** | **PARTIAL** — see WARNING-6 |
| runtime-coverage-verdict | `(STATIC ONLY)` qualifier, REJECT unqualified | COMPLIANT in `qa-report`; **BROKEN at the presentation layer** — CRITICAL-2, CRITICAL-1 |
| runtime-coverage-verdict | Unverified Coverage section names specialists that did not run | **PARTIAL** — hardcoded pair, WARNING-7 |
| runtime-coverage-verdict | Preflight truth table byte-identical | COMPLIANT (verified) |
| runtime-coverage-verdict | *"Impossible to imply runtime verification that never happened"* | **VIOLATED** — CRITICAL-1 (live), CRITICAL-2 |
| runtime-coverage-verdict | Negative fixture: bare APPROVE + unverified fails linter | DEVIATION (accepted) — C10d asserts the template, not a report. Note the accepted proxy does not cover `examples/` |
| page-level-scope | Steps 1–8 page-level checks, 7 checks | COMPLIANT — Steps 2–8 map to the 7 checks |
| page-level-scope | Report records *"User flows: none provided — page-level only"* | **UNIMPLEMENTED** — 0 matches repo-wide |
| page-level-scope | *"MUST NOT infer user flows from the diff"* prohibition | **UNIMPLEMENTED** — 0 matches in `qa-browser/SKILL.md`, `agents/qa-browser.md`, `CLAUDE.md`. Behavior is effectively correct (Step 9 gated on provided flows, `SKILL.md:501`) but the prohibition is never stated |
| page-level-scope | Clean degradation on skills-only installs → `(STATIC ONLY)` | **VIOLATED for opencode** — CRITICAL-1 |
| page-level-scope | Bash confinement unchanged | COMPLIANT — `install_test` capability-boundary green |

---

## 7. SUGGESTION

- **S1** — C10(e) set containment is satisfied by a **negation**: `agents/qa-scan.md:54` reads
  *"`qa-scan` never emits `UNVERIFIED`"*, and `grep -rlF 'UNVERIFIED'` counts that file as a member
  of the required set. The check asserts which files *mention* the token, not which files *emit* it.
  Correct outcome here, semantically vacuous as a containment guarantee.
- **S2** — `qa-report` metadata field `verdict: {APPROVE|APPROVE_WITH_WARNINGS|REJECT}`
  (`SKILL.md:254`) carries the bare base verdict in the same block as
  `runtime_coverage: unverified`. Defensible (base vs rendered are distinct fields) but worth an
  explicit note in the template so a machine consumer does not read the bare field as the verdict.
- **S3** — `README.md:219` describes URL resolution as three sources ("the flag, stored context, or
  `qa-init` defaults"), omitting step 3 (port probe) and step 4 (ask the user once) of the
  five-step precedence.
- **S4** — Recommended hardening once CRITICAL-1/2 are fixed: extend C10's scope to `examples/**`;
  add `required` rows for the probe exit-code literal and for `{runtime_suffix}` in the verdict
  presentation; drop `[^|]` from the C10a regex and instead whitelist the exact legitimate idiom.

---

## 8. Verdict

**FAIL.** The contract layer (`skills/`, `agents/`) is well built: M1, M2 and M3 all exist and each
works independently, the launch-context gating is correct, R5 containment holds, and the byte-identity
invariant is intact. The failure is at the **presentation boundary** — the layer the linter does not
police and the user actually reads.

The single sentence that most compactly describes the state of this change is `design.md:471`:
*"Six documents, not seven."* There are seven, and the seventh renders a bare `APPROVE`.

**Blocks archive.** Return to `sdd-apply`.


---

# Final Confirmation Pass

**Context**: fresh context, adversarial. Mandate: confirm or refute the claim that all 8 CRITICALs
(X1–X8) are closed, hunt for regressions the remediation introduced, and re-attack the primary
question across all seven orchestrators.
**Branch**: `feat/GS-runtime-routing-orchestrator`, uncommitted (26 files changed, 670 insertions,
132 deletions, plus 8 untracked fixture files).
**Verdict**: **NOT DELIVERABLE** — 2 CRITICAL, 11 WARNING, 7 SUGGESTION.
6 of 8 CRITICALs are genuinely closed and reproduced by mutation. X4 is not closed. X8's instance is
closed but its mechanism is not.

---

## FC.1 Gate re-executed in this context

| Command | Exit | Result |
|---|:--:|---|
| `bash scripts/lint_skills.sh` | 0 | PASS 123, FAIL 0, WARN 0 (includes `PASS C9`, `PASS C10`) |
| `bash scripts/install_test.sh` | 0 | PASS 22, FAIL 0 |
| `bash scripts/coherence_test.sh` | 0 | 7/7 fixtures PASS |
| preflight truth-table byte-identity vs `a058d8f` | 0 | diff empty, 18 lines; `persistence-contract.md` untouched in this working tree (`git diff` = 0 lines) |
| `jq empty examples/opencode/opencode.json` | 0 | valid JSON |

After the full mutation battery below, the working tree was restored and re-verified byte-for-byte:
`26 files changed, 670 insertions(+), 132 deletions(-)`, all three gates exit 0, opencode prompt
length 14272 — identical to the pre-mutation state.

---

## FC.2 X1–X8 confirmation table (each confirmed by execution, not by inspection alone)

| # | Claim | Status | Reproduction evidence |
|---|---|---|---|
| **X1** | `opencode.json` was a 7th unwired orchestrator | **CONFIRMED FIXED** | Prompt extracted with `jq` and diffed line-by-line: 208 → 249 lines, 10680 → 14272 chars. Three "deletions" are all in-place expansions (Rule 9, Step 3 fan-in line, verdict heading) — **zero content lost**. Non-prompt JSON structure `diff`-identical. Mutation: strip `The orchestrator never starts the application.` → `FAIL C9 orch-no-auto-start: required literal 'never starts the application' missing from …/examples/opencode/opencode.json (found 0, need 1)`, lint exit 1. `design.md:471` now reads "Seven documents, not six." |
| **X2** | qa-browser undefined in 5 of 6 docs | **CONFIRMED FIXED (7/7)** | Parity matrix, all seven `y`: Rule 9 lists `qa-browser`+`qa-visual`; Command→Skill Mapping row for both; Available Skills lists `qa-browser/SKILL.md` and `qa-visual/SKILL.md`; Commands list carries `/qa-browser <url>` / `/qa-visual [url]`. |
| **X3** | `{runtime_suffix}` unresolvable in the presentation header | **CONFIRMED FIXED (7/7)** | All seven now carry, immediately under the heading: `{runtime_suffix} resolution: read runtime_coverage from qa-report Step 3b result. / If runtime_coverage == unverified AND base_verdict is not REJECT: runtime_suffix = " (STATIC ONLY)". / Otherwise: runtime_suffix = "" (empty string). Full definition: severity-contract.md → ### Runtime Coverage Suffix.` This matches `severity-contract.md:86-89` exactly. Counts across 7 docs: `{runtime_suffix}` 2, `STATIC ONLY` 1, `severity-contract.md` 1, `Runtime Coverage Suffix` 1. Now C9-pinned. Mutation: remove `{runtime_suffix}` from `GEMINI.md` → `FAIL C9 orch-runtime-suffix … (found 0, need 1)`, lint exit 1. |
| **X4** | qa-report "What You Receive" omitted the fields; no orchestrator forwarded them; **Step 8 envelope omitted `runtime_coverage`** | **NOT CLOSED** | Two of three sub-parts fixed: `skills/qa-report/SKILL.md:26-27` now receives `runtime_recommendation` + `runtime_unverified_reason`; all 7 orchestrators forward them at Step 3. **The third is untouched**: `skills/qa-report/SKILL.md:300-319` (Step 8 "Return structured envelope") still lists `verdict`, `veto`, `total_findings`, `blockers`, `warnings`, `infos`, `hotspot_files` … and **no** `runtime_coverage`, **no** `runtime_unverified_reason`. `awk 'NR>=293' skills/qa-report/SKILL.md \| grep runtime` → **0 matches**. See CRITICAL-1. |
| **X5** | BRANCH N unreachable | **CONFIRMED FIXED (7/7)** | All seven restructured to `IF runtime_recommendation.recommended != true: → BRANCH N: runtime_coverage = not-required` / `ELSE (recommended == true): → BRANCH R/U/D/X`. BRANCH N is now the taken branch of the negated guard. Arrow conventions preserved and **not** homogenised: CLAUDE.md `→`, the other five `->`, opencode `-`. |
| **X6** | README documented `{verdict} \| UNVERIFIED` | **CONFIRMED FIXED** | `grep -cF '\| UNVERIFIED' README.md` → **0**; `grep -n UNVERIFIED README.md` → **no matches at all**. New §"Runtime Routing" states `## Review Complete: {verdict} (STATIC ONLY)` and corrects the trigger: *"`runtime_coverage` is `unverified` whenever the recommended specialists did not run or refused — … not only when a specialist ran and refused."* |
| **X7** | C10a defeated by inserting one `\|` | **CONFIRMED FIXED (as reported)** | New second pattern `eq2` added, and C10's scope extended to `examples/`. Mutation battery on `skills/qa-report/SKILL.md`: `UNVERIFIED \| treated as CLEAN` → **CAUGHT**; control `UNVERIFIED is treated as CLEAN` → **CAUGHT**; `UNVERIFIED \| severity: none \| == CLEAN` → **CAUGHT**. Scope extension proven live: `UNVERIFIED -> CLEAN` and `UNVERIFIED \| treated as CLEAN` appended to `examples/claude-code/CLAUDE.md` → **CAUGHT**; `UNVERIFIED is treated as CLEAN` appended to `examples/opencode/opencode.json` → **CAUGHT**. Residual bypass surface remains — WARNING-F2. |
| **X8** | C9 cannot fail on a file not pinned in the `required` table | **INSTANCE FIXED, MECHANISM NOT FIXED** | Instance: the table grew from 4 rows × 6 paths to **6 rows × 7 paths** (added `orch-runtime-suffix` and `orch-probe-exit-code`; added `examples/opencode/opencode.json` to every row). Mechanism unchanged — `check_c9_required_literal` (`scripts/lib/coherence.sh:427-455`) iterates only the row's own `files` column; the sole guard is `rows -eq 0`. Nothing enumerates `examples/*` against the table. **Mutation**: delete `,examples/opencode/opencode.json` from all six rows, then strip *all five* runtime literals from `opencode.json` → `lint exit=0, PASS: 123, FAIL: 0`, `coherence_test exit=0`. The exact CRITICAL-1 regression can silently reappear. See WARNING-F4. |

---

## FC.3 The primary question, re-attacked across all SEVEN

**Can a bare `APPROVE` still escape when runtime was recommended and did not run?**

| Path | Result |
|---|---|
| **Header path** | **CLOSED, 7/7.** `## Review Complete: {verdict}{runtime_suffix}` is present in all seven, and `{runtime_suffix}` is now locally resolvable at the exact render step with enumerated values and an owner pointer. A literal reader cannot stall. |
| **Envelope path** | **OPEN.** `agents/qa-report.md:59-60` declares `runtime_coverage` and `runtime_unverified_reason` as returned fields. `skills/qa-report/SKILL.md:300-319` — the envelope spec the executor actually follows — omits both. Two files shipped in the same change state contradictory contracts about the same field. All seven orchestrators say "read `runtime_coverage` from qa-report Step 3b result"; if the executor emits the Step 8 list literally, that field is not in the result. |
| **Missing-field path** | **OPEN, fail-open.** No orchestrator document states a default when `runtime_coverage` is absent or unreadable. The safe rule ("absent ⇒ treat as `unverified`") is written nowhere in any of the seven. Independently, `qa-report` Step 3b is itself fail-open on a missing `runtime_recommendation` block: absent ⇒ `recommended != true` ⇒ `not-required` ⇒ empty suffix ⇒ bare `APPROVE`. Mutation: deleting the Step 3 forwarding clause `(including runtime_recommendation from qa-scan and runtime_unverified_reason when set by Step 2b)` from `CLAUDE.md` → lint exit 0, 123/0. |

**Mitigation, stated for fairness**: the value does still travel out of qa-report inside `report_markdown`
(`skills/qa-report/SKILL.md:267` — `- **runtime_coverage**: {verified \| not-required \| unverified}`),
and `agents/qa-report.md` does promise the field. A competent orchestrator recovers. But recovery
depends on inference, and the standard this change set for itself — and the standard on which X3 was
failed — is that a literal reader must not have to guess.

**Answer: yes, on the envelope and missing-field paths. Not on the header path.**

---

## FC.4 CRITICAL

### CRITICAL-1 — X4 is not closed: Step 8 envelope omits the field the whole change depends on

`skills/qa-report/SKILL.md:293-319`:

```
### Step 8: Return Report
Return structured envelope:
    status / executive_summary / report_markdown / verdict / veto / veto_agents /
    artifacts / total_findings / blockers / warnings / infos / hotspot_files /
    next_recommended / risks
```

`awk 'NR>=293' skills/qa-report/SKILL.md | grep runtime` → **0 matches**.

`agents/qa-report.md:59-60` (modified by this very remediation):

```
- `runtime_coverage`: `verified` | `not-required` | `unverified` — resolved by Step 3b Coverage Resolution; …
- `runtime_unverified_reason`: one value from `persistence-contract.md` `runtime_unverified_reason` enum, or `null`
```

The remediation edited the agent contract to describe the suffix behaviour but never added the two
fields to the skill's own return envelope. Nothing in the corpus reconciles the two. Combined with the
absence of a fail-closed default (FC.3), this is a live path to a bare `APPROVE` under recommendation.

**Fix**: two lines in Step 8, plus one sentence in each of the seven orchestrators —
*"if `runtime_coverage` is absent from the qa-report result, treat it as `unverified`."*

### CRITICAL-2 — `Read-Only Reachability Probe` spec requirement is unimplemented in all seven (unchanged)

`openspec/changes/runtime-routing/specs/url-resolution/spec.md:68-81`:

> The reachability probe at step 3 MUST be a single read-only HTTP request. … THEN the request MUST be
> an HTTP GET (or equivalent read-only method) — AND the orchestrator MUST NOT follow more than one
> redirect — AND a non-2xx/3xx response MUST cause step 3 to fail and fall through to step 4

Shipped in all seven: `agent-browser --session "$S" open "http://localhost:{likely_port}"`, keyed off
the exit code. `rg 'redirect|--max-time|3-second' skills/ examples/ agents/ README.md` returns **no
probe-related hit** — no redirect bound, no timeout, no status-code check anywhere.

`agent-browser open` is a full browser navigation: it follows unbounded redirects, executes page
JavaScript, and can trigger load-time side effects. It is not "a single read-only HTTP request", which
is the exact boundary the spec's own rationale defends (*"A reachability probe reads; a start command
mutates"*). The design was amended to `agent-browser`; the spec was never amended, and the bound was
dropped rather than re-expressed.

**I am escalating this above the previous report's classification** (it was recorded there as
UNIMPLEMENTED inside the conformance matrix but not counted among the CRITICALs). Three `MUST`/`MUST NOT`
clauses in an approved spec ship unimplemented and unreconciled. Either amend the `url-resolution`
spec scenario to match the agent-browser ruling, or express the bound (e.g. same-origin assertion +
explicit timeout). Both are cheap; shipping the contradiction is not.

---

## FC.5 WARNING

### WARNING-F1 — Cross-document parity: `--url` is discoverable in six of seven (the recurring defect class)

| Item | claude | vscode | cursor | gemini | codex | antigravity | **opencode** |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Scope-syntax `--url <url>` modifier row | y | y | y | y | y | y | **NO** |
| `/qa-review [scope] [--url <url>]` command entry | y | y | y | y | y | y | **NO** |

`--url` occurrence counts: 3 / 3 / 3 / 3 / 3 / 3 / **1**. OpenCode's single hit is inside ADR-C step 1
(*"`--url <url>` flag present in the invocation"*) — a step that references a flag the document never
documents. Its `SCOPE SYNTAX` table stops at `--deep`, and its command list still reads
`/qa-review [scope]`. E1 was applied to six of seven documents.

Effect: on OpenCode, step 1 of the five-step precedence is undiscoverable; resolution silently degrades
to project-context → port probe → ask-the-user. Not a bare-`APPROVE` path (the suffix machinery is
intact), but this is the third occurrence of the six-and-one defect class in this change alone, and it
is the one the remediation was specifically asked to eliminate.

### WARNING-F2 — C10a residual bypass surface (X7's string is caught; the class is not)

Mutation battery appended to `skills/qa-report/SKILL.md`:

| Mutation | Result |
|---|---|
| `UNVERIFIED \| treated as CLEAN for verdict purposes.` | **CAUGHT** (X7's exact bypass) |
| `UNVERIFIED is treated as CLEAN for verdict purposes.` | **CAUGHT** (control) |
| `Contribution: UNVERIFIED \| severity: none \| == CLEAN.` | **CAUGHT** |
| `UNVERIFIED \| is treated as CLEAN for verdict purposes.` | **BYPASS**, lint exit 0 |
| `UNVERIFIED \| in practice maps to CLEAN.` | **BYPASS**, lint exit 0 |
| `UNVERIFIED counts as CLEAN.` | **BYPASS**, lint exit 0 |
| `For verdict purposes CLEAN == UNVERIFIED.` | **BYPASS**, lint exit 0 |

`eq2` requires the equating operator to sit immediately after the pipe (`\|[[:space:]]*(op)`); one
intervening word defeats it. `counts as` is not in the operator alternation, and neither pattern is
order-symmetric. C10a remains a phrase blacklist, not a semantic check.

### WARNING-F3 — The remediation made `severity-contract.md`'s single-source claim false

`skills/_shared/qase/severity-contract.md:94`: *"The `(STATIC ONLY)` literal is owned exclusively by
this file. It MUST NOT be restated elsewhere."*

The remediation restated `" (STATIC ONLY)"` in **all seven** orchestrator documents — necessarily, to
close X3. Before it, `rg 'STATIC ONLY' examples/` returned 0. The linter stays silent only because the
`static-only-qualifier` rule row scopes to `skills/**,agents/**`; the prose carries no such scope. Two
shipped files now state opposite things about the same literal. **Introduced by this remediation.**
Fix: scope the sentence to `skills/` and `agents/`, mirroring the rule row.

### WARNING-F4 — C9 is still presence-only; five structural deletions pass the gate

All mutations below leave `lint exit=0, PASS: 123, FAIL: 0` and `coherence_test exit=0`:

| Mutation | Gate |
|---|---|
| Delete the entire `Step 2b` block from `CLAUDE.md`, leaving the words `Step 2b (removed)` | PASS |
| Delete the ADR-C body sentence from `codex/agents.md` | PASS |
| Delete the Step 3 forwarding clause from `CLAUDE.md` | PASS |
| Drop `{runtime_suffix}` from `CLAUDE.md`'s verdict **heading** while keeping it in the prose below | PASS |
| Drop `{runtime_suffix}` from `opencode.json`'s verdict heading, prose kept | PASS |
| Flip `qa-report` Step 3b's ELSE branch from `→ unverified` to `→ verified` | PASS |
| Unpin `opencode.json` from all six `required` rows, then strip all five literals from it | PASS |

The last row is X8's unfixed mechanism. The fourth and fifth are the direct successor to X3: the guard
pins the *token's presence in the file*, not its presence *in the template*.

### WARNING-F5 — criterion-13 install test is a tautology and cannot fail

`scripts/install_test.sh:312-364` (`test_skills_only_install`) builds its own synthetic skills source,
writes `runtime_coverage: verified | not-required | unverified` into a fake `qa-report/SKILL.md`, installs
it, then asserts the installed copy contains `runtime_coverage`. It never touches the real `skills/`
tree. The synthetic `qase.json` it writes (`local skill_qase_json="$TMP_DIR/skills_only.json"`) is
**never referenced again** — `install_skills_to_path "$skills_dest" "SkillsOnlyTest" "$skills_src"` is
called with the directory, not the manifest. The stated purpose ("a `qase.json` without `install_agents`
installs 12 skills") is not exercised, and the `runtime_coverage` assertion is true by construction.

### WARNING-F6 — New non-conforming placeholder is invisible to C2

The WARNING-7 fix replaced the hardcoded pair with
`{runtime_recommendation.specialists joined by ", "}` (`skills/qa-report/SKILL.md:244`) — a
C2-scoped file. C2 extracts `\{[a-z][a-z0-9_-]*\}`; the dots, spaces and quotes make this token
unmatchable, so it is neither registered in the `placeholders` table nor detectable as undeclared.
The semantic fix is right; the token shape silently escapes the placeholder registry. Prefer
`{runtime-specialists}` registered as `descriptive`.

### WARNING-F7 — BRANCH U repeats the exact defect the remediation just fixed in qa-report

All seven: `BRANCH U: … launch qa-browser [url, launched_under_recommendation: true]; launch qa-visual if ui triggered`.

The specialist set is hardcoded instead of read from `runtime_recommendation.specialists` — the same
hardcoding that WARNING-7 removed from `qa-report`. Behaviour happens to be correct for the current
trigger table (`api`/`auth` → qa-browser only), but the manifest key exists precisely so the launch
decision is data-driven. `ui triggered` is defined in no orchestrator document and has no pointer to
`runtime_recommendation.triggering_categories`.

### WARNING-F8 — `cache absent/stale` is undefined at the point of use (unchanged)

`BRANCH R: runtime_available != true (or cache absent/stale)` in all seven. "Stale" is defined only in
`skills/_shared/qase/persistence-contract.md:56` (`probed_at` older than `ttl_hours`, default 24) —
a file the orchestrator does not read and to which BRANCH R gives no pointer. Lower stakes than X3
because the ambiguity resolves toward `unverified`, which is fail-safe.

### WARNING-F9 — Two `page-level-scope` spec requirements remain unimplemented (unchanged)

`rg 'User flows: none provided|MUST NOT infer user flows|page-level only' skills/ agents/ examples/` →
**0 matches**. Spec `page-level-scope` requires the report to record *"User flows: none provided —
page-level only"* and requires the *"MUST NOT infer user flows from the diff"* prohibition to be
stated. Behaviour is effectively correct (Step 9 is gated on user-supplied flows) but neither the
record line nor the prohibition exists anywhere in the corpus.

### WARNING-F10 — `qa-report` Step 3b is fail-open on a missing recommendation block (unchanged)

Absent `runtime_recommendation` ⇒ first branch (`recommended != true`) ⇒ `not-required` ⇒ empty suffix.
Missing input and "no runtime needed" are indistinguishable, and the forwarding clause that supplies
the block is documented but unlinted (WARNING-F4).

### WARNING-F11 — "zero findings" contradiction is unaddressed (unchanged)

`severity-contract.md:11` — UNVERIFIED *"carries **zero** findings"*. All three refusal branches in
`skills/qa-browser/SKILL.md:59,64,69` and `skills/qa-visual/SKILL.md:56,61,66` emit *"one INFO finding"*.
No verdict impact (INFO is non-contributing), but the two files still ship stating opposite things.

---

## FC.6 Regression hunt — what the remediation did **not** break

| Area | Finding |
|---|---|
| `examples/opencode/opencode.json` content loss | **None.** Full prompt diff: 3 changed lines, all in-place expansions. Non-prompt JSON structure identical. Valid JSON. |
| Coherence fixtures teach correct semantics | **Yes.** `positive/agents/qa-report.md` states *"The UNVERIFIED contribution is never counted as CLEAN"*; `positive/agents/qa-scan.md` states *"qa-scan never sets runtime_coverage and never emits UNVERIFIED"*; refusal branches use the conditional idiom `UNVERIFIED (if launched_under_recommendation: true) \| CLEAN (otherwise)`; `neg-*` fixtures encode exactly the defect each names. |
| `coherence.sh` weakened an existing check | **No.** C1–C8 untouched (diff is purely additive: +99 lines, all inside the two new functions plus two wiring lines). C10a's scope was *widened* to `examples/`, never narrowed. |
| Preflight truth table / `unavailable_reason` enum | **Intact.** Byte-identical to `a058d8f`, 18 lines, `persistence-contract.md` has zero working-tree changes. |
| Arrow/heading conventions homogenised | **No.** CLAUDE.md keeps `→`, the other five keep `->`, opencode keeps `-`. Divergent section names preserved. |
| Task bookkeeping | **Accurate.** 27/27 `[x]`; spot-checked 3.1–3.6, 4.1–4.4, 6.1–6.2 against code. |

---

## FC.7 SUGGESTION

- **FS1** — The positive fixture's `required` table pins only `orch-no-auto-start`, though its stub docs
  contain all six required literals. Five of six C9 rows are unexercised by the positive fixture.
- **FS2** — `neg-unverified-as-clean` fires four C10 sub-failures (C10b, C10d ×2, **C10e**), not the two
  it documents. C10e fires incidentally because the fixture has no `agents/` directory. The assertion
  greps only for `C10`, so the fixture would still pass if C10b and C10d both regressed.
- **FS3** — `scripts/lib/coherence.sh:470-471` — the comment `# (a) No file may EQUATE the two tokens on one line.`
  is duplicated verbatim.
- **FS4** — The seven inline suffix rules say *"base_verdict is not REJECT"*; the canonical function
  excludes `{REJECT, REJECT (VETO)}`. Faithful in effect, but the two spellings differ.
- **FS5** — `README.md` still describes URL resolution as three sources (*"the flag, stored context, or
  `qa-init` defaults"*), omitting step 3 (port probe) and step 4 (ask the user once). Carried from S3.
- **FS6** — `qa-report` metadata still carries the bare `verdict: {APPROVE|APPROVE_WITH_WARNINGS|REJECT}`
  alongside `runtime_coverage: unverified` in the same block. Carried from S2.
- **FS7** — `skills/qa-report/SKILL.md:115` says Step 3b's result is for "Step 8 metadata", but the
  `## Metadata` block lives inside the Step 6 report template.

---

## FC.8 Verdict

**NOT DELIVERABLE. Blocks archive. Return to `sdd-apply`.**

The remediation is substantially real, not cosmetic. X1, X2, X3, X5, X6 and X7 are closed and each one
was reproduced here by constructing the mutation that would have caught the original defect and showing
it now fails. The seventh orchestrator is fully wired with no content loss, the suffix is resolvable at
the render step in all seven, BRANCH N is reachable, README teaches the right contract, and C10 now sees
`examples/`. Six new C9 rows and two new coherence checks did not weaken anything that existed.

Two things stop it. **X4 was reported as three sub-defects and two were fixed** — the Step 8 envelope
still omits the field every orchestrator is told to read, while the agent contract next to it promises
that field. And the `Read-Only Reachability Probe` requirement still ships with three unimplemented
`MUST` clauses and an unamended spec.

Both are small. Neither is cosmetic. The remaining eleven WARNINGs are guard-strength and parity issues
that do not block, with one exception worth naming plainly: **`--url` is documented in six of seven
orchestrators.** The defect class this change kept hitting has now happened a third time, in the same
file the remediation was written to fix.
