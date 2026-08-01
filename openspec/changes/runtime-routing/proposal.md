# Proposal: runtime-routing

**Change**: `runtime-routing`
**Phase**: proposal
**Input**: direct user brief; declared as the next change by `three-layer-architecture` §7 (Non-goals)
**Status**: ready for spec and design

---

## 1. Why

### What a verdict currently claims, and what it actually covers

`/qa-review --pr 42` never opens a browser. `routing-rules.md:96-108` declares `qa-browser` and `qa-visual` **out-of-band**: no column in the routing matrix, not activated by `qa-scan`, launched only when a human types `/qa-browser <url>` by hand.

So the pipeline runs six specialists that read source, and emits `APPROVE` on a UI change that was never rendered. The word `APPROVE` carries no qualifier, so it reads as "this was reviewed" when it means "this was read". **That overstatement is the exact failure QASE exists to eliminate.**

### Why now

Two completed changes built the entire runtime capability and left it unreachable:

| Built by | Capability |
|---|---|
| `runtime-proof-e2e` | 4-tier oracle model, tier-gated veto for `qa-browser`, agent-browser CLI migration, runtime preflight cache, step-by-step flow evidence |
| `three-layer-architecture` | Bash confined to exactly `qa-browser` and `qa-visual`; orchestrator owns environment probing and scope resolution (ADR-E′/ADR-F) |

Everything needed is in the repository. The orchestrator simply never calls it. The cost of waiting is not a missing feature — it is a stream of confidently wrong verdicts.

### The design problem this change exists to solve

`qa-scan` receives a **diff**. `qa-browser` needs a **running application at a URL**. Bridging those two worlds is the whole change, and the bridge cannot be a matrix column: *recommending* runtime verification is knowable from a diff; *deciding* it is not.

---

## 2. What changes

`qa-scan` gains the ability to **recommend** runtime verification. The orchestrator decides, resolves a URL, and launches. `qa-report` gains a **runtime coverage state** so no report can imply verification that never happened.

### In scope

1. A `runtime_recommendation` block in the routing manifest (Decision A).
2. A category → runtime-specialist trigger table with three triggers (Decision B).
3. An orchestrator-owned URL resolution precedence, including a new `--url` flag (Decision C).
4. A first-class `runtime_coverage` state, a new `UNVERIFIED` verdict contribution, a mandatory `(STATIC ONLY)` verdict qualifier, and an **Unverified Coverage** report section (Decision D).
5. Page-level runtime checks only; no flow inference (Decision E).

### Affected modules

**Contracts** (`skills/_shared/qase/`)

| File | Change |
|---|---|
| `routing-rules.md` | Replace "Out-of-Band Specialists" with "Runtime Recommendation": trigger table, manifest block, and the refusal contribution change from `CLEAN` to `UNVERIFIED`. Sole owner of activation rules |
| `severity-contract.md` | `UNVERIFIED` added to the contribution enum; verdict logic gains the `(STATIC ONLY)` qualifier. Sole owner of verdict logic |
| `persistence-contract.md` | Refusal-rule wording; new **review-scoped** `runtime_unverified_reason` field. The preflight `unavailable_reason` enum and its truth table are **not** touched |
| `rule-ownership.md` | Register the no-auto-start rule and the `(STATIC ONLY)` string as single-source literals |

**Skills**

`qa-scan` (recommendation step + manifest block), `qa-report` (coverage section, verdict qualifier, metadata), `qa-browser` and `qa-visual` (refusal returns `UNVERIFIED` when launched under a recommendation), `qa-init` (optional `runtime.base_url` in project context).

**Agents**: `qa-scan.md`, `qa-browser.md`, `qa-visual.md`, `qa-report.md` — result-contract enums only.

**Docs and tooling**: the 6 orchestrator documents under `examples/*/` (new `--url` flag, URL precedence, no-auto-start rule, runtime launch step), `README.md`, `scripts/lib/coherence.sh` registry entries, `.atl/skill-registry.md`.

---

## 3. Decisions

### Decision A — `qa-scan` recommends; it does not route runtime specialists

**Decision: `qa-scan` emits a separate `runtime_recommendation` block. The runtime specialists get NO column in the routing matrix.**

```yaml
runtime_recommendation:
  recommended: true
  reason: "ui category in 4 files; api category in 2 files"
  triggering_categories: [ui, api]
  specialists: [qa-browser, qa-visual]
  candidate_targets:                    # advisory only — never auto-navigated
    - route_hint: "/checkout"
      source: "src/pages/checkout.tsx"
```

Rationale: a matrix column means "activate". Activation needs two facts `qa-scan` structurally cannot hold — whether a runtime is available (preflight cache, orchestrator-owned per ADR-E′) and what URL to point at (user- and environment-owned). `qa-scan` has no Bash and no environment access by design. A column would make it assert what it cannot verify — the same fabrication failure the refusal rule already prohibits at the specialist level.

Rejected — matrix columns: uniform with the other six specialists. Rejected because activation becomes unconditional and every skills-only install fails routing.

Rejected — the orchestrator classifies categories itself: removes a hop. Rejected because it duplicates classification logic into six orchestrator documents, and `qa-scan` already computes the categories the recommendation derives from.

### Decision B — Three triggers: `ui`, `api`, `auth`. `business` is deliberately declined

| Category | Recommends | Why |
|---|:---:|---|
| `ui` | `qa-browser` + `qa-visual` | The rendered output **is** the artifact. Source is a description of it |
| `api` | `qa-browser` | `qa-browser` has network interception and the L3-schema tier. A response-shape or status-code mismatch is its highest-confidence oracle — a verified citation, not an inference |
| `auth` | `qa-browser` | Login, logout, redirect, and session expiry are runtime facts. This is also the highest-consequence category: an auth flow that breaks at runtime while passing static review is the worst verdict QASE can emit |
| `business` | **no** | `qa-scan` Step 2 classifies **unmatched files as `business` by default**. Triggering on the fallback category means triggering on nearly every review, and the recommendation stops meaning anything. Business logic reaches a browser through `ui` or `api`; if the diff touched those, they already trigger |
| `database`, `test`, `infra`, `config`, `docs` | no | No user-observable surface changes by themselves |

`--full` escalates the **static** squad only; it does not force runtime. Runtime is gated on a resolvable URL, not on a flag.

The tension is real in both directions: too eager and every review demands a running app until users learn to ignore the unverified banner; too shy and the capability stays dead. Three triggers, with the tempting fourth explicitly declined.

### Decision C — URL precedence, resolved by the orchestrator, never started by it

Resolution order, first hit wins:

1. `--url <url>` passed to `/qa-review` — the user stated the fact.
2. `runtime.base_url` from `qa-init` project context — set once per project.
3. `detected_start_hints[].likely_port` → `http://localhost:{port}`, **confirmed by a single reachability probe** by the orchestrator. A hint says what command *would* start the app, not that it *is* running.
4. Ask the user once, quoting the detected start command as a suggestion.
5. No answer or unattended run → runtime does not execute → Decision D.

**The orchestrator MUST NOT execute `detected_start_hints[].command`.** Settled in `runtime-proof-e2e` (`qa-init/SKILL.md:158` — "SUGGEST ONLY — never run these"); this change extends the rule from `qa-init` to the orchestrator. A reachability probe reads; a start command mutates the developer's environment. That line is the boundary.

`candidate_targets` are presented to the user, never auto-navigated. A wrongly derived route 404s, and a 404 becomes a confident BLOCKER about a page that was never changed.

Rejected — auto-start with `detected_cleanup_hook`: tempting, since the hook already exists. Rejected because the orchestrator would own a process lifecycle in the user's terminal, and one failed cleanup leaves a stray server bound to a port. QA that mutates the environment it audits is a different product.

Rejected — default to `http://localhost:3000`: a review that tested the wrong application is worse than one that tested nothing, because it produces confident findings about someone else's code.

### Decision D — Unverified coverage is a verdict scope qualifier, not a finding

**This is the load-bearing decision.** Three mechanisms, all mandatory:

1. **`runtime_coverage`** becomes a first-class review field: `verified` | `not-required` | `unverified`.
2. **`UNVERIFIED`** joins the `verdict_contribution` enum. Today the refusal rule returns `CLEAN`, which is the bug in one word: "found nothing" and "did not look" are the same token, so the consensus engine cannot tell them apart. `UNVERIFIED` still carries **zero findings** — the refusal rule is untouched.
3. **The verdict string gains a mandatory qualifier** when `runtime_coverage == unverified`: `APPROVE (STATIC ONLY)` and `APPROVE WITH WARNINGS (STATIC ONLY)`. A bare `APPROVE` becomes structurally impossible on a review that recommended runtime and did not get it. `REJECT` is unqualified — it already understates nothing.

Plus a mandatory **Unverified Coverage** report section naming the triggering categories, the specialists that did not run, the machine reason, and the exact command that closes the gap (`/qa-browser <url>`).

`runtime_unverified_reason` is **review-scoped**, not a preflight field: its enum is the preflight `unavailable_reason` values plus `no-url-resolved` and `user-declined`. Adding those to the preflight enum would corrupt a truth table that describes environment probing, not URL resolution.

Rejected — emit a WARNING: it fabricates a finding with no evidence (prohibited), and makes every UI review on a skills-only install permanently non-clean, which trains users to ignore warnings.

Rejected — REJECT when runtime is unavailable: makes QASE unusable on the 7 skills-only targets and contradicts clean degradation.

Rejected — status quo: that is the defect.

### Decision E — Page-level checks only; the first slice does not infer flows

**Decision: `qa-browser` is launched with a URL and zero flows unless the user passes them explicitly.**

A flow is a sequence of user *intentions*. A diff shows changed *symbols*. Inferring "the checkout flow" from `src/pages/checkout.tsx` is a guess wearing the costume of evidence — and a wrong flow produces confident L1/L2 findings, which are **veto-bearing**. That is strictly worse than not running the flow at all.

Page-level checks need only a URL and are exactly where `qa-browser`'s L1/L2 tiers live: console errors, failed network requests, rendered-DOM accessibility, Core Web Vitals, responsive breakpoints. Most of the value, zero inference risk.

Deferred to a later change: flow inference from e2e test files, which is the only honest source — an e2e test **is** a written-down flow. That change pairs naturally with the recorded `qa-flow` extraction trigger.

---

## 4. Success criteria

Mechanically checkable. A criterion a script cannot assert is not on this list.

1. `rg -n 'Out-of-Band' skills/_shared/qase/routing-rules.md` returns **zero** matches.
2. `routing-rules.md` contains a runtime trigger table whose recommending categories are exactly `ui`, `api`, `auth` — and `business` appears in it with an explicit non-recommendation.
3. `skills/qa-scan/SKILL.md` contains a `runtime_recommendation:` manifest block with keys `recommended`, `reason`, `triggering_categories`, `specialists`, `candidate_targets`.
4. `rg -c 'UNVERIFIED' skills/_shared/qase/severity-contract.md` is **≥ 1**, and the contribution enum in all four affected `agents/*.md` files includes `UNVERIFIED`.
5. `rg -n 'STATIC ONLY' skills/_shared/qase/severity-contract.md skills/qa-report/SKILL.md` matches in **both** files, and `rule-ownership.md` registers the literal with `severity-contract.md` as owner.
6. `rg -n 'verdict_contribution: CLEAN' skills/qa-browser/SKILL.md skills/qa-visual/SKILL.md` returns **zero** matches in the three refusal branches.
7. The refusal branches still specify **zero** runtime findings — `rg -c 'Do NOT fabricate findings from static reading' skills/qa-browser/SKILL.md` is **3**.
8. `qa-report`'s report template contains an `Unverified Coverage` section and metadata keys `runtime_coverage` and `runtime_unverified_reason`.
9. `persistence-contract.md`'s preflight truth table and its `unavailable_reason` enum are **byte-identical** to their pre-change state. The new reasons live only in the review-scoped field.
10. All 6 orchestrator documents under `examples/*/` document the `--url` flag, the 5-step precedence, and a literal statement that the orchestrator must not run start commands.
11. `bash scripts/lint_skills.sh` exits `0`.
12. **Negative fixture**: a fixture report emitting a bare `APPROVE` while `runtime_coverage: unverified` makes the linter exit `1`.
13. `bash scripts/install_test.sh` exits `0`, and a skills-only target still installs and runs with `runtime_coverage: unverified`, not an error.

---

## 5. Rollback plan

Required by `openspec/config.yaml`. Markdown only — no scripts change behaviour, no schema migrates, no persisted state format outlives a review.

**Blast radius**: 4 contracts, 5 SKILL.md files, 4 agent files, 6 orchestrator docs, `README.md`, 1 linter registry, 1 skill registry. Zero new files.

**Full rollback**

1. `git revert` the change's commit range (`git revert -m 1 <merge-sha>` if merged as a merge commit).
2. Re-run `scripts/install.sh` for every declared target — the revert restores the repository, not previously distributed skills and agents. An installed `qa-report` that still expects `UNVERIFIED` from a reverted `qa-browser` will render a coverage section it can never populate.
3. `bash scripts/lint_skills.sh` and `bash scripts/install_test.sh` must both exit `0`.
4. Regenerate `.atl/skill-registry.md`.

**Partial rollback — the likely case.** The decisions are independently revertible:

- **Too many reviews demanding a runtime?** Narrow the trigger table in `routing-rules.md` (Decision B) — one table edit. Decisions C, D, and E survive.
- **URL resolution guessing wrong?** Drop precedence steps 3 and 4, leaving `--url` and `runtime.base_url` only. Recommendation and coverage reporting both survive; unresolved URLs simply land in `unverified`.
- **`(STATIC ONLY)` qualifier too noisy?** Revert the qualifier alone and keep `UNVERIFIED` plus the report section. Weaker, but the coverage fact stays visible. Reverting Decision D **entirely** reinstates the defect this change exists to fix and requires explicit acknowledgement.

**Non-rollbackable side effects**: none. No external system records, no user data.

---

## 6. Risks and mitigations

| # | Risk | Impact | Mitigation |
|---|---|---|---|
| R1 | **`(STATIC ONLY)` becomes wallpaper.** Most installs lack a runtime; every UI review carries the qualifier and users stop reading it | The signal degrades to noise and the defect returns in a new costume | Qualifier appears **only** when a category actually triggered — never on `not-required`. The Unverified Coverage section always names the one command that removes it. Decision B declining `business` exists largely to keep this rare |
| R2 | **Trigger table too eager**, `api`-only backend changes demand a running frontend | Friction on reviews with nothing to render | `api` recommends `qa-browser` only, never `qa-visual`, and unresolved URLs degrade to `unverified` rather than blocking. Narrowing is a one-table revert |
| R3 | **A derived `candidate_target` 404s** and `qa-browser` files a confident BLOCKER about a page nobody changed | A fabricated defect at veto-bearing tier — the worst possible output | Decision C makes `candidate_targets` advisory only, never auto-navigated. Unattended runs test the base URL alone |
| R4 | **Pressure to auto-start the app** the first time precedence step 5 frustrates someone | Orchestrator owns a process lifecycle; stray servers on ports | The prohibition is a registered single-source literal in `rule-ownership.md`; the linter fails a contradicting restatement. Reversing it is a proposal, not an edit |
| R5 | **`UNVERIFIED` leaks into static specialists**, whose envelopes have no coverage semantics | Consensus engine sees a fourth state it cannot weigh | Enum extension is scoped to `qa-browser`, `qa-visual`, and `qa-report`. Criterion 4 pins the exact four agent files |
| R6 | **`three-layer-architecture` is not archived**; its capability specs still live in the change folder | Spec-phase capability names may collide on merge | Stated assumption 3 below. `sdd-spec` resolves names against the change folder, not only `openspec/specs/` |
| R7 | **Recommendation without a preflight cache.** `qa-scan` recommends; the cache is absent, so the specialist refuses anyway | A round trip that could have been skipped | Correct by design: the recommendation is diff-derived and the refusal is environment-derived. The user sees an actionable `/qa-init` instruction rather than silence |

---

## 7. Non-goals

- **Not re-opening the three-layer architecture, the capability boundary, or the sole-writer rule.** Bash stays on exactly `qa-browser` and `qa-visual`.
- **Not auto-starting the application.** Settled in `runtime-proof-e2e`; restated here as a boundary, not a decision.
- **Not relaxing the refusal rule.** Runtime specialists still return zero findings and still never fabricate from static reading.
- **Not flow inference.** Deferred with a named successor (Decision E).
- **Not a change to oracle tiers, severity ceilings, or the veto gate.** This change adds a coverage state; it does not touch how findings are weighed.
- **Not authentication handling for runtime reviews.** `qa-browser` already accepts optional credentials; wiring them into `/qa-review` is a separate change.
- **Not CI wiring**, and not a new specialist or command.

---

## 8. Assumptions stated plainly

1. **The orchestrator may perform a reachability probe** (a single read-only request to a candidate URL). This is the same class as the P0–P3 preflight probes ADR-E′ already assigns to it. If the user considers any orchestrator network call out of bounds, precedence step 3 collapses into step 4 (ask).
2. **`runtime.base_url` is an acceptable addition to `qa-init` project context.** It is one optional field and the difference between typing `--url` every review and once per project.
3. **`three-layer-architecture` lands before this change.** This proposal is written against `agents/`, `rule-ownership.md`, and the orchestrator-owned scope resolution that change introduces.
4. **`qa-visual` triggers on `ui` only.** A CSS-free API change has no visual surface to regress.

---

## 9. Capabilities

> Contract between this proposal and `sdd-spec`.

### New Capabilities

- `runtime-routing`: the `runtime_recommendation` manifest block, the category trigger table, and the orchestrator's URL resolution precedence including the no-auto-start boundary.
- `unverified-coverage`: the `runtime_coverage` state, the `UNVERIFIED` verdict contribution, the `(STATIC ONLY)` verdict qualifier, the review-scoped `runtime_unverified_reason` enum, and the Unverified Coverage report section.

### Modified Capabilities

- `docs`: `README.md` and the 6 orchestrator documents must describe `--url`, the URL precedence, and stop describing the runtime specialists as launch-by-hand only.

---

## 10. Next phases

- `sdd-spec` — Given/When/Then scenarios with RFC 2119 keywords for: the recommendation block schema, each trigger row (including the `business` non-trigger), each URL precedence step and the no-auto-start prohibition, each `runtime_coverage` transition, the verdict qualifier, and the negative fixture in criterion 12.
- `sdd-design` — the recommendation-to-launch sequence diagram (required by `openspec/config.yaml`), the `runtime_unverified_reason` enum boundary against the preflight truth table, and ADRs for A–E.

Both depend only on this proposal and can run in parallel.
