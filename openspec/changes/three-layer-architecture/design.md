# Design: three-layer-architecture

**Change**: `three-layer-architecture`
**Phase**: design
**Input**: `openspec/changes/three-layer-architecture/proposal.md` (authoritative — Decisions A, B, C, D are settled)
**Reference patterns**: `~/.claude/agents/sdd-verify.md` (thin), `~/.claude/agents/review-readability.md` (self-contained), `agents/qa-security.md` (approved, to be amended)
**Delivery**: single PR with `size:exception`; slices below are commit boundaries, not separate PRs

> Size note: the `sdd-design` skill sets an 800-word budget. `openspec/config.yaml` `rules.design` requires sequence diagrams and documented decisions, and the sibling `runtime-proof-e2e/design.md` is 1109 lines. Project convention wins; this document follows the sibling's shape.

---

## Technical Approach

QASE gains three layers with **three distinct owners**, so that every fact has exactly one home and a script can prove it.

```
┌────────────────────────────────────────────────────────────────────────┐
│ L0  Orchestrator (host-resident; CLAUDE.md and 5 siblings)             │
│     Owns: process spawning, scope→diff resolution, capability probing, │
│           and ALL filesystem writes. The SOLE WRITER.                  │
└────────────────────────────────────────────────────────────────────────┘
        ▲ spawns (isolated)          ▼ receives reports, writes artifacts
┌───────┴────────────────────────────────────────────────────────────────┐
│ L1  agents/qa-*.md  — 12 files, ≤ 120 lines each                       │
│     Owns: isolation, `tools:` (capability boundary), `description`     │
│           (routing). NOTHING ELSE. No procedure. No rules.             │
│     Claude-Code-shaped. OPTIONAL — skills work without it.             │
└────────────────────────────────────────────────────────────────────────┘
        ▲ "read your SKILL.md and your contracts"
┌───────┴────────────────────────────────────────────────────────────────┐
│ L2  skills/qa-*/SKILL.md — 12 files. THE DISTRIBUTABLE PRODUCT.        │
│     Owns: the procedure only. References rules, never restates them.   │
└────────────────────────────────────────────────────────────────────────┘
        ▲ reference-not-restate
┌───────┴────────────────────────────────────────────────────────────────┐
│ L3  skills/_shared/qase/*.md — 8 files (7 today + rule-ownership.md)   │
│     Owns: every normative rule, stated EXACTLY ONCE.                   │
│     rule-ownership.md is both the human index AND the linter registry. │
└────────────────────────────────────────────────────────────────────────┘
        ▲ parsed as a registry
┌───────┴────────────────────────────────────────────────────────────────┐
│ L4  scripts/lib/coherence.sh — the enforcement layer                   │
│     Reads L3's registry; asserts L1/L2/L3 obey it. Exit 1 on drift.    │
└────────────────────────────────────────────────────────────────────────┘
```

The architectural pattern is **declared-invariant enforcement**: a machine-readable registry declares what must be true, and a checker proves it against the corpus. The registry is not a second source of truth about the *rules* — it is a source of truth about *where rules live*. That distinction is what makes Decision C implementable without importing the pathology it removes.

Five boundaries are load-bearing and stated so `sdd-verify` can check them:

| # | Boundary | Rule | Why it matters |
|---|----------|------|----------------|
| B1 | **Isolation** | One specialist per process. An agent never reads another specialist's report. | Independence is the product (proposal §1). |
| B2 | **Capability** | `tools:` is the only enforcement point. No specialist has `Write`/`Edit`. Only `qa-browser` and `qa-visual` have `Bash`. | A restriction the platform cannot enforce is documentation, not a boundary. |
| B3 | **Persistence** | Specialists RETURN. The orchestrator WRITES the filesystem. `mem_save` is retained (memory store ≠ audited repo). | Decision B. |
| B4 | **Ownership** | A normative rule appears in exactly one file under `skills/_shared/qase/`. Everywhere else is a pointer. | Decision C; the root cause of four failed rounds. |
| B5 | **Portability** | `skills/` is complete and correct with zero agent files installed. No logic migrates upward. | "Zero dependencies. Pure Markdown. Works everywhere." |

---

## Sequence Diagram 1 — `/qa-review` today vs. after

### Today (measured, not assumed)

`examples/claude-code/CLAUDE.md` launches `Task(subagent_type: 'general-purpose', ...)`. `examples/vscode/copilot-instructions.md:14` and `examples/cursor/.cursorrules:12` say "ALWAYS **run** the corresponding sub-agent **skill**" — there is no isolation primitive named, because those hosts have none. "Sub-agent" is prose on 6 of 7 toolchains.

```
User        Orchestrator (ONE context, accumulating)          Filesystem
 |               |                                                 |
 | /qa-review    |                                                 |
 |-------------->|                                                 |
 |               | load qa-scan/SKILL.md          ─┐               |
 |               | resolve scope, read diff        │               |
 |               | produce routing manifest        │ ctx += scan    |
 |               | write scan.md ─────────────────────────────────>|
 |               |                                 │               |
 |               | load qa-architect/SKILL.md      │               |
 |               | read the SAME diff again        │ ctx += SOLID   |
 |               | conclude "layering is fine"     │  conclusions   |
 |               | write architect.md ───────────────────────────->|
 |               |                                 │               |
 |               | load qa-security/SKILL.md       │  <-- reads the |
 |               | "layering is fine" is ALREADY   │   architect's  |
 |               |  in context and colours what    │   conclusion   |
 |               |  it looks for                   │   as premise   |
 |               | write security.md ────────────────────────────->|
 |               |                                 │               |
 |               | ... 4 more specialists ...      │               |
 |               |                                 │               |
 |               | load qa-report/SKILL.md         │               |
 |               | "consensus" over conclusions    ─┘  6 voices,    |
 |               |  it produced itself                 1 opinion    |
 |<-- verdict ---|                                                 |
```

Three properties fall out of the shape, not from bad execution:
- **Cross-contamination**: specialist N reads specialist N−1's conclusions because they are in the same context window.
- **Nominal parallelism**: the fan-out is a loop.
- **No capability boundary**: every skill inherits the host session's tools. `qa-security` can run shell commands and write anywhere.

### After

```
User    Orchestrator (thin; SOLE WRITER)      agents/qa-*.md (isolated procs)   FS
 |            |                                        |                         |
 | /qa-review |                                        |                         |
 |----------->|                                        |                         |
 |            | resolve scope -> diff (git/gh)         |                         |
 |            | probe capabilities (see ADR-E')        |                         |
 |            |                                        |                         |
 |            | spawn qa-scan ------------------------>| [ctx: diff, scope]      |
 |            |<-- routing manifest (RETURNED) --------|                         |
 |            | write scan.md ---------------------------------------------->    |
 |            |                                        |                         |
 |   ╔════════ TRUE FAN-OUT — N processes, N contexts, no shared memory ═══════╗ |
 |            | spawn qa-architect ------------------>[ P1 ] tools: R,G,G,mem   | |
 |            | spawn qa-security ------------------->[ P2 ] tools: R,G,G,mem   | |
 |            | spawn qa-advocate -------------------->[ P3 ]                   | |
 |            | spawn qa-inclusion -------------------->[ P4 ]                  | |
 |            | spawn qa-performance ------------------>[ P5 ]                  | |
 |            | spawn qa-test-strategy ---------------->[ P6 ]                  | |
 |            |                                        |                         | |
 |            |   P2 CANNOT SEE P1's conclusions. There is no channel.          | |
 |            |   P2 CANNOT write to the repo it is auditing. No Write tool.    | |
 |            |   P2 CANNOT execute the code it is auditing. No Bash tool.      | |
 |            |   Each P reads its SKILL.md + contracts from a COLD context.    | |
 |   ╚═════════════════════════════════════════════════════════════════════════╝ |
 |            |<-- report P1 (RETURNED, not written) --|                         |
 |            |<-- report P2 ... P6 -------------------|                         |
 |            | write architect.md, security.md, ... ------------------------>   |
 |            |                                        |                         |
 |            | spawn qa-report ---------------------->| [ctx: 6 reports +       |
 |            |                                        |  metadata envelopes]    |
 |            |<-- verdict (RETURNED) -----------------|                         |
 |            | write report.md, actionable-issues --------------------------->  |
 |<- verdict -|                                        |                         |
```

**The isolation boundary is the process boundary, and it is enforced by `tools:`, not by instruction.** The orchestrator's context holds diffs, review ids, and returned reports — never the reasoning that produced them. `qa-report` is the *only* specialist that legitimately sees other specialists' output, and it receives findings plus metadata envelopes, never raw artifacts (inherited boundary B4 of `runtime-proof-e2e`).

**What is lost, deliberately**: a specialist can no longer benefit from another's discovery mid-review. That correlation was never independence; §1 of the proposal shows it costs three missed defects. R9 accepts the token cost.

---

## Sequence Diagram 2 — a single specialist's lifecycle

```
Orchestrator      agents/qa-security.md      skills/... (installed)      Return
     |                     |                           |                    |
     | spawn(agent=qa-security, ctx={review-id, scope, diff, mode,          |
     |        detail_level, dismissed_patterns, project_context})           |
     |-------------------->|                           |                    |
     |                     | frontmatter applied by HOST before first token:|
     |                     |   tools: Read, Grep, Glob, mem_*               |
     |                     |   (no Write, no Edit, no Bash)                 |
     |                     |                           |                    |
     |                     | ===== STARTUP GUARD =====                      |
     |                     | read qa-security/SKILL.md-------->|            |
     |                     | read persistence-contract.md ---->|            |
     |                     | read severity-contract.md ------->|            |
     |                     | read issue-format.md ------------>|            |
     |                     |                           |                    |
     |                     |  BRANCH G1: a path is unreadable               |
     |                     |    resolve relative to dirname(SKILL.md) and   |
     |                     |    retry ONCE (install roots differ per tool)  |
     |                     |    still unreadable ->                         |
     |                     |      STOP. status: blocked.                    |
     |                     |      executive_summary names the MISSING FILE. |
     |                     |      findings: ZERO.                           |
     |                     |    NEVER proceed from memory: a specialist     |
     |                     |    without its contracts produces findings     |
     |                     |    whose severity cannot be trusted.           |
     |<-- {status: blocked, missing: severity-contract.md} -----------------|
     |                     |                           |                    |
     |                     |  BRANCH G2: procedure conflicts with contract  |
     |                     |    THE CONTRACT WINS. Proceed using it, and    |
     |                     |    emit a WARNING finding against the QASE     |
     |                     |    installation so it is fixed at the source.  |
     |                     |    (R2 mitigation — never silently pick one.)  |
     |                     |                           |                    |
     |                     | ===== ANALYSE =====                            |
     |                     | Read/Grep/Glob over scope only                 |
     |                     | apply severity per severity-contract.md        |
     |                     | format per issue-format.md                     |
     |                     |                           |                    |
     |                     |  BRANCH G3: needs a capability it lacks        |
     |                     |    (e.g. "run the test suite" -> needs Bash)   |
     |                     |    DO NOT route around it. DO NOT simulate.    |
     |                     |    status: partial + a stated limitation       |
     |                     |    naming the capability and the unreviewed    |
     |                     |    portion of scope.                           |
     |                     |                           |                    |
     |                     | ===== PERSIST (SPLIT) =====                    |
     |                     |  engram mode: mem_save(qase/{review-id}/       |
     |                     |    security-report)  <- ALLOWED (B3)           |
     |                     |  openspec mode: NOTHING. No Write tool exists. |
     |                     |  none mode: NOTHING.                           |
     |                     |                           |                    |
     |<-- {status, executive_summary, report_markdown, artifacts,          |
     |     verdict_contribution, risks, skill_resolution} ------------------|
     |                     |                           |                    |
     | openspec mode: orchestrator writes                                   |
     |   qaspec/reviews/{review-id}/security.md  <- SOLE WRITER (B3)        |
     |                     |                           |                    |
     |  BRANCH G4: orchestrator write fails (permissions, missing dir)      |
     |    create the review dir and retry ONCE; on second failure surface   |
     |    the report INLINE to the user and record artifacts: none.         |
     |    A returned report that could not be written is never discarded    |
     |    silently — that is R3's silent-artifact-loss failure mode.        |
```

**Why the startup guard is load-bearing under thin agents.** A thin agent carries no rules. If its contracts are unreadable it has nothing — unlike `review-readability`, which is self-contained and degrades to "still works". This is the concrete cost of Decision A and it is paid here, once, mechanically.

---

## Rule Ownership Map

Measured on the current tree (`skills/` + `agents/` only; `openspec/` history excluded):

| Symptom | Measurement | Command |
|---|---|---|
| `veto` in skill/agent/contract files | **59 occurrences across 14 files**, 45 of them in the 11 `skills/qa-*/SKILL.md` that mention it | `rg -c veto skills/ agents/` |
| Veto *rule strings* (`veto power`, `forces REJECT`, `requires explicit user acknowledgment`, `veto_power`) | **24 occurrences across 11 files** | `rg -c 'requires explicit user acknowledgment\|forces REJECT\|veto power\|veto_power' skills/` |
| `Oracle Tier` | **60 occurrences across 7 files** | `rg -c 'Oracle Tier' skills/` |
| `L3-schema`/`L3-inferred` tier tokens | **81 occurrences across 7 files** | `rg -c 'L3-inferred\|L3-schema' skills/` |
| Declared second source of truth | `skills/_shared/qase/severity-contract.md:15` — *"This section **restates** the ceilings that govern verdict production."* | — |
| `Write to \`qaspec/` (specialist self-write) | **16 occurrences across 11 files** | `rg -c 'Write to `qaspec/' skills/` |
| `HAS_BLOCKERS` | **15 occurrences across 10 files**; both `qa-visual` hits are *negations* | `rg -c HAS_BLOCKERS skills/` |

### Ownership assignments

| Rule | Owner (sole) | Duplicate sites to remove |
|---|---|---|
| Severity levels; verdict lattice `APPROVE < APPROVE WITH WARNINGS < REJECT < REJECT (VETO)` | `severity-contract.md` | `qa-report/SKILL.md` Step 3 inline pseudocode (3 rule strings); per-skill "Rules" restatements in `qa-architect`, `qa-security` (4 each), `qa-advocate`, `qa-inclusion`, `qa-performance`, `qa-test-strategy` (1 each) |
| Veto authority + veto-bearing predicate | `severity-contract.md` | same 11 files. `veto_power:` **frontmatter stays** — a declaration, not a restatement (proposal Assumption 6; `runtime-proof-e2e` criterion 3 pins exactly 3 `true`) |
| `qa-visual` BLOCKER carve-out | `severity-contract.md` | `qa-visual/SKILL.md` Rules, Step 10 verdict logic, report template, metadata block — the five-site defect from §1 |
| Oracle tier definitions, citation rules, downgrade table, blocking matrix | `oracle-contract.md` | `severity-contract.md:13-28` (the self-declared restatement + duplicated ceiling table) and `:108-119` (a *second* duplicate of the same table); `qa-browser/SKILL.md` (18 tier-token sites); `qa-visual`; `routing-rules.md` "Oracle-Tier-Aware Routing" bullets 2-3 |
| Finding structure, all three variants, metadata envelope, flow-evidence format | `issue-format.md` | per-skill inline report templates in all 12 SKILL.md |
| Persistence mode resolution, sole-writer rule, preflight cache schema + TTL + refusal | `persistence-contract.md` | the 16 `Write to \`qaspec/...\`` lines; per-skill mode tables |
| Engram key naming, artifact-type strings, recovery protocol | `engram-convention.md` | per-skill `Artifact type: X` lines become a pointer + the type string only |
| openspec paths, review-id format, slug derivation | `openspec-convention.md` | per-skill path literals |
| Activation, routing matrix, out-of-band declaration | `routing-rules.md` | `qa-scan/SKILL.md` inline matrix |
| **Ownership itself** (which file owns which rule) | **`rule-ownership.md` (NEW)** | — (new; no prior site) |
| Capability class per agent | **`rule-ownership.md`** declares the class; `agents/qa-*.md` frontmatter declares the instance | — |

**Removal discipline (R2).** A deleted restatement leaves a pointer, never a hole:

> Severity, veto authority, and verdict logic are owned by `skills/_shared/qase/severity-contract.md`. Apply them; do not restate them.

**Expected-vs-actual is not duplication.** The capability class in `rule-ownership.md` and the `tools:` line in the agent frontmatter are a *specification* and an *instance* that a checker compares. Duplication is two independent statements of the same rule with no comparator. Decision C forbids the latter, not the former.

---

## The Coherence Linter

### Where the registry lives

`skills/_shared/qase/rule-ownership.md` — human-readable Markdown, machine-parsed by `awk`. It ships with the skills to all 8 targets, so every host can read the ownership map even without agents.

Tables are anchored by HTML comments so parsing is positional-free:

```markdown
<!-- coherence:table rules -->
| rule_id | owner | literal | scope | allow_regex | allow_count |
|---------|-------|---------|-------|-------------|-------------|
| veto-ack | skills/_shared/qase/severity-contract.md | requires explicit user acknowledgment | skills/**,agents/** | — | 0 |
| tier-ceiling-l4 | skills/_shared/qase/oracle-contract.md | L4 | Must NOT | ... |
<!-- /coherence:table -->

<!-- coherence:table forbidden -->
| check_id | token | files | allow_regex | allow_count |
| visual-no-blockers | HAS_BLOCKERS | skills/qa-visual/SKILL.md,agents/qa-visual.md | never HAS_BLOCKERS\|intentionally absent | 2 |
<!-- /coherence:table -->

<!-- coherence:table placeholders -->
| token | class | derivation_owner | derivation_anchor |
| {page-slug} | derived | skills/_shared/qase/openspec-convention.md | ### `{page-slug}` — from a URL |
| {flow-slug} | derived | skills/_shared/qase/openspec-convention.md | ### `{flow-slug}` — from a flow name |
| {review-id} | derived | skills/_shared/qase/openspec-convention.md | ## Review ID Format |
| {count}     | descriptive | — | — |
<!-- /coherence:table -->

<!-- coherence:table capabilities -->
| agent | class |
| qa-security | static |
| qa-browser  | runtime |
| qa-report   | aggregator |
<!-- /coherence:table -->

<!-- coherence:table classes -->
| class | tools |
| static     | Read, Grep, Glob, mem_search, mem_get_observation, mem_save |
| runtime    | Read, Grep, Glob, Bash, mem_search, mem_get_observation, mem_save |
| aggregator | Read, Glob, mem_search, mem_get_observation, mem_save |
<!-- /coherence:table -->
```

Parser (`scripts/lib/coherence.sh`):

```bash
# Emits TSV rows of a named table. Anchored, not line-numbered.
coh_table() {  # $1 = file, $2 = table name
    awk -v t="$2" '
      $0 == "<!-- coherence:table " t " -->" { on=1; next }
      $0 == "<!-- /coherence:table -->"      { on=0 }
      on && /^\|/ && !/^\|[- |]*\|$/ {
          sub(/^\|/,""); sub(/\|$/,"")
          n=split($0, f, /\|/)
          for (i=1;i<=n;i++) { gsub(/^[ \t]+|[ \t]+$/,"",f[i]) }
          if (f[1] ~ /^(rule_id|check_id|token|agent|class)$/) next   # header
          line=f[1]; for(i=2;i<=n;i++) line=line "\t" f[i]; print line
      }' "$1"
}
```

### Check C1 — forbidden-token-present

Catches: `HAS_BLOCKERS` reintroduced into a file that declares it cannot emit BLOCKERs.

```bash
while IFS=$'\t' read -r id token files allow_re allow_n; do
  for f in ${files//,/ }; do
    [ -f "$f" ] || { fail "C1 $id: missing file $f"; continue; }
    total=$(grep -cF -- "$token" "$f" || true)
    if [ "$allow_re" = "—" ]; then exempt=0
    else exempt=$(grep -F -- "$token" "$f" | grep -Ec -- "$allow_re" || true); fi
    [ "$exempt" -eq "$allow_n" ] || fail "C1 $id: exemption drift in $f (expected $allow_n, found $exempt)"
    [ "$((total - exempt))" -eq 0 ] || fail "C1 $id: forbidden token '$token' in $f"
  done
done < <(coh_table "$REG" forbidden)
```

**Why `allow_regex` + `allow_count` and not a bare grep.** Measured today, `skills/qa-visual/SKILL.md` contains `HAS_BLOCKERS` twice — at line 696 (`never HAS_BLOCKERS`) and line 732 (`HAS_BLOCKERS is intentionally absent`). Both are *negations that state the rule correctly*. A naive deny-list is R4 (false positive → linter disabled → guard lost) on day one. The exact `allow_count` makes the exemption itself drift-detectable: a third occurrence fails even if it matches the negation pattern.

**Stated limitation**: `grep -c` counts lines, not occurrences. Two occurrences of a token on one line count as one. Accepted; registered literals are sentence-length, and a duplicated sentence on one line is not a realistic drift mode.

### Check C2 — variable-used-never-defined

Catches: `<evid>` used three times, never defined.

```bash
CORPUS=$(printf '%s\n' skills/qa-*/SKILL.md skills/_shared/qase/*.md agents/qa-*.md)
grep -ohE '\{[a-z][a-z0-9_-]*\}|<[a-z][a-z0-9_-]*>' $CORPUS | sort -u > "$TMP/used"
coh_table "$REG" placeholders | cut -f1 | sort -u                > "$TMP/declared"
undeclared=$(comm -23 "$TMP/used" "$TMP/declared")
[ -z "$undeclared" ] || fail "C2: token(s) used but not declared in rule-ownership.md: $undeclared"
unused=$(comm -13 "$TMP/used" "$TMP/declared")
[ -z "$unused" ] || warn "C2: declared but unused (dead registry entry): $unused"
```

Regex design notes, verified against the corpus: the lowercase-anchored class does **not** match shell expansions (`${TMPDIR:-/tmp}`), HTML fragments in `routing-rules.md` (`<div`, `<button`, `<input` — no closing `>`), or Markdown autolinks (`<https://…>` contains `:`). It **does** match CLI placeholders (`<url>`, `<sel>`, `<cmd>`) and template tokens (`{review-id}`, `{flow-slug}`), which is intended: they must be declared. Bootstrapping the registry means declaring the tokens that legitimately exist today (59 distinct matches in `qa-browser/SKILL.md` alone), which is one-time work and is the point — an undeclared token is precisely the defect class.

### Check C3 — template-token-without-derivation

Catches: `{page-slug}` used with no derivation algorithm.

```bash
while IFS=$'\t' read -r token class owner anchor; do
  [ "$class" = "derived" ] || continue
  [ -f "$owner" ] || { fail "C3 $token: derivation owner $owner missing"; continue; }
  grep -qF -- "$anchor" "$owner" || { fail "C3 $token: no derivation anchor '$anchor' in $owner"; continue; }
  body=$(awk -v a="$anchor" 'index($0,a){f=1;next} f&&/^#{2,3} /{exit} f' "$owner" | tr -d '[:space:]')
  [ -n "$body" ] || fail "C3 $token: derivation section '$anchor' is empty"
done < <(coh_table "$REG" placeholders)
```

The non-empty-body assertion is what distinguishes "a heading exists" from "an algorithm exists". Today `openspec-convention.md:97-127` satisfies this for `{page-slug}` and `{flow-slug}`; C3 is therefore a **regression guard** on a defect already fixed — which is exactly what criterion 16's negative fixture must prove, since a check that only ever passes has not been shown to work.

### Check C4 — rule-string-in-multiple-files

Catches: `severity-contract.md:15` restating `oracle-contract.md`.

```bash
while IFS=$'\t' read -r id owner literal scope allow_re allow_n; do
  mapfile -t hits < <(grep -rlF -- "$literal" ${scope//,/ } 2>/dev/null | sort)
  n=${#hits[@]}
  if [ "$n" -eq 0 ]; then fail "C4 $id: registered literal found nowhere — stale registry entry"
  elif [ "$n" -gt 1 ]; then fail "C4 $id: literal in $n files: ${hits[*]} (owner: $owner)"
  elif [ "${hits[0]}" != "$owner" ]; then fail "C4 $id: literal lives in ${hits[0]}, registry says $owner"
  else pass "C4 $id: single source of truth ($owner)"; fi
done < <(coh_table "$REG" rules)
```

The zero-hit branch matters as much as the many-hit branch: it catches a rule deleted from its owner while the registry still claims it, which would otherwise make the whole check vacuous. R4's escape hatch is deliberate registry amendment — visible in the diff, arguable in review.

### Checks C5-C8 — structural

| Check | Assertion | Strategy |
|---|---|---|
| **C5** bijection | `basename agents/qa-*.md .md` set == `basename skills/qa-*/` set, cardinality 12 | `comm -3` on two sorted lists; report orphans in both directions |
| **C6** agent shape | frontmatter has `name`, `description`, `model`, `tools`; `name` == filename stem == skill dir; `wc -l ≤ 120`; body contains `SKILL.md` and `persistence-contract.md`; `description` non-empty and matches `Use when\|Trigger:` (R7 — a description without a trigger clause never routes) | awk frontmatter slice, reusing `lint_skills.sh`'s existing `second_marker` idiom |
| **C7** capability | `rg '^tools:.*\b(Write\|Edit\|MultiEdit\|NotebookEdit)\b' agents/` → 0; `rg -l '^tools:.*\bBash\b' agents/` → exactly `qa-browser`, `qa-visual`; per-agent `tools:` set == its class expansion from the `classes` table (order-insensitive, `mem_*` matched by suffix so host-specific MCP prefixes do not break portability) | set comparison via `tr ', ' '\n' \| sort` |
| **C8** no self-write | `rg -n 'Write to \`qaspec/' skills/qa-*/SKILL.md` → 0 (16 today) | direct grep, count assertion |

### Wiring and the fixture harness

`scripts/lint_skills.sh` gains `source "$SCRIPT_DIR/lib/coherence.sh"` and calls `run_coherence_checks "$CORPUS_ROOT"`. `coherence.sh` defines no colours and no counters — it calls the caller-provided `pass`/`fail`/`warn`, exactly as `installer_core.sh` already consumes caller-provided `$OS`/`$RED`. This satisfies `openspec/config.yaml` `rules.apply` ("follow existing modular patterns in `scripts/lib/`").

Every check takes a **corpus root** parameter, which is what makes negative fixtures possible:

```
scripts/fixtures/coherence/
├── positive/                     <- minimal well-formed corpus, expect exit 0
├── neg-forbidden-token/          <- HAS_BLOCKERS reintroduced un-negated  -> C1
├── neg-undefined-placeholder/    <- <evid> used, undeclared               -> C2
└── neg-missing-derivation/       <- {page-slug} declared, anchor deleted  -> C3
```

`scripts/coherence_test.sh` runs each fixture and asserts **both** the exit code and the failing check id — a fixture that fails for the wrong reason is a false green. `scripts/fixtures/` is outside the production corpus globs, so the real lint never sees it.

---

## Capability Boundary Table

`mem_*` abbreviates `mcp__plugin_engram_engram__mem_search`, `…mem_get_observation`, `…mem_save`.

| Agent | Class | `tools:` | Justification | Needs Bash? |
|---|---|---|---|---|
| `qa-scan` | static | Read, Grep, Glob, mem_* | Classifies a diff supplied by the orchestrator; pattern-matches paths and content | No — see ADR-F |
| `qa-architect` | static | Read, Grep, Glob, mem_* | SOLID analysis is reading | No |
| `qa-security` | static | Read, Grep, Glob, mem_* | **`Write` removed.** A reviewer that can execute or write into the repo it audits is a larger attack surface than the code | No |
| `qa-advocate` | static | Read, Grep, Glob, mem_* | Failure-mode reasoning over source | No |
| `qa-inclusion` | static | Read, Grep, Glob, mem_* | Static a11y review; runtime a11y belongs to `qa-browser` | No |
| `qa-performance` | static | Read, Grep, Glob, mem_* | Complexity and query-shape analysis; measurement belongs to `qa-browser` | No |
| `qa-test-strategy` | static | Read, Grep, Glob, mem_* | Analyses coverage strategy, does not execute suites (Assumption 2 / R6) | No |
| `qa-browser` | runtime | Read, Grep, Glob, **Bash**, mem_* | `agent-browser` is CLI-only; Bash IS the backend (`runtime-proof-e2e` L0 boundary) | **Yes** |
| `qa-visual` | runtime | Read, Grep, Glob, **Bash**, mem_* | Same backend: `set viewport`, `screenshot`, `diff screenshot --baseline` | **Yes** |
| `qa-report` | aggregator | Read, Glob, mem_* | Consumes findings + metadata envelopes only; **no Grep** — it must never search raw artifacts (inherited B4) | No |
| `qa-init` | static | Read, Grep, Glob, mem_* | Stack detection is file reading; runtime probing is orchestrator-owned (ADR-E′) | No — see ADR-E′ |
| `qa-feedback` | static | Read, Grep, Glob, mem_* | Reads a report + user dismissals, produces patterns; orchestrator writes them | No |

Totals satisfy the criteria: `Write`/`Edit` → 0 files; `Bash` → exactly 2 files.

### What a specialist does when it lacks a capability

One protocol, owned by `rule-ownership.md`, pointed at from all 12 agents (branch G3 above):

1. **Never route around it.** No asking the orchestrator to run it, no simulating the result, no inferring the answer from file names.
2. **Report the limitation** in the return envelope: `status: partial`, naming the capability, the action it would have enabled, and the portion of scope left unreviewed.
3. **Never downgrade the limitation into a finding.** "I could not run the tests" is not a test-coverage BLOCKER.
4. **A capability gap is an amendment request**, scoped to one agent, argued on its own merits (R6) — never a blanket class widening.

Precedent for the wording: `agents/qa-security.md:43-48` already states this for Bash; the change generalises it and moves it to the shared owner.

---

## Multi-Tool Distribution

### `qase.json` extension (Decision D)

```json
{
  "id": "claude-code",
  "install":        { "linux": "$HOME/.claude/skills",  "windows": "$USERPROFILE/.claude/skills" },
  "install_agents": { "linux": "$HOME/.claude/agents",  "windows": "$USERPROFILE/.claude/agents" }
}
```

`install_agents` is **absent** from the other 7 `qase.json` files. That absence is the feature, not an omission: Assumption 4 records Claude Code as the only host with a native agents directory today, and Decision D's rejected alternative (deriving the path from `dirname(install)/agents`) argues against creating directories a tool will never read. Adding an empty block to all 8 would be that same guess with extra steps.

`examples/mock-tool/qase.json` is **not** modified. `install_test.sh` builds synthetic `qase.json` fixtures in `$TMP_DIR` (the pattern it already uses at lines 44-56 and 126-131), which keeps criterion 17 assertable without a real tool directory and resolves Assumption 3 in the negative.

### Installer flow

```
install.sh                json_parser.sh          installer_core.sh        FS
    |                          |                        |                   |
    | discover_tools()         |                        |                   |
    |  for examples/*/qase.json                         |                   |
    |------------------------->| validate_qase_json     |                   |
    |                          |  requires: id, name, install.$OS           |
    |                          |  install_agents NOT required <-- criterion 18
    |<-- TOOLS_IDS/NAMES/DIRS -|                        |                   |
    |                          |                        |                   |
    | install_tool(id, dir)    |                        |                   |
    |  target=$(get_install_path json $OS)              |                   |
    |------------------------------------------------->| install_skills_to_path
    |                          |                        |--- 12 skills + ->|
    |                          |                        |    _shared/qase/  |
    |                          |                        |                   |
    |  agents_raw=$(get_agents_path json $OS) || true   |                   |
    |------------------------->|                        |                   |
    |                          | sed -n '/"install_agents":/,/}/p'          |
    |                          |  (no collision: /"install":/ requires the  |
    |                          |   literal `"install":` and never matches   |
    |                          |   `"install_agents":`)                     |
    |<-- path | exit 1 --------|                        |                   |
    |                          |                        |                   |
    |  BRANCH: empty / exit 1  (7 of 8 tools today)     |                   |
    |    print "Agents: not supported by <tool> — skills-only install"      |
    |    exit status UNCHANGED (0). This is a supported configuration.      |
    |                          |                        |                   |
    |  BRANCH: path present                             |                   |
    |------------------------------------------------->| install_agents_to_path
    |                          |                        | mkdir -p; writable?|
    |                          |                        | cp agents/qa-*.md ->|
    |                          |                        | count == 12 or warn|
    |<-- "12 agents installed → ~/.claude/agents" ------|                   |
```

New symbols: `get_agents_path()` in `json_parser.sh` (mirrors `get_install_path`), `install_agents_to_path()` in `installer_core.sh` (mirrors `install_skills_to_path`, including the `make_writable` + `mkdir -p` + write-permission guard). `AGENTS_SRC="$REPO_DIR/agents"` in `install.sh`. `install_custom` prompts for an optional agents path and accepts empty.

### Degradation contract (B5, criterion 18)

| Host state | Skills | Agents | Behaviour |
|---|---|---|---|
| `install_agents` declared, dir writable | 12 | 12 | Orchestrator names agents in `subagent_type`; full isolation |
| `install_agents` declared, dir unwritable | 12 | 0 | Warn, exit 0, skills-only — install is not failed by an optional layer |
| `install_agents` absent (7 of 8 today) | 12 | 0 | Silent, expected, supported |
| Agents installed, orchestrator doc not updated | 12 | 12 | Orchestrator still uses `general-purpose`; agents are inert files. **Fail-safe, not fail-open** |

Skills never reference `agents/`. A SKILL.md that required its agent would break "Works everywhere" — C6 asserts the pointer direction is agent → skill only.

---

## Architecture Decisions

### ADR-A — Thin agents (`sdd-verify` pattern), not self-contained (`review-readability` pattern)

**Context.** Two real reference agents. `~/.claude/agents/sdd-verify.md` is 45 lines: frontmatter (`name`, `description`, `model`, `tools`), a "read the skill file and follow it exactly" instruction, a numbered pointer list, an engram-save clause, and a result contract. Zero rules. `~/.claude/agents/review-readability.md` is 26 lines and carries its eight review rules inline, with no skill behind it.

**Decision.** Thin. `agents/qa-security.md` (82 lines) is the shape: frontmatter → executor boundary → ordered contract pointers + startup guard → rule-ownership clause → capability boundary → evidence discipline → result contract.

| Option | Cost | Benefit | Decision |
|---|---|---|---|
| Thin (`sdd-verify`) | Startup guard needed; agent is useless without its skill | Skills stay the product; rules stay in one place across all 8 targets | **Chosen** |
| Self-contained (`review-readability`) | 12 new copies of rules that already drift across 5 sites; 6 toolchains cannot see agent-resident rules | One file, no indirection, no guard, degrades gracefully | Rejected |
| Status quo (skills only) | No isolation, no capability boundary | Zero work | Rejected — §1's empirical result |

**Rationale.** `review-readability` is genuinely simpler and its rules cannot go missing. It is rejected because it has no distributable artifact behind it: QASE ships to 7 toolchains, and an agent-resident rule is invisible to 6 of them. Self-contained agents would produce copies 13 and 14 of rules this change exists to reduce to 1 — importing the exact pathology being removed. The 120-line cap (criterion 2) is the mechanical guard: procedure or rules leaking upward shows up as length.

### ADR-B — Sole-writer persistence, split by store

**Decision.** Specialists return their report. The orchestrator writes the filesystem. `mem_save` is retained on all 12.

| Option | Blast radius on compromise | Orchestrator context cost | Decision |
|---|---|---|---|
| Specialist writes FS + engram (today) | Repo-wide write from a reviewer | Minimal | Rejected |
| Return everything; orchestrator writes both | Zero | 12 full reports through one context | Rejected |
| **Return FS artifacts; keep `mem_save`** | Memory store only, outside the audited repo | Report text transits once, is written, and is not retained | **Chosen** |
| Path-restricted `Write` | Zero in theory | Zero | Rejected — `tools:` accepts tool names, not paths |

**Consequences.** The `Execution and Persistence Contract` section of all 12 SKILL.md changes from *"If mode is `openspec`: Write to `qaspec/…`"* to *"If mode is `openspec`: return the report; the orchestrator writes it to `qaspec/…`"*. `agents/qa-security.md` must lose `Write` from line 9 **and** the justifying paragraph at lines 50-52 — the approved reference currently contradicts the decision it illustrates. R3 forces the SKILL.md rewrite and the 6 orchestrator docs into the same slice; branch G4 above is the residual-loss guard.

### ADR-C — De-duplication enforced by a registry the humans also read

**Decision.** `rule-ownership.md` is a single artifact serving two consumers: a human ownership index in `_shared/qase/` (installed everywhere) and the linter's registry (parsed by `awk`).

| Option | Tradeoff | Decision |
|---|---|---|
| Markdown registry in `_shared/qase/` | `awk` table parsing; anchor comments needed | **Chosen** |
| JSON/YAML manifest under `scripts/` | Trivial to parse — but needs `jq` (the repo deliberately avoids it, see `json_parser.sh`) and becomes a second source of truth beside the human doc | Rejected |
| Heuristic linter, no registry | Zero authoring cost | Rejected — R4 false positives kill the guard |
| Convention + code review | Zero cost | Rejected on evidence: four contradictory rounds |
| One monolithic contract file | Removes duplication by construction | Rejected — every specialist would read every rule; next 800-line artifact |

**Rationale.** A separate machine manifest would need to agree with the human ownership doc, and nothing would check that agreement — precisely the failure mode. One file, two readers. `jq` is already rejected repo-wide (`scripts/lib/json_parser.sh` parses JSON with `grep`/`sed`), so a JSON registry would either add a dependency or need a second hand-rolled parser.

### ADR-D — `qa-init` produces the preflight cache; the orchestrator writes it

**Context.** `persistence-contract.md:54` says *"`qa-init` is the ONLY writer of the preflight cache"*. Decision B removes `Write` from `qa-init`.

**Decision.** Split the role:
- **Producer (`qa-init`)**: the sole source of the cache payload. `qa-browser` and `qa-visual` still MUST NOT produce it (ADR-E of `runtime-proof-e2e` survives intact — one prober, one truth).
- **Writer (orchestrator)**: the only actor that persists it to `qaspec/preflight-cache.yaml`. In engram mode `qa-init` upserts `qa-init/{project}/preflight` directly via `mem_save` (B3).

Rewording at `persistence-contract.md:54`:

> **Single-producer rule**: `qa-init` is the ONLY producer of the preflight cache payload. `qa-browser` and `qa-visual` read the cache; they neither produce nor write it. **Single-writer rule**: in `openspec` mode the orchestrator is the only writer of `qaspec/preflight-cache.yaml`.

The same split applies to `qa-feedback` dismissal patterns and `qa-report`'s `report.md` + `actionable-issues` (proposal question 2, answered: yes, `qa-report` returns).

**Why the distinction is not pedantry.** ADR-E's rationale was *"three specialists independently probing produces three answers"* — that is a **producer** constraint. Nothing in it required the producer to hold the pen. Rewording preserves the guarantee and satisfies Decision B without touching runtime semantics.

### ADR-E′ — Capability probing is orchestrator-owned (amends `runtime-proof-e2e` ADR-E)

**Context — a genuine conflict between two settled artifacts.** `runtime-proof-e2e` gives `qa-init` a Step 4 that executes `command -v agent-browser`, `agent-browser doctor --json`, and a session smoke test. Those require Bash. Criterion 6 of this proposal pins Bash to exactly two agents: `qa-browser`, `qa-visual`.

| Option | Consequence | Decision |
|---|---|---|
| Grant `qa-init` Bash | Criterion 6 becomes "exactly three"; a pipeline role gains shell in every review | Rejected — cheapest, but reopens a settled criterion |
| `qa-init` records `bash_available: false` (its own P0 branch) | `runtime_available: false` forever → `qa-browser`/`qa-visual` permanently skip. Silently guts `runtime-proof-e2e` | **Rejected — unacceptable** |
| Runtime specialists self-probe | They have Bash — but ADR-E rejected this by name | Rejected |
| **Orchestrator runs P0-P3, passes results to `qa-init`, which produces the payload** | 4 short commands in the orchestrator context; `qa-init` stays Bash-free | **Chosen** |

**Rationale.** `persistence-contract.md:17` already states: *"**The orchestrator** is responsible for detecting Engram availability BEFORE launching any sub-agents."* Runtime backend detection is the same class of decision — environment capability, resolved once per pipeline, passed down. The chosen option makes the two detections consistent instead of splitting them across layers. Probe outputs are tiny (`command -v` path, `doctor --json`, one session id), so the orchestrator-context cost is bounded, unlike a full specialist report.

**Consequences.** `skills/qa-init/SKILL.md` Step 4 becomes *"read the probe results supplied in your context and produce the cache payload"*; the probe command sequence and the P0-P6 branch table move into the orchestrator documents (all 6). The preflight outcome truth table, cache schema, TTL, and refusal rule are unchanged. **CONFIRMED by the orchestrator.** An initial ruling reversed this to "grant `qa-init` Bash" based on the risk summary alone; on reading the ADR in full the reversal was withdrawn, because the probes relocate without the preflight breaking, and `persistence-contract.md:17` already establishes the orchestrator as the environment-capability prober. ADR-F is confirmed on the same basis.

### ADR-F — `qa-scan` receives a resolved diff instead of resolving one

**Context.** `skills/qa-scan/SKILL.md:59-64` maps scope to `git diff HEAD~N`, `git diff --staged`, `gh pr diff N`. Those need Bash; criterion 6 forbids it.

**Decision.** The orchestrator resolves scope → diff and passes the diff in `qa-scan`'s context. `qa-scan` classifies and routes; it never shells out.

**Rationale.** The orchestrator already owns scope (`CLAUDE.md` "Scope Syntax" table) and `git`/`gh` are state queries, which orchestrators run inline by convention. Rejected: giving `qa-scan` Bash (breaks criterion 6 and hands shell to the first agent in every pipeline); rejected: reconstructing the change set with Read/Glob (cannot see a diff — it would review the whole tree).

**Degradation.** When the host cannot pass a large diff, `qa-scan` falls back to file-list-only classification (path patterns only, no content patterns), records `confidence: reduced` in the manifest, and says so. Silent partial classification is not permitted.

**Deviation from the proposal, stated plainly.** The proposal lists all 12 SKILL.md as modified but does not name this actor change. It is surfaced here rather than discovered during apply.

---

## Migration Order

Delivery is **single PR with `size:exception`**. The five units below are ordered **commits** inside that PR, giving the reviewer a bisectable path through a diff that no ordering can bring under 400 lines.

```
S1 contracts ──> S2 agents ──> S3 skills+orchestrators ──> S4 tooling ──> S5 docs
   (owner set)     (pointers)      (writer identity)          (guard)      (index)
```

| # | Unit | Contents | Depends on | Why this order |
|---|---|---|---|---|
| **S1** | Ownership | `rule-ownership.md`; de-duplicate `severity-contract.md` (delete line 15 restatement + both ceiling tables), `oracle-contract.md`, `issue-format.md`, `routing-rules.md`, `persistence-contract.md` (ADR-B + ADR-D wording), the two convention files | — | Answers proposal question 3: **contracts first**. S2 and S3 write pointers *at* owners. Authoring 11 agents against contracts that still restate rules bakes in pointers that S1 would then invalidate — a rewrite of everything S2 produced |
| **S2** | Agent layer | 11 new `agents/qa-*.md`; amend `agents/qa-security.md` (drop `Write` from line 9, delete lines 50-52) | S1 | The rule-ownership clause must name a file that already owns the rule |
| **S3** | Skills + orchestrators | 12 SKILL.md: persistence rewrite (16 `Write to qaspec/` lines), strip restatements, insert pointers, `qa-scan` Step 1 (ADR-F), `qa-init` Step 4 (ADR-E′), `qa-report` Step 3; **plus all 6 orchestrator docs in the same commit** | S1, S2 | **R3 is a same-commit constraint, not a preference**: a specialist that stops writing before the orchestrator starts writing loses artifacts silently. Also where criterion 12's ≥ 15% shrink of `qa-visual` (803) and `qa-browser` (663) is realised |
| **S4** | Enforcement | `scripts/lib/coherence.sh`, `lint_skills.sh` wiring, 4 fixtures, `coherence_test.sh`, `install.sh` + `installer_core.sh` + `json_parser.sh` agent distribution, `install_test.sh` assertions, `examples/claude-code/qase.json` | S1, S2, S3 | **De-duplication must precede enforcement.** A linter landing before S1-S3 fails on its own repository; criterion 15 (`lint_skills.sh` exits 0 as delivered) is unsatisfiable until the corpus is clean |
| **S5** | Documentation | `README.md` (three layers; delete "7 Static + 2 Runtime" — there are 12), `.atl/skill-registry.md` regeneration | S1-S4 | Documents the end state; the registry must list agents that exist |

**Reviewer guidance.** Review in commit order. S1 is the only unit requiring semantic judgement (does a deletion lose a rule a reader needed? — R2). S2 is 11 near-identical files best reviewed as one template plus 11 diffs against it. S4 is the only unit with executable behaviour and carries its own negative fixtures as evidence.

**Constraints that survive re-slicing** if the single-PR decision is revisited: S1 before S2/S3; S3's two halves atomic; S4 after S1-S3.

---

## Rollback Design

### Full rollback

```bash
# 1. Repository
git revert -m 1 <merge-sha>            # or the commit range for a squashed PR

# 2. Orphans the revert may leave untracked
git rm -r --ignore-unmatch agents/
rm -f skills/_shared/qase/rule-ownership.md scripts/lib/coherence.sh
rm -rf scripts/fixtures/coherence scripts/coherence_test.sh

# 3. MANDATORY — uninstall distributed agents from EVERY declared target.
#    The repository revert does NOT reach a user's install directory.
rm -f "$HOME/.claude/agents/qa-"*.md         # + any other tool that declared install_agents

# 4. Prove the reverted tree
bash scripts/lint_skills.sh && bash scripts/install_test.sh   # both must exit 0

# 5. Regenerate .atl/skill-registry.md
```

**Step 3 is the only non-obvious step and the only one with teeth.** An installed `qa-security` agent whose `tools:` no longer matches the reverted SKILL.md is a specialist running against contracts that changed underneath it — exactly what the startup guard exists to prevent, except the guard cannot detect it: the files are all readable, they simply disagree. Skipping step 3 leaves a silently mismatched reviewer in the user's environment.

### Residue after a correct full rollback

| Residue | Where | Harm | Action |
|---|---|---|---|
| Engram observations written by specialists under the new flow | Memory store, `qase/{review-id}/*` | None — identical keys and format before and after; `mem_save` is unchanged by this design | None |
| `qaspec/reviews/**` artifacts written by the orchestrator | Repo (openspec mode) | None — paths and formats are byte-identical; only the *writer identity* changed | None |
| Installed agents on other machines / other tools | Each install target | Contract mismatch (above) | Step 3, per machine and per target |
| `install_agents` block in a user's local `qase.json` fork | User's fork | Points at an empty source dir; installer's absent-branch handles it | None |
| Preflight cache written under ADR-D/ADR-E′ | `qaspec/preflight-cache.yaml` or engram | None — schema unchanged | None |

**Non-rollbackable side effects: none.** No external records, no user data, no schema migration, no persisted format that outlives a review.

### Partial rollback — the likely case

| Symptom | Revert | Survives |
|---|---|---|
| Linter too strict / false positives (R4) | `scripts/lib/coherence.sh` + its `source` line | Agent layer, de-duplication, distribution. Only regression protection is lost |
| Sole-writer breaks openspec mode | Restore `Write` to the affected agent + its `Write to qaspec/…` SKILL.md line | Everything else. Two edits per specialist, mutually independent |
| One agent misroutes (R7) | Edit its `description` in place | Everything. Agent files are instructions, not code — no rebuild, no skills reinstall |
| Distribution breaks for one tool | Delete that tool's `install_agents` block | Falls back to skills-only, which criterion 18 proves works |
| ADR-E′ rejected by the user | Restore `qa-init` Step 4 probing; add `Bash` to `agents/qa-init.md`; amend criterion 6 to three files | Everything else; contained to one agent, one skill step, 6 orchestrator docs |

---

## Testing Strategy

| Layer | What | Approach |
|---|---|---|
| Unit | `coh_table` parser; each check function in isolation | `scripts/coherence_test.sh` over `scripts/fixtures/coherence/*` |
| Unit | `get_agents_path` — present, absent, malformed, missing-OS-key | Extend `test_json_parser_errors` in `install_test.sh` (existing pattern, lines 121-181) |
| Unit | `install_agents_to_path` — copies 12, honours unwritable target | Synthetic `$TMP_DIR` fixture, mirroring `test_installer_core` (lines 94-116) |
| Integration | Negative fixtures each exit 1 **with the expected check id** (criterion 16) | 3 negative + 1 positive corpus |
| Integration | Skills-only install still yields 12 skills, exit 0 (criterion 18) | Synthetic `qase.json` with no `install_agents` |
| Integration | No installed agent grants `Write` (criterion 17) | `rg` over the installed target after a mock install |
| System | Full lint green as delivered (criterion 15) | `bash scripts/lint_skills.sh` |
| System | Criteria 1-14, 19-20 | `rg` assertions listed in proposal §4, run by `sdd-verify` |

---

## Open Questions

- [ ] **ADR-E′ (blocking if rejected).** Moving runtime probing from `qa-init` to the orchestrator is the only way to satisfy criterion 6 without disabling runtime QA. The alternative — grant `qa-init` Bash and amend criterion 6 to "exactly three" — is one line of proposal text and zero design work. **Confirm the orchestrator-probing design, or amend criterion 6.**
- [ ] **ADR-F.** The orchestrator resolving scope → diff is not named in the proposal's affected-modules table. Confirm the actor change to `qa-scan` Step 1.
- [ ] **Registry bootstrap cost (C2).** Declaring every legitimate placeholder is one-time authoring work over a corpus with 59 distinct token matches in `qa-browser/SKILL.md` alone. If that lands as too heavy for S1, the fallback is to scope C2 to `agents/**` + `skills/_shared/qase/**` in this change and extend to `skills/qa-*/` in a follow-up — at the cost of not catching the `<evid>` class where it was actually found.
