# Design: runtime-routing

**Change**: `runtime-routing`
**Phase**: design
**Input**: `openspec/changes/runtime-routing/proposal.md` (authoritative — Decisions A–E are settled)
**Depends on**: `three-layer-architecture` (NOT archived; its specs live in `openspec/changes/three-layer-architecture/specs/`). ADR-E′ (orchestrator owns environment probing) and ADR-F (orchestrator resolves scope → diff) are inherited, not re-litigated.
**Delivery**: markdown only. No script changes behaviour except `scripts/lib/coherence.sh` (two new checks).

> Size note: the `sdd-design` skill sets an 800-word budget. `openspec/config.yaml` `rules.design` requires sequence diagrams and documented decisions, and the sibling `three-layer-architecture/design.md` is 697 lines. Project convention wins; this document follows the sibling's shape.

---

## Technical Approach

The change is a **bridge between two facts that no single actor holds**, so it is built as a three-owner pipeline with one join point:

```
┌──────────────────────────────────────────────────────────────────────────┐
│ RECOMMEND — qa-scan (L1/L2, static, no Bash, no environment access)      │
│   Input:  a diff.  Output: runtime_recommendation{}.                     │
│   Knows:  which categories changed.                                      │
│   Cannot: know whether a runtime exists or where it listens.             │
└──────────────────────────────────────────────────────────────────────────┘
                                   │  recommendation (advisory)
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ DECIDE — the orchestrator (L0, sole writer, owns env + user + git)       │
│   Input:  recommendation + preflight cache + flags + project context.    │
│   Output: launch(url) OR record(runtime_unverified_reason).              │
│   Boundary: resolves a URL. NEVER starts an application.                 │
└──────────────────────────────────────────────────────────────────────────┘
                                   │  launch or skip
                                   ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ ACCOUNT — qa-report (aggregator)                                         │
│   Input:  findings + metadata envelopes + the recommendation.            │
│   Output: verdict = base_verdict ⊕ suffix(runtime_coverage).             │
│   Invariant: a report cannot render a bare APPROVE on unverified cover.  │
└──────────────────────────────────────────────────────────────────────────┘
```

The architectural pattern is **advisory-recommendation with mandatory accounting**. The recommendation is non-binding — that is what keeps `qa-scan` honest and keeps skills-only installs working. The *accounting* is binding — that is what stops the overstatement the change exists to remove. Everything load-bearing lives in the accounting half, because a recommendation that is ignored silently is exactly today's defect wearing a new name.

Four boundaries are load-bearing and stated so `sdd-verify` can check them:

| # | Boundary | Rule |
|---|----------|------|
| B6 | **Recommendation ≠ activation** | `qa-scan` has no matrix column for runtime specialists and asserts nothing about availability. |
| B7 | **Read, never start** | The orchestrator MAY issue one read-only reachability request. It MUST NOT execute `detected_start_hints[].command`. |
| B8 | **Coverage is not a finding** | `UNVERIFIED` carries zero findings. It changes the verdict *scope string*, never the severity counts. |
| B9 | **Preflight is frozen** | The preflight `unavailable_reason` enum and its truth table are byte-identical. Review-scoped reasons live in a separate field. |

---

## Sequence Diagram 1 — `/qa-review --pr 42`, end to end, after this change

```
User    Orchestrator (L0, sole writer)         qa-scan   static x6   qa-browser/visual   qa-report
 |            |                                   |          |             |                |
 | /qa-review --pr 42 [--url U]                    |          |             |                |
 |----------->|                                   |          |             |                |
 |            | ADR-F: gh pr diff 42  ────────────────────────────────────────────────────>  |
 |            | read preflight cache (ADR-E′; written by ME at /qa-init)                     |
 |            |                                   |          |             |                |
 |            | spawn qa-scan [ctx: diff, scope, flags] ───> |             |                |
 |            |<── routing manifest + runtime_recommendation{} ───────────|                |
 |            |    recommended: true|false, triggering_categories, specialists,             |
 |            |    candidate_targets[] (ADVISORY — never auto-navigated)                    |
 |            |                                   |          |             |                |
 |   ╔═══ TRUE FAN-OUT (unchanged) — 6 static specialists, 6 cold contexts ═══╗            |
 |            | spawn qa-architect … qa-test-strategy ──────>|             |                |
 |            |<── 6 reports (RETURNED) ─────────────────────|             |                |
 |   ╚═════════════════════════════════════════════════════════════════════╝              |
 |            |                                   |          |             |                |
 |            | ┌── DECISION GATE (new; the whole change) ──────────────────────────┐       |
 |            | │ recommended == false                                             │       |
 |            | │   → runtime_coverage = not-required ; reason = null  ── BRANCH N  │       |
 |            | │                                                                  │       |
 |            | │ recommended == true                                              │       |
 |            | │   ├─ preflight.runtime_available != true (or cache absent/stale) │       |
 |            | │   │    → DO NOT LAUNCH. Launching produces a guaranteed refusal. │       |
 |            | │   │    → coverage = unverified                       ── BRANCH R  │       |
 |            | │   │      reason ∈ {bash-unavailable,                             │       |
 |            | │   │                agent-browser-not-installed, no-chrome-binary,│       |
 |            | │   │                smoke-test-failed, preflight-cache-absent,    │       |
 |            | │   │                preflight-cache-stale}                        │       |
 |            | │   └─ runtime_available == true → resolve URL (Diagram 2)         │       |
 |            | │        ├─ URL found   → LAUNCH                       ── BRANCH U  │       |
 |            | │        ├─ user declines → coverage = unverified,                 │       |
 |            | │        │                  reason = user-declined     ── BRANCH D  │       |
 |            | │        └─ unattended / no answer → coverage = unverified,        │       |
 |            | │                                   reason = no-url-resolved ─ BR X │       |
 |            | └──────────────────────────────────────────────────────────────────┘       |
 |            |                                   |          |             |                |
 |  BRANCH U: | spawn qa-browser  [ctx: url=U, flows=NONE (Decision E),   |                |
 |            |                     launched_under_recommendation: true]  |                |
 |            | spawn qa-visual   [same ctx]  (only when `ui` triggered) ─>|                |
 |            |                                   |          |             |                |
 |            |     Specialist re-checks the preflight cache itself (Step 1, unchanged).   |
 |            |     If it refuses now, contribution is UNVERIFIED, not CLEAN,              |
 |            |     because launched_under_recommendation == true.                          |
 |            |     ZERO fabricated findings in every refusal branch.                       |
 |            |<── report(s) (RETURNED) ─────────────────────────────────|                |
 |            |    all specialists succeeded, none UNVERIFIED → coverage = verified         |
 |            |    any recommended specialist UNVERIFIED/absent → coverage = unverified     |
 |            |                                   |          |             |                |
 |            | write scan.md, *.md ────────────────────────────────────────────────────>   |
 |            | spawn qa-report [ctx: reports + envelopes + runtime_recommendation +        |
 |            |                   runtime_coverage + runtime_unverified_reason] ──────────> |
 |            |<── verdict string = base ⊕ suffix (never assembled by prose) ──────────────|
 |            | write report.md, actionable-issues ─────────────────────────────────────>   |
 |<- verdict -|   "APPROVE (STATIC ONLY)" + Unverified Coverage section + the one command   |
```

**Why the gate lives in the orchestrator and not in `qa-scan`.** Branches R, D and X each need a fact `qa-scan` structurally cannot hold: the preflight cache (orchestrator-written, ADR-E′), an interactive user, and a network probe. `qa-scan` has no Bash by design (`rule-ownership.md` capabilities table: `qa-scan | static`). Putting the gate there would make it assert what it cannot verify — the same fabrication failure the refusal rule prohibits one layer down.

**Why BRANCH R does not launch.** `qa-browser` would refuse anyway (its Step 1 precondition). Launching costs a process and returns nothing new. The orchestrator already holds the cache it wrote; it short-circuits and records the cached reason verbatim. R7 in the proposal accepts the opposite ordering as also-correct; this design picks the cheap one and keeps the specialist-side precondition as defence in depth, because a stale orchestrator read must never become a fabricated "verified".

---

## Sequence Diagram 2 — URL resolution (Decision C), and the hard stop

```
Orchestrator                                         Shell (read-only)      User
     |                                                      |                 |
     | ── STEP 1 ── --url <url> present in the invocation?   |                 |
     |     YES → RESOLVED(url, source: "flag"). STOP.        |                 |
     |     The user stated the fact. No probe. No question.  |                 |
     |                                                      |                 |
     | ── STEP 2 ── project context has runtime.base_url?    |                 |
     |     (from qa-init; engram qa-init/{project} or qaspec/config.yaml)      |
     |     YES → RESOLVED(url, source: "project-context"). STOP.               |
     |                                                      |                 |
     | ── STEP 3 ── preflight.detected_start_hints[].likely_port present?      |
     |     candidate = http://localhost:{likely_port}       |                 |
     |     A hint says what command WOULD start the app.    |                 |
     |     It does NOT say the app IS running. So: PROBE.   |                 |
     |                                                      |                 |
     |     curl -s -o /dev/null -w '%{http_code}' --max-time 3 <candidate>    |
     |     ------------------------------------------------>|                 |
     |     ┌───────────────────────────────────────────────┐|                 |
     |     │ READ-ONLY. One request. GET. No body. 3s cap.  ││                 |
     |     │ Same class as the P0–P3 probes ADR-E′ already ││                 |
     |     │ assigns to the orchestrator (Assumption 1).   ││                 |
     |     └───────────────────────────────────────────────┘|                 |
     |<---- status ------------------------------------------|                 |
     |     2xx / 3xx / 401 / 403 → a server IS listening → RESOLVED. STOP.     |
     |     404 at the base URL   → ambiguous (something listens, but maybe not |
     |                             this app) → fall to STEP 4, quoting 404.    |
     |     000 / connect refused / timeout → NOT running → fall to STEP 4.     |
     |     curl absent            → STEP 3 collapses into STEP 4 (Assumption 1)|
     |                                                      |                 |
     | ── STEP 4 ── ask the user ONCE ------------------------------------------>|
     |     "Runtime verification is recommended (ui, api).                      |
     |      No running app found at http://localhost:3000.                      |
     |      Start it with `npm run dev` and re-run, or give me a URL."          |
     |      ↑ the detected command is QUOTED AS TEXT.                           |
     |<---- url --------------------------------------------------------------|
     |     answer is a URL → RESOLVED(url, source: "user"). STOP.              |
     |     answer is "no" / "skip" → UNRESOLVED(reason: user-declined). STOP.  |
     |                                                      |                 |
     | ── STEP 5 ── unattended run, or no answer                              |
     |     → UNRESOLVED(reason: no-url-resolved). Runtime does not execute.    |
     |     → Decision D takes over. The review COMPLETES.                      |
     |                                                                        |
     | ╔══════════════════════ HARD STOP ══════════════════════════════════╗  |
     | ║ At NO step does the orchestrator execute                          ║  |
     | ║ detected_start_hints[].command.                                   ║  |
     | ║ Not on failure. Not with user consent inline. Not with            ║  |
     | ║ detected_cleanup_hook available.                                  ║  |
     | ║ Reversing this is a proposal, not an edit (R4).                   ║  |
     | ║ Registered single-source literal → enforced by C4 + C9.           ║  |
     | ╚═══════════════════════════════════════════════════════════════════╝  |
     |                                                                        |
     | candidate_targets[] from the recommendation are DISPLAYED to the user   |
     | as suggested follow-up commands. They are NEVER auto-navigated (R3).    |
     | An unattended run tests the resolved base URL and nothing else.         |
```

**Precedence is strictly ordered and first-hit-wins**; a later step never overrides an earlier one, and no step is skipped except by its own miss. Step 3's accept-set is deliberately permissive on `401/403` (an auth-walled app is still an app) and deliberately conservative on `404` (a 404 at the base is the signature of *someone else's* server on that port — Decision C's rejected `localhost:3000` default is exactly this failure, and falling through to a question costs one prompt).

---

## The Verdict Algorithm with `runtime_coverage`

### Where `UNVERIFIED` enters, and how it differs mechanically from `CLEAN`

`UNVERIFIED` is **not** a fourth severity and never reaches Gate 1 or Gate 2. It enters at a new sub-step placed between existing Step 3 (veto logic) and Step 6 (report rendering) in `skills/qa-report/SKILL.md`:

```
Step 3b — Coverage Resolution (NEW; runs before any verdict string exists)

INPUT:  runtime_recommendation (from qa-scan, forwarded by the orchestrator)
        the set of returned specialist envelopes
        runtime_unverified_reason (from the orchestrator, when it short-circuited)

runtime_coverage =
    IF runtime_recommendation.recommended != true          → not-required
    ELSE IF every agent in runtime_recommendation.specialists returned
            status: success AND verdict_contribution != UNVERIFIED
                                                           → verified
    ELSE                                                   → unverified

# Partial coverage (qa-browser ran, qa-visual refused) resolves to `unverified`.
# Coverage is all-or-nothing per recommendation: understating what was checked
# is safe; overstating it is the defect this change exists to remove.
```

The mechanical difference in one table — this is the whole of Decision D:

| | `CLEAN` | `UNVERIFIED` |
|---|---|---|
| Findings contributed | 0 | 0 |
| Meaning | "I looked and found nothing" | "I did not look" |
| Enters Gate 1 (tier ceiling) | no | no |
| Enters Gate 2 (veto predicate) | no | no |
| Changes BLOCKER/WARNING/INFO counts | no | no |
| Changes `base_verdict` | no | **no** |
| Sets `runtime_coverage = unverified` | no | **yes** |
| Changes the rendered verdict **string** | no | **yes, via the suffix** |
| Emitted by | any specialist that ran | only `qa-browser` / `qa-visual`, and only when `launched_under_recommendation: true` |

The last row is R5's containment: a solo `/qa-browser <url>` that refuses still returns `CLEAN`, because a solo run has no consensus to poison. The contribution is a function of the launch context, not of the agent identity.

### The suffix is structural, not a reminder

The verdict string is not a literal a renderer may forget to qualify. It is a **two-token template** whose second token has a registered derivation:

```
severity-contract.md, appended to "## Verdict Logic (used by qa-report)":

  ### Runtime Coverage Suffix

  base_verdict is computed by Gate 1 + Gate 2 above and is NEVER altered by coverage.

  runtime_suffix(runtime_coverage, base_verdict):
      IF runtime_coverage != unverified            → ""     (empty string)
      IF base_verdict IN {REJECT, REJECT (VETO)}   → ""     (REJECT understates nothing)
      ELSE                                         → " (STATIC ONLY)"

  rendered_verdict = base_verdict + runtime_suffix(...)
```

```
qa-report/SKILL.md, Step 6 report template — the ONLY verdict line:

  ### Verdict: {verdict}{runtime_suffix}
```

Three independent mechanisms make a bare `APPROVE` on unverified coverage impossible to reach by omission:

| # | Mechanism | Failure it prevents | Enforced by |
|---|---|---|---|
| M1 | The template line carries **two** tokens. A renderer that resolves only `{verdict}` leaves a literal `{runtime_suffix}` in the output — visibly broken, not silently wrong. | "I forgot the qualifier" | shape of the artifact |
| M2 | `{runtime_suffix}` is registered in `rule-ownership.md` as `class: derived`, owner `severity-contract.md`, anchor `### Runtime Coverage Suffix`. | Deleting or emptying the derivation | **C3** (existing) |
| M3 | The template line is asserted verbatim; the un-suffixed form is asserted absent. | Someone "simplifies" the template back to one token | **C10(d)** (new) |

M1 is the one that matters at runtime: `(STATIC ONLY)` is not appended by a rule someone must remember — it is the resolution of a token the template already requires. Forgetting it produces a malformed report, which is loud.

### Report and metadata additions

```markdown
### Unverified Coverage                                  ← mandatory when coverage == unverified

Runtime verification was recommended for this review and did not run.

| Triggering categories | Specialists that did not run | Reason |
|---|---|---|
| {triggering-categories} | qa-browser, qa-visual | {runtime-reason} |

Static review found what static review can find. Nothing here was rendered,
loaded, or executed. To close the gap:

    /qa-browser <url>
```

```
## Metadata (added keys)
- **runtime_coverage**: {verified | not-required | unverified}
- **runtime_unverified_reason**: {null | one enum value}
```

The section is emitted **only** when coverage is `unverified` — never on `not-required`. That is R1's entire mitigation: the qualifier is rare by construction, because Decision B declined the fallback `business` category.

### The `runtime_unverified_reason` boundary (B9)

```
skills/_shared/qase/persistence-contract.md
│
├── ## Runtime Preflight Cache                         ← FROZEN (criterion 9)
│   ├── ### Preflight Cache Schema                     byte-identical
│   ├── ### Preflight Outcome Truth Table              byte-identical
│   └── `unavailable_reason` enum: 5 values            byte-identical
│         null, bash-unavailable, agent-browser-not-installed,
│         no-chrome-binary, smoke-test-failed
│
└── ## Review-Scoped Runtime Coverage                  ← NEW section, appended below
    └── `runtime_unverified_reason` enum: 9 values
          null                                    (coverage verified or not-required)
          bash-unavailable                        ┐
          agent-browser-not-installed             │ VALUE-COPIED from the preflight
          no-chrome-binary                        │ enum. Copied, not imported: the
          smoke-test-failed                       ┘ frozen line above is untouched.
          preflight-cache-absent                  ┐ cache STATES, which were never
          preflight-cache-stale                   ┘ unavailable_reason values
          no-url-resolved                         ┐ URL-resolution outcomes
          user-declined                           ┘ (Decision C, new)
```

Adding the last four to the preflight enum would corrupt a truth table that describes *environment probing*. `user-declined` is not an environment fact; it has no row in P0–P3 and never will. Two enums that share four spellings are cheaper than one enum that means two things.

**Byte-identity is verifiable, not asserted.** `sdd-verify` runs:

```bash
git show "$(git merge-base HEAD main)":skills/_shared/qase/persistence-contract.md \
  | awk '/^### Preflight Outcome Truth Table/,/^### Engram Preflight Cache Key/' > /tmp/before
awk '/^### Preflight Outcome Truth Table/,/^### Engram Preflight Cache Key/' \
      skills/_shared/qase/persistence-contract.md > /tmp/after
diff /tmp/before /tmp/after     # MUST be empty
```

---

## Coherence Checks for the New Invariants

Both follow the C1–C8 contract in `scripts/lib/coherence.sh`: caller-provided `pass`/`fail`/`warn`, a corpus-root parameter, registry-driven where a registry can carry the data.

### The no-auto-start rule — mostly zero new code

The normative sentence gets **one home** and is enforced by the existing C4, by adding one row to the `rules` table in `rule-ownership.md`:

```markdown
| no-auto-start | skills/_shared/qase/routing-rules.md | MUST NOT execute `detected_start_hints[].command` | skills/**,agents/** | — | 0 |
```

C4 already fails on zero hits (stale registry), on more than one hit (duplication), and on the hit living outside the declared owner. No new code path. This is deliberate: the cheapest correct enforcement is the one that already has negative fixtures.

But C4's scope is `skills/**,agents/**`, and criterion 10 requires the prohibition to also appear in **all 6** orchestrator documents under `examples/**`. Those are a different corpus with the opposite requirement — presence in every file, not uniqueness across files. That is a check QASE does not have yet.

### Check C9 — required-literal-present (new; the mirror of C1)

Catches: the exact drift measured on this repo — `Note: /qa-browser and /qa-visual use a URL as scope` exists in `examples/claude-code/CLAUDE.md:79` and **in none of the other five**.

New registry table:

```markdown
<!-- coherence:table required -->
| check_id | literal | files | min_count |
|----------|---------|-------|-----------|
| orch-no-auto-start | never starts the application | examples/claude-code/CLAUDE.md,examples/vscode/copilot-instructions.md,examples/cursor/.cursorrules,examples/gemini-cli/GEMINI.md,examples/codex/agents.md,examples/antigravity/qase-orchestrator.md | 1 |
| orch-url-flag | --url | (same 6) | 1 |
| orch-url-precedence | ### Runtime URL Resolution (ADR-C) | (same 6) | 1 |
| orch-runtime-step | Step 2b | (same 6) | 1 |
<!-- /coherence:table -->
```

```bash
check_c9_required_literal() {
    local reg="$1" root="${2:-.}" c9_ok=1 rows=0
    while IFS=$'\t' read -r id literal files min_n; do
        [ -z "$id" ] && continue
        rows=$((rows + 1))
        local flist_str="$files"
        while [ -n "$flist_str" ]; do
            local f="${flist_str%%,*}"
            flist_str="${flist_str#"$f"}"; flist_str="${flist_str#,}"; f="${f// /}"
            [ -z "$f" ] && continue
            [[ "$f" != /* ]] && f="$root/$f"
            if [ ! -f "$f" ]; then fail "C9 $id: file not found: $f"; c9_ok=0; continue; fi
            local n
            n=$(grep -cF -- "$literal" "$f" 2>/dev/null || true)
            if [ "$n" -lt "${min_n:-1}" ]; then
                fail "C9 $id: required literal '$literal' missing from $f (found $n, need ${min_n:-1})"
                c9_ok=0
            fi
        done
    done < <(coh_table "$reg" required)

    # A check that asserts nothing is a false green — mirror C4's zero-hit branch.
    if [ "$rows" -eq 0 ]; then
        fail "C9: 'required' table is empty or absent — check would pass vacuously"
        c9_ok=0
    fi
    [ "$c9_ok" -eq 1 ] && pass "C9 required-literal: all required literals present in all declared files"
}
```

The `rows -eq 0` branch is the important one and is the residue guard from Rollback below: reverting the registry while keeping `coherence.sh` would otherwise leave a check that passes because it read nothing.

### Check C10 — unverified-not-clean (new)

Catches: `UNVERIFIED` quietly collapsed back into `CLEAN`, in any of the four ways it can happen.

```bash
check_c10_unverified_not_clean() {
    local root="${1:-.}" c10_ok=1
    local sk="$root/skills" ag="$root/agents"

    # (a) No file may EQUATE the two tokens on one line.
    #     Matches: "UNVERIFIED -> CLEAN", "UNVERIFIED = CLEAN", "UNVERIFIED is treated as CLEAN",
    #              "UNVERIFIED maps to CLEAN", "UNVERIFIED (same as CLEAN)".
    local eq
    eq=$(grep -rn 'UNVERIFIED' "$sk" "$ag" 2>/dev/null \
         | grep -E 'UNVERIFIED[^|]*(->|→|==?|treated as|maps? to|same as|equivalent to)[[:space:]`]*CLEAN' \
         || true)
    [ -z "$eq" ] || { fail "C10a: UNVERIFIED equated with CLEAN: $eq"; c10_ok=0; }

    # (b) Refusal branches must not restate the old contribution (proposal criterion 6).
    local old
    old=$(grep -rn 'verdict_contribution: CLEAN' \
            "$sk/qa-browser/SKILL.md" "$sk/qa-visual/SKILL.md" 2>/dev/null || true)
    [ -z "$old" ] || { fail "C10b: refusal branch still returns CLEAN: $old"; c10_ok=0; }

    # (c) The refusal branches must still forbid fabrication — 3 per runtime skill (criterion 7).
    local f
    for f in qa-browser qa-visual; do
        local n
        n=$(grep -cF 'Do NOT fabricate findings from static reading' "$sk/$f/SKILL.md" || true)
        [ "$n" -eq 3 ] || { fail "C10c: $f has $n fabrication guards, expected 3"; c10_ok=0; }
    done

    # (d) The verdict template must carry BOTH tokens (M3 above).
    local tmpl="$sk/qa-report/SKILL.md"
    grep -qF -- '### Verdict: {verdict}{runtime_suffix}' "$tmpl" \
        || { fail "C10d: qa-report verdict template lost {runtime_suffix}"; c10_ok=0; }
    if grep -qE '^### Verdict: \{verdict\}[^{]*$' "$tmpl"; then
        fail "C10d: qa-report contains an unsuffixed verdict template line"; c10_ok=0
    fi

    # (e) R5 containment: UNVERIFIED lives in exactly 4 agent files, no more.
    local got want
    got=$(grep -rlF 'UNVERIFIED' "$ag" 2>/dev/null | xargs -n1 basename | sed 's/\.md$//' | sort || true)
    want=$(printf 'qa-browser\nqa-report\nqa-scan\nqa-visual')
    [ "$got" = "$want" ] || { fail "C10e: UNVERIFIED agent set is {$got}, expected {qa-browser,qa-report,qa-scan,qa-visual}"; c10_ok=0; }

    [ "$c10_ok" -eq 1 ] && pass "C10 unverified-not-clean: UNVERIFIED is distinct, contained, and structurally rendered"
}
```

Wired in `run_coherence_checks` after C8. Negative fixtures, following the existing `scripts/fixtures/coherence/` + `coherence_test.sh` pattern (each asserts **both** exit code and failing check id):

```
scripts/fixtures/coherence/
├── neg-missing-required-literal/   <- one orchestrator doc lacks the no-auto-start line  -> C9
├── neg-empty-required-table/       <- `required` table absent from the registry          -> C9
└── neg-unverified-as-clean/        <- qa-browser refusal restored to CLEAN + template
                                       reduced to `### Verdict: {verdict}`                 -> C10b, C10d
```

**Stated limitation, and a deviation from proposal criterion 12.** Criterion 12 asks for "a fixture *report* emitting a bare `APPROVE` while `runtime_coverage: unverified`" to fail the linter. The linter lints the **corpus**, not generated output — it can never see a report QASE produced at runtime. C10(d) implements the criterion at the only place a script can reach: the template that produces the report. `neg-unverified-as-clean` therefore contains a `qa-report/SKILL.md` whose template emits a bare `APPROVE`, and the check fires on that. This is surfaced here rather than discovered during apply; if the user wants the literal reading of criterion 12, the honest implementation is a runtime assertion in `qa-report`, not a linter check.

---

## Exactly What Changes in Each of the 6 Orchestrator Documents

The six documents drift because they are near-duplicates edited one at a time. Measured today: the probe sequence *did* land in all 6 (4 occurrences of `P2b`/`Branch table`/`SUGGEST ONLY`/`detected_start_hints` in each), but the `/qa-browser` URL-scope note landed in **1 of 6**. C9 exists to convert that class of drift from "hopefully noticed in review" into "exit 1".

Six edits per document, 36 sites. Anchors differ per file — apply must not blind-copy:

| Edit | What | Anchor (per file) |
|---|---|---|
| **E1** | Scope Syntax table: add row `` \| `--url <url>` \| Base URL for runtime verification (modifier) \| `` | `### Scope Syntax` — CLAUDE.md:68, vscode:79, cursor:69, gemini:77, codex:77, antigravity:77 |
| **E2** | **New section** `### Runtime URL Resolution (ADR-C)` — the 5-step precedence, the read-only probe command, the accept-set, and the literal `The orchestrator never starts the application` + `MUST NOT run a detected start command`. **This section carries the C9-pinned literals.** | insert immediately **after** `### Scope Resolution for qa-scan (ADR-F)` — CLAUDE.md:177, vscode:262, cursor:248, gemini:258, codex:258, antigravity:251 |
| **E3** | Pipeline block: insert `Step 2b: Runtime verification (conditional)` between the fan-out step and `qa-report`, naming BRANCHES N/R/U/D/X | `### Pipeline: /qa-review [scope]` — CLAUDE.md:219, vscode:107, cursor:97, gemini:105, codex:105, antigravity:100 |
| **E4** | Verdict Presentation: heading becomes `## Review Complete: {verdict}{runtime_suffix}`; add a `**Runtime coverage**:` line to the Summary block | `### Verdict Presentation` — CLAUDE.md:278, vscode:176, cursor:164, gemini:174, codex:174, antigravity:167 |
| **E5** | Commands table: `/qa-review [scope]` → `/qa-review [scope] [--url <url>]`; amend the `/qa-browser` row so it no longer reads as launch-by-hand only | `### QASE Commands` (CLAUDE.md:52) / `### Commands` (all others: vscode:67, cursor:57, gemini:65, codex:65, antigravity:65) |
| **E6** | The URL-scope note (**today in CLAUDE.md:79 only**) added to the other five, reworded: runtime specialists take a URL as scope and may be launched by `/qa-review` under a recommendation | end of `### Scope Syntax`, all 6 |

Naming traps recorded so apply does not "normalise" them into a diff: CLAUDE.md's section is `### Runtime Preflight Sequence (ADR-E')` while the other five say `### Runtime Preflight for qa-init (ADR-E')`; CLAUDE.md's rules list ends at 9, the others at 10; `cursor/.cursorrules`, `codex/agents.md` and `vscode` use ASCII `->` where CLAUDE.md uses `→`. E2's inserted prose must use each file's existing arrow convention or the C9 literals (which contain no arrows) are unaffected but the diff becomes noisy.

`examples/opencode/opencode.json` is **not** an orchestrator document and is not touched. Six documents, not seven.

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `skills/_shared/qase/routing-rules.md` | Modify | Delete `## Out-of-Band Specialists` (criterion 1). Add `## Runtime Recommendation`: trigger table (`ui`→browser+visual, `api`→browser, `auth`→browser, `business`→**no**, rest→no), the `runtime_recommendation` manifest block, and the **owned** no-auto-start literal. Sole owner of activation rules. |
| `skills/_shared/qase/severity-contract.md` | Modify | Add `UNVERIFIED` to the contribution enum; append `### Runtime Coverage Suffix` under Verdict Logic. Sole owner of verdict logic and of `(STATIC ONLY)`. |
| `skills/_shared/qase/persistence-contract.md` | Modify | **Append** `## Review-Scoped Runtime Coverage` (9-value enum). Reword the Refusal rule to make the contribution launch-context-dependent. Preflight schema, truth table and `unavailable_reason` enum untouched. |
| `skills/_shared/qase/rule-ownership.md` | Modify | +1 `rules` row (`no-auto-start`); +1 `rules` row (`static-only-qualifier`, owner `severity-contract.md`); new `required` table (4 rows × 6 files); +`{runtime_suffix}` (derived), `{triggering-categories}`, `{runtime-reason}` (descriptive) placeholders. |
| `skills/qa-scan/SKILL.md` | Modify | New Step 4b "Produce Runtime Recommendation"; manifest gains the `runtime_recommendation` block; envelope gains `runtime_recommendation`. No availability assertion — Bash stays absent. |
| `skills/qa-report/SKILL.md` | Modify | New Step 3b (Coverage Resolution); Step 6 verdict line becomes two tokens; new `### Unverified Coverage` section; 2 new metadata keys. |
| `skills/qa-browser/SKILL.md` | Modify | 3 refusal branches: contribution becomes `UNVERIFIED` when `launched_under_recommendation: true`. Zero-findings text unchanged (3 occurrences preserved). |
| `skills/qa-visual/SKILL.md` | Modify | Same 3 branches, same rule. |
| `skills/qa-init/SKILL.md` | Modify | Optional `runtime.base_url` in project context; Step 5 summary reports it. `SUGGEST ONLY — never run these` (line 158) unchanged. |
| `agents/qa-scan.md`, `qa-browser.md`, `qa-visual.md`, `qa-report.md` | Modify | Result-contract enums only (criterion 4 + C10e). |
| `examples/*/` × 6 | Modify | E1–E6 above. |
| `scripts/lib/coherence.sh` | Modify | `check_c9_required_literal`, `check_c10_unverified_not_clean`, wired into `run_coherence_checks`. |
| `scripts/coherence_test.sh` | Modify | 3 new fixture assertions. |
| `scripts/fixtures/coherence/neg-{missing-required-literal,empty-required-table,unverified-as-clean}/` | Create | Negative corpora. |
| `README.md`, `.atl/skill-registry.md` | Modify | `--url`, runtime routing, registry regeneration. |

Zero new production files. Three new fixture directories.

---

## Architecture Decisions

The proposal settled A–E. These ADRs record the *design-level* consequences each one forces, and the alternatives rejected at design time (not only at proposal time).

### ADR-A — `qa-scan` recommends; the orchestrator routes

**Context.** Activation needs two facts `qa-scan` cannot hold: runtime availability (preflight cache, orchestrator-written per ADR-E′) and a URL (user- and environment-owned). `qa-scan` is `class: static` in the capabilities table — no Bash, by design.

**Decision.** A separate `runtime_recommendation` block in the routing manifest. No column in the routing matrix.

| Option | Cost | Benefit | Decision |
|---|---|---|---|
| **Separate advisory block** | One extra hop; the orchestrator must not ignore it (enforced by Step 3b) | `qa-scan` asserts only what a diff proves; every install routes identically | **Chosen** |
| Matrix column | — | Uniform with the other six specialists | Rejected — activation becomes unconditional; every skills-only install fails routing |
| Orchestrator classifies categories itself | Removes a hop | — | Rejected — duplicates classification into 6 orchestrator documents; `qa-scan` already computes the categories |
| `qa-scan` reads the preflight cache (Read tool, no Bash) | Cheap | Would let `qa-scan` decide | Rejected at design time — it could read a cache it cannot validate the freshness *source* of, and the orchestrator would still own the URL. Two deciders, one decision. |

**Consequences.** `qa-scan`'s envelope gains one field. The orchestrator gains a decision gate it did not have (Diagram 1). `runtime_recommendation.recommended: false` must be emitted explicitly, not omitted — Step 3b distinguishes `not-required` from `unverified` by reading it, and an absent block is indistinguishable from a `qa-scan` that predates this change.

### ADR-B — Three triggers: `ui`, `api`, `auth`; `business` declined

**Context.** `qa-scan` Step 2 classifies unmatched files as `business` by default. Triggering on the fallback category means triggering on nearly every review.

**Decision.** `ui` → `qa-browser` + `qa-visual`; `api` → `qa-browser`; `auth` → `qa-browser`; `business` and the remaining five → no.

**Consequences.** `qa-visual` triggers on `ui` only (Assumption 4) — a CSS-free API change has no visual surface. R1's mitigation depends entirely on this ADR: the `(STATIC ONLY)` qualifier stays rare *because* the fallback category was declined. `--full` escalates the static squad only; runtime is gated on a resolvable URL, never on a flag. The trigger table is one table in one file, which is what makes R2's rollback a single edit.

**Rejected.** Trigger on `business` (every review demands a runtime; the recommendation stops meaning anything). Trigger on `database` (a migration has no user-observable surface *by itself*; if it reaches a screen, `ui` or `api` changed too). Make `--full` force runtime (a flag cannot conjure a URL).

### ADR-C — URL precedence resolved by the orchestrator, never started by it

**Context.** A `detected_start_hint` says what command *would* start the app, not that it *is* running. `qa-init/SKILL.md:158` already says "SUGGEST ONLY — never run these"; that rule bound `qa-init`, which has no Bash. The orchestrator does have a shell.

**Decision.** Five ordered steps, first hit wins (Diagram 2), with one read-only probe at step 3 and a registered prohibition on executing start commands.

**Consequences.** The orchestrator performs a network request it did not perform before (Assumption 1). It is bounded: one GET, 3-second cap, no body, only against a candidate derived from the user's own project. `candidate_targets[]` become display-only — R3's fabricated-BLOCKER-on-a-404 failure is structurally unreachable because nothing auto-navigates. The prohibition becomes a registered single-source literal (C4) plus a presence assertion in all 6 orchestrator docs (C9); reversing it requires editing a registry row that shows up in the diff.

**Rejected.** Auto-start via `detected_cleanup_hook` — the hook exists, which is precisely the temptation; rejected because the orchestrator would own a process lifecycle in the user's terminal and one failed cleanup leaves a server bound to a port. QA that mutates the environment it audits is a different product. Default to `http://localhost:3000` — a review that tested the wrong application produces confident findings about someone else's code, which is worse than testing nothing. Probe *before* consulting `--url` — rejected: probing a URL the user already stated is a network call with no decision attached to it.

### ADR-D — Unverified coverage is a verdict scope qualifier, not a finding

**Context.** Today the refusal rule returns `CLEAN`. "Found nothing" and "did not look" collapse into one token, so the consensus engine cannot tell them apart. That collapse *is* the defect.

**Decision.** Three mechanisms, all mandatory: `runtime_coverage` as a first-class field; `UNVERIFIED` in the contribution enum carrying **zero** findings; and a verdict string assembled as `base_verdict ⊕ runtime_suffix(...)` from a two-token template.

**Consequences.** The verdict *lattice* is untouched — Gate 1 and Gate 2 are byte-for-byte the same, and `base_verdict` is never altered by coverage. Only the rendered string changes. `REJECT` is deliberately unqualified: it already understates nothing, and suffixing it would imply the rejection is provisional. The suffix is structural (M1/M2/M3) rather than procedural, because a rule that says "remember to add the qualifier" is the same class of guarantee that produced the defect. The refusal rule itself is untouched — zero findings before, zero findings after (C10c pins three fabrication guards per runtime skill).

**Rejected.** Emit a WARNING for unverified coverage — fabricates a finding with no evidence (prohibited by the refusal rule) and makes every UI review on a skills-only install permanently non-clean, training users to ignore warnings. REJECT when runtime is unavailable — makes QASE unusable on 7 of 8 targets and contradicts clean degradation. Add the new reasons to the preflight `unavailable_reason` enum — corrupts a truth table that describes environment probing; `user-declined` has no P0–P3 row and never will (B9). Status quo — that is the defect.

### ADR-E — Page-level checks only; no flow inference in this slice

**Context.** A flow is a sequence of user *intentions*; a diff shows changed *symbols*. `qa-browser` L1/L2/L3-schema findings are veto-bearing.

**Decision.** `qa-browser` is launched with a URL and **zero** flows unless the user passes them explicitly.

**Consequences.** Runtime verification needs only a URL, which is exactly what Decision C resolves — the two decisions compose without a third input. The value captured is where `qa-browser`'s L1/L2 tiers already live: console errors, failed network requests, rendered-DOM accessibility, Core Web Vitals, responsive breakpoints. `candidate_targets[]` are carried in the recommendation and surfaced to the user, but the launch context sets `flows: NONE`, so a wrong route hint cannot become a wrong flow.

**Rejected.** Infer flows from `candidate_targets` — a guess wearing the costume of evidence, and a wrong flow produces confident veto-bearing findings, which is strictly worse than not running the flow. Deferred with a named successor: flow inference from e2e test files, the only honest source, because an e2e test *is* a written-down flow; it pairs naturally with the recorded `qa-flow` extraction trigger.

---

## Degradation Design — skills-only installs (7 of 8 targets)

`install_agents` is declared only by `examples/claude-code/qase.json`. Seven targets receive skills and no agents. This change must not make any of them worse, and must never let one of them silently pass a UI review as verified.

| # | Host state | Recommendation | URL | Specialists | `runtime_coverage` | Rendered verdict | Review status |
|---|---|---|---|---|---|---|---|
| 1 | Agents + agent-browser + URL | yes | resolved | run | `verified` | `APPROVE` | success |
| 2 | Agents + agent-browser, no URL, unattended | yes | none | not launched | `unverified` (`no-url-resolved`) | `APPROVE (STATIC ONLY)` | **success** |
| 3 | **Skills-only host**, agent-browser present, URL present | yes | resolved | run (no isolation, B5: skills are the product) | `verified` | `APPROVE` | success |
| 4 | **Skills-only host**, no agent-browser | yes | n/a | short-circuit (BRANCH R) | `unverified` (`agent-browser-not-installed`) | `APPROVE (STATIC ONLY)` | **success** |
| 5 | Any host, `/qa-init` never run | yes | n/a | short-circuit | `unverified` (`preflight-cache-absent`) | `APPROVE (STATIC ONLY)` | **success** |
| 6 | Any host, cache older than TTL | yes | n/a | short-circuit | `unverified` (`preflight-cache-stale`) | `APPROVE (STATIC ONLY)` | **success** |
| 7 | User answers "no" at Step 4 | yes | declined | not launched | `unverified` (`user-declined`) | `APPROVE (STATIC ONLY)` | **success** |
| 8 | No `ui`/`api`/`auth` in the diff | **no** | n/a | not launched | `not-required` | `APPROVE` | success |
| 9 | Runtime ran, `qa-visual` refused mid-review | yes | resolved | partial | `unverified` | `APPROVE (STATIC ONLY)` | success |

**Every row completes.** No row is an error, a `blocked` status, or a REJECT. Rows 2–7 and 9 are exactly the "must complete and be declared `(STATIC ONLY)`" requirement. Row 8 is R1's protection: the qualifier never appears when nothing triggered, which is what keeps it from becoming wallpaper.

The three degradation properties that must survive apply:

1. **`qa-scan` never asserts availability.** Its recommendation is diff-derived and identical on all 8 targets. A recommendation on a host with no runtime is correct, not a bug (proposal R7).
2. **The recommendation is advisory.** No install fails routing because a runtime is absent — the rejected "matrix column" alternative would have done exactly that.
3. **The refusal rule is untouched.** Rows 4–6 still return zero runtime findings. `UNVERIFIED` changes the *token*, not the *content*, of a refusal. C10(c) pins the three fabrication guards per runtime skill.

`scripts/install_test.sh` gains one assertion (criterion 13): a synthetic `qase.json` with no `install_agents` installs 12 skills, exits 0, and the installed `qa-report/SKILL.md` contains `runtime_coverage`.

---

## Rollback Design

### Full rollback

```bash
# 1. Repository
git revert -m 1 <merge-sha>            # or the commit range for a squashed PR

# 2. Orphans the revert may leave untracked
rm -rf scripts/fixtures/coherence/neg-missing-required-literal \
       scripts/fixtures/coherence/neg-empty-required-table \
       scripts/fixtures/coherence/neg-unverified-as-clean

# 3. MANDATORY — reinstall skills to EVERY declared target.
#    The repository revert does NOT reach a user's install directory.
bash scripts/install.sh                # for each target the user installed

# 4. Prove the reverted tree
bash scripts/lint_skills.sh && bash scripts/install_test.sh && bash scripts/coherence_test.sh

# 5. Regenerate .atl/skill-registry.md
```

**Step 3 is the only step with teeth**, and its failure mode is specific to this change: an installed `qa-report` whose template still reads `### Verdict: {verdict}{runtime_suffix}` paired with a reverted `qa-browser` that returns `CLEAN` will render a coverage section it can never populate — and, worse, will emit a literal unresolved `{runtime_suffix}` on every review. Mixed installs are visibly broken rather than silently wrong (that is M1 working as designed even during a botched rollback), but they are still broken.

### Residue after a correct full rollback

| Residue | Where | Harm | Action |
|---|---|---|---|
| Reports containing `(STATIC ONLY)` and `runtime_coverage` | engram `qase/{review-id}/final-report`, `qaspec/reviews/**` | None — historical records of what was true when written | None |
| `runtime.base_url` in a user's `qa-init` project context | engram `qa-init/{project}` / `qaspec/config.yaml` | None — a reverted `qa-scan` and orchestrator simply never read it | None (harmless orphan field) |
| Preflight cache | unchanged | None — B9 means this change never wrote to it | None |
| `required` registry table left behind while `coherence.sh` is reverted | `rule-ownership.md` | None — `coh_table` returns rows no function reads | None |
| **`check_c9` left behind while the registry is reverted** | `coherence.sh` | **Would pass vacuously** — a guard that asserts nothing | Prevented in code: the `rows -eq 0` branch fails loudly |
| `actionable-issues` artifacts from unverified reviews | engram | None — the bridge carries findings, and coverage produced none | None |

**Non-rollbackable side effects: none.** No external records, no user data, no schema migration, no persisted format that outlives a review.

### Partial rollback — the likely case

| Symptom | Revert | Survives |
|---|---|---|
| Too many reviews demand a runtime (R2) | Narrow the trigger table in `routing-rules.md` — one table edit | C, D, E intact. Coverage accounting still works; it just triggers less |
| URL resolution guessing wrong (R3) | Delete precedence steps 3 and 4 from the E2 section in all 6 docs; C9's `orch-url-precedence` row stays satisfied (the heading survives) | `--url` + `runtime.base_url` still resolve; misses land in `no-url-resolved` |
| `(STATIC ONLY)` too noisy (R1) | Change `runtime_suffix()` to return `""` unconditionally — **one function, one file**. Do NOT delete the token from the template, or C10(d) fires | `UNVERIFIED`, `runtime_coverage`, and the Unverified Coverage section all survive. Weaker, but the coverage fact stays visible |
| C9/C10 false positives (R4) | Remove the two calls from `run_coherence_checks`; leave the registry rows | Everything. Only regression protection is lost |
| Decision D reverted **entirely** | Restores the defect this change exists to fix | Requires explicit acknowledgement — not a routine revert |

The three-way independence is real: Decision B is a table, Decision C is a doc section plus a precedence list, Decision D is an enum plus a suffix function. No two share a file except `rule-ownership.md`, which is additive rows.

---

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Unit | `check_c9_required_literal` — missing literal, missing file, empty table | `scripts/coherence_test.sh` over 2 new fixtures |
| Unit | `check_c10_unverified_not_clean` — each of assertions (a)–(e) in isolation | `neg-unverified-as-clean` + per-assertion invocation, mirroring the existing `run_check` helper |
| Integration | Full corpus green as delivered (criterion 11) | `bash scripts/lint_skills.sh` |
| Integration | Negative fixtures exit 1 **with the expected check id** | `assert_fail_with_check` (existing) |
| Integration | Skills-only install, `runtime_coverage` present, exit 0 (criterion 13) | synthetic `qase.json` in `install_test.sh` |
| System | Preflight truth-table byte-identity (criterion 9) | the `git show` + `diff` command above, run by `sdd-verify` |
| System | Criteria 1–8, 10, 12 | `rg` assertions listed in proposal §4 |

---

## Open Questions

- [ ] **Criterion 12's literal reading.** The linter cannot see a generated report. C10(d) enforces the template instead. Confirm this substitution, or accept that criterion 12 needs a runtime assertion inside `qa-report` rather than a linter check.
- [ ] **Criterion 4 vs. R5 tension.** Criterion 4 requires `UNVERIFIED` in **four** agent files including `agents/qa-scan.md`; R5 wants the token contained to the agents that can emit it (three). This design satisfies both by having `qa-scan`'s occurrence document the enum it *forwards* in `runtime_recommendation`, never one it emits. C10(e) pins the set at exactly those four. Confirm, or drop `qa-scan` from criterion 4 and set C10(e) to three.
- [ ] **Reachability-probe dependency.** Step 3 uses `curl`. If `curl` is absent the step collapses into Step 4 (ask) — acceptable, but it means precedence step 3 is silently unavailable on minimal containers. Confirm `curl` as the probe, or specify a fallback (`wget --spider`, or drop step 3 entirely per Assumption 1).
