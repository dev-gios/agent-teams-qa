## Verification Report

**Change**: runtime-proof-e2e
**Verified**: 2026-07-31
**Mode**: openspec + engram (hybrid artifacts)
**Verdict**: **FAIL**
**Counts**: 5 CRITICAL / 7 WARNING / 6 SUGGESTION

---

### Completeness

| Metric | Value |
|--------|-------|
| Tasks in `tasks.md` | 25 |
| Tasks marked `[x]` | 25 |
| Tasks unchecked | 0 |
| Tasks claimed by apply-progress | 22 |

All checkboxes are checked. The count claimed by the tasks artifact and by `apply-progress.md` (22) does not
match the file (25 = 7 + 7 + 3 + 8). See W5.

---

### Build & Tests Execution

**Lint**: PASS — `bash scripts/lint_skills.sh`

```
=== Summary ===
  PASS: 108, FAIL: 0, WARN: 0
RESULT: ALL PASSED
lint exit=0
```

**Install test**: PASS — `bash scripts/install_test.sh`

```
=== Summary ===
  PASS: 12, FAIL: 0
RESULT: ALL PASSED
install exit=0
```

**Runtime backend**: `agent-browser 0.32.2` at `/home/devgio/.local/share/mise/installs/node/25.9.0/bin/agent-browser`

**Runtime execution evidence** — the qa-init P3 smoke test, run verbatim:

```
SESSION=qase-09437bc69835
[agent-browser] launched browser
✓ Done
open exit=0
{"success":true,"data":{"lifecycle":{...},"url":"about:blank"},"error":null}
geturl exit=0
✓ Browser closed
close exit=0
```

**Runtime execution evidence** — the three literal `eval --stdin` scripts written into `qa-browser/SKILL.md`,
run verbatim against a live page:

```
=== Step 4 (axe-core injection, SKILL.md:116-123) ===
✗ Evaluation error: SyntaxError: await is only valid in async functions and the top level bodies of modules
exit=1

=== Step 7 (responsive overflow, SKILL.md:188-195) ===
✗ Evaluation error: SyntaxError: Illegal return statement
exit=1

=== Step 8 (vitals fallback, SKILL.md:218-227) ===
✗ Evaluation error: SyntaxError: Illegal return statement
exit=1

=== Step 4 wait guard (SKILL.md:124) ===
agent-browser --session "$S" wait "#axe-core-script"
wait-axe exit=124   (timed out; the injected <script> is never assigned that id)

=== Control: forms that DO work ===
bare expression         → {"scrollWidth":1280,"viewportWidth":1280}   exit=0
async IIFE with await   → "object"                                     exit=0
```

**Coverage**: not applicable — Markdown skill files, no unit-test runner.

---

### Command Fabrication Audit (primary mission)

Every `agent-browser ...` string in `skills/qa-browser/SKILL.md`, `skills/qa-visual/SKILL.md`,
`skills/qa-init/SKILL.md` and `skills/_shared/qase/persistence-contract.md` was extracted with
`rg -no 'agent-browser[^\`\n|]*'` and checked against per-subcommand `agent-browser <cmd> --help`
(`network`, `wait`, `eval`, `console`, `errors`, `doctor`, `get`, `screenshot`, `set`, `diff`, `session`,
`record`, `snapshot`, `close`, `find`, `is`, `open`, `scroll`, `select`, `press`, `fill`, `type`, `check`,
`click`) plus top-level `agent-browser --help` for fall-through commands.

| # | Command as written | Where | Verdict |
|---|---|---|---|
| 1 | `session id --scope worktree --prefix qase` | browser:64,253 visual:61 init:165 | verified (`session --help` example) |
| 2 | `--session "$S" open <url>` | browser:67,166,209,260,355,501 visual:64,728 | verified (global flag precedes subcommand) |
| 3 | `--session "$S" open` (no url) | init:166 | verified (`open --help`: "Without a URL, launches the browser but stays on about:blank") |
| 4 | `--session "$S" wait --load networkidle` | browser:68,143,167,185,211,261,309 visual:65,314 | verified |
| 5 | `--session "$S" snapshot -i` | browser:69,138,163,168,186,319 | verified |
| 6 | `--session "$S" snapshot` | visual:68 | verified |
| 7 | `--session "$S" screenshot <path>` | browser:70,187,333 visual:66,316,509 | verified |
| 8 | `--session "$S" screenshot --full <path>` | browser:334 | verified |
| 9 | `--session "$S" screenshot --annotate <path>` | browser:335 | verified |
| 10 | `--session "$S" console` | browser:71 | verified |
| 11 | `--session "$S" console --json` | browser:85,324 | verified (`--json` is a documented global option of `console`) |
| 12 | `--session "$S" console --clear` | browser:271 | verified |
| 13 | `--session "$S" errors --json` | browser:325 | verified |
| 14 | `--session "$S" errors --clear` | browser:272 | verified |
| 15 | `--session "$S" network requests` | browser:72 | verified |
| 16 | `--session "$S" network requests --json` | browser:100,326 | verified |
| 17 | `--session "$S" network requests --clear` | browser:273 | verified |
| 18 | `--session "$S" network request <requestId>` | browser:102,328 | verified (`network --help`: `request <requestId>`; NOT in top-level help — help-per-subcommand was required to confirm) |
| 19 | `--session "$S" network route "<pat>" --abort` | browser:280 | verified |
| 20 | `--session "$S" network route "<pat>" --body '<json>'` | browser:282 | verified |
| 21 | `--session "$S" network unroute "<pat>"` | browser:345 | verified |
| 22 | `--session "$S" network unroute` | browser:364 | verified (`unroute [url]` — url optional) |
| 23 | `--session "$S" network har start` | browser:263 | verified |
| 24 | `--session "$S" network har stop <path>` | browser:366 | verified |
| 25 | `--session "$S" eval --stdin` | browser:116,188,218 visual:88,143,181,257,318,431,444,474 | flag verified; **the script bodies fail — see C1** |
| 26 | `--session "$S" wait "#axe-core-script"` | browser:124 | syntax verified; **semantically dead — see C5** |
| 27 | `--session "$S" wait --url "**/dashboard"` | browser:306 | verified |
| 28 | `--session "$S" wait --text "Welcome back"` | browser:307 | verified |
| 29 | `--session "$S" wait "<selector>"` | browser:308 | verified |
| 30 | `--session "$S" wait --fn "<expr>"` | browser:310 | verified |
| 31 | `--session "$S" click "<sel>"` / `click @e7` | browser:141,288,289 | verified |
| 32 | `--session "$S" find role button click --name "..."` | browser:142,287 | verified |
| 33 | `--session "$S" fill "<sel>" "<text>"` / `""` | browser:146,148,290 | verified |
| 34 | `--session "$S" press "Enter"` | browser:147,149,291 | verified |
| 35 | `--session "$S" type "<sel>" "<text>"` | browser:292 | verified |
| 36 | `--session "$S" check "<sel>"` | browser:293 | verified |
| 37 | `--session "$S" select "<sel>" "<value>"` | browser:294 | verified |
| 38 | `--session "$S" scroll down` | browser:295 | verified against `scroll --help` (`direction: up, down, left, right`); **absent from the command-reference doc — see S1** |
| 39 | `--session "$S" set viewport <w> <h>` / `1440 900` | browser:184,200 visual:310,358 | verified |
| 40 | `--session "$S" set media light reduced-motion` | visual:471 | verified (`set --help` example, verbatim) |
| 41 | `--session "$S" set media dark` | visual:481 | verified |
| 42 | `--session "$S" vitals --json` | browser:212 | verified by execution (see below); `vitals --help` falls through to top-level, which documents `vitals [url] [--json]` |
| 43 | `--session "$S" get url` / `get title` / `get text "<sel>"` | browser:315,316,317 | verified |
| 44 | `--session "$S" get url --json` | init:167 | flag verified; **the asserted output shape is wrong — see C4** |
| 45 | `--session "$S" is visible "<sel>"` | browser:318 | verified |
| 46 | `--session "$S" record start <path>.webm` | browser:264 | verified |
| 47 | `--session "$S" record stop` | browser:365 | verified |
| 48 | `--session "$S" session info --json` | browser:353 | verified |
| 49 | `--session "$S" close` | browser:372 init:168 | verified |
| 50 | `close --all` (cited only as forbidden) | browser:374,386,485 | verified as a real flag; correctly prohibited |
| 51 | `--session "$S" diff screenshot --baseline <f> -o <f>` | visual:504 | verified (`-b/--baseline`, `-o/--output`) |
| 52 | `agent-browser --version` | init:138 | verified — prints `agent-browser 0.32.2` |
| 53 | `agent-browser doctor --json` | init:143, persistence:92 | verified |
| 54 | `command -v agent-browser` / `npm i -g agent-browser && agent-browser install` | init:128,133 | verified (`install`, `install --with-deps` both documented) |

**Result: 0 fabricated commands, 0 invented flags, 0 wrong argument orders. Every subcommand and flag written
into a skill file exists in agent-browser 0.32.2.** The four fabrications caught during planning did not
return. Global-flag ordering is correct everywhere:
`rg -n 'agent-browser [a-z]+ .*--session' skills/` → **zero matches**.

`vitals --json` executed live against `example.com`:

```
{"success":true,"data":{"cls":{"entries":[],"score":0.0},"fcp":220.0,"hydration":null,
 "inp":null,"lcp":{"element":"p","size":12461,"startTime":220,"url":null},
 "ttfb":71.2,"url":"https://example.com/"},"error":null}
vitals exit=0
```

**The command layer is clean. The failures found by this verification are one layer deeper: the JavaScript
payloads passed to a correct command, and the severity/tier semantics wired around them.**

---

### Spec Compliance Matrix

| Capability | Requirement / Scenario | Evidence | Result |
|---|---|---|---|
| oracle-contract | Tier definitions and assignment (5 tiers) | `oracle-contract.md:21-27` full table with Source Kind, Available When, Citation Requirement, Max Severity, Veto-Bearing | PASS |
| oracle-contract | L3-schema requires `path:line` + verbatim literal | `oracle-contract.md:25,65-69,118,157,192` — stated five times, with worked examples | PASS |
| oracle-contract | L3-schema downgraded to L3-inferred when citation absent | `oracle-contract.md:65` ("automatic downgrade ... not to L3-schema with a note — actual downgrade"), `:126`, `:192`; re-enforced `qa-report:90-91`, `severity-contract:51-52` | PASS |
| oracle-contract | L3-inferred requires 2 independent signals | `oracle-contract.md:71-75` incl. the "same expression = one signal" rule | PASS |
| oracle-contract | L3-inferred caps at WARNING | `oracle-contract.md:26,180`; `severity-contract:24,50,107` | PASS |
| oracle-contract | L4 never blocks delivery | `oracle-contract.md:27,181`; `severity-contract:25,106` | **FAIL — C2** (`qa-browser:76` authors a BLOCKER at L4) |
| oracle-contract | Graceful degradation / absence declaration | `oracle-contract.md:131-137,161-167` | PASS |
| oracle-contract | Blocking matrix normative | `oracle-contract.md:171-184` | PASS |
| oracle-contract | All five other shared contracts reference oracle-contract.md | verified: severity-contract, issue-format, persistence-contract, engram-convention, openspec-convention, routing-rules — 1 reference each (6 files) | PASS |
| oracle-contract | Browser + Visual issue variants carry Oracle Tier | `issue-format.md:60,102` | PASS |
| oracle-contract | Metadata envelope carries `oracle_tier_breakdown` | key is spelled `oracle-tier-breakdown` in `qa-browser:455`, `qa-visual:628`, `issue-format:227`; `oracle_tier_breakdown` in `qa-report:249` | **PARTIAL — W2** |
| runtime-preflight | Preflight is the last qa-init step | `qa-init:112-114` | PASS |
| runtime-preflight | Bash availability recorded as distinct reason | `qa-init:116-123` (`bash-unavailable`) | PASS |
| runtime-preflight | agent-browser detected by version command | `qa-init:138` | PASS |
| runtime-preflight | Install instructions surfaced, not executed | `qa-init:131-136` ("do NOT execute") | PASS |
| runtime-preflight | doctor as primary diagnostic, exit 0 / exit 1 / unparseable branches | `qa-init:140-149` | PASS |
| runtime-preflight | Multi-name Chrome probing as fallback | `qa-init:151-160` — 4 probes, "NEVER probe a single name only (R4)" | PASS |
| runtime-preflight | Real smoke connection test | `qa-init:162-173` — commands correct, **asserted output shape wrong** | **FAIL — C4** |
| runtime-preflight | Start command detection — suggest, never execute | `qa-init:175-188` ("NEVER execute any detected command") | PASS |
| runtime-preflight | Cache schema and storage (openspec + engram) | `qa-init:194-198`; schema at `persistence-contract.md:60-98`; single-writer + TTL rules `:54,:56` | PASS |
| runtime-preflight | Subsequent qa-browser reads the cache | `qa-browser:50-61`, `qa-visual:47-52` | PASS |
| flow-evidence | Per-step record, 6 fields | `issue-format.md:148` table = Step, Action, Observed, Expected, Oracle Tier, Status, Artifact; `qa-browser:349` S11 requires all six | PASS |
| flow-evidence | FAIL carries severity; bare FAIL invalid | `issue-format.md:152-158`; `qa-browser:340` | PASS |
| flow-evidence | Console / error / network buffers cleared per step | `qa-browser:269-275` S1 (mandatory for N>=2, optional for step 1) | PASS |
| flow-evidence | Forced-failure via network interception | `qa-browser:277-283` S2 (`--abort`, `--body`) | PASS |
| flow-evidence | Video + HAR started before / stopped after; depth-gated | `qa-browser:263-264,365-366`; depth table `:473-475` | PASS |
| flow-evidence | Flow summary + Test Data Ledger | `issue-format.md:162-180`; `qa-browser:376-379` (read-only flows record `—`, not omitted) | PASS |
| flow-evidence | Artifact paths (openspec + engram) | `qa-browser:42-43,379` | PASS |
| browser-backend-migration | Zero MCP tool references | `rg 'navigate_page\|take_snapshot\|take_screenshot\|evaluate_script\|list_console_messages\|list_network_requests\|get_network_request\|resize_page\|performance_start_trace\|performance_stop_trace\|emulate(\|wait_for('` → **zero** | PASS |
| browser-backend-migration | Zero "Chrome DevTools MCP" strings | `rg -i 'chrome devtools mcp' skills/ README.md .atl/` → **zero** | PASS |
| browser-backend-migration | MCP `core` profile explicitly excluded | `qa-browser:15` | PASS |
| browser-backend-migration | All command mappings correct | see Command Fabrication Audit — 54/54 verified | PASS |
| browser-backend-migration | `wait --load networkidle` is the only valid form | intent met, but the spec's own check `rg -n "wait networkidle" skills/` returns **2** matches (rule text at `qa-browser:500`, `qa-visual:729`) | **PARTIAL — W3** |
| browser-backend-migration | Global flags precede the subcommand | `rg 'agent-browser [a-z]+ .*--session'` → **zero** | PASS |
| browser-backend-migration | `cookies get` available as default operation | **no `agent-browser cookies` command exists anywhere in `skills/`** | **NOT IMPLEMENTED — W6** |
| browser-backend-migration | Visual diff via CLI | `qa-visual:504` with `--baseline` + `-o` | PASS |
| browser-backend-migration | Registry rows updated | `.atl/skill-registry.md:92` (qa-browser) and `:101` (qa-visual) both describe the agent-browser CLI; neither mentions MCP | PASS |
| runtime-veto | `veto_power: true` in qa-browser frontmatter | `qa-browser/SKILL.md:12` | PASS |
| runtime-veto | severity-contract veto table has a qa-browser row | `severity-contract.md:38` — tier-gated to L1/L2/L3-schema | PASS |
| runtime-veto | V1+V2 sync invariant holds | both present in the same working tree | PASS |
| runtime-veto | L1 / L2 / L3-schema trigger veto | `severity-contract:57-60`, `qa-report:96-99` | PASS |
| runtime-veto | L3-inferred / L4 do NOT trigger veto | `severity-contract:38,40`; `qa-report:88-89` | PASS |
| runtime-veto | qa-report applies veto per holder; consensus cannot override | `qa-report:96-110` — per-finding predicate, independent evaluation | PASS |
| runtime-veto | qa-report specialist table lists qa-browser as veto holder | `qa-report:187` — "yes (tier-gated: L1/L2/L3-schema)" | PASS |
| runtime-veto | R11 resolved — no third inline veto definition | `qa-report` Step 3 pseudocode is semantically identical to `severity-contract.md:45-75`; no divergent third definition | PASS (but see W1) |
| runtime-veto | qa-visual remains non-veto | `qa-visual/SKILL.md:13` `veto_power: false` | PASS |

---

### Issues

#### CRITICAL

**C1 — All three literal `eval --stdin` scripts in `qa-browser/SKILL.md` are non-executable.**
`skills/qa-browser/SKILL.md:116-123` (Step 4, axe-core injection), `:188-195` (Step 7, responsive overflow),
`:218-227` (Step 8, vitals fallback). Every one uses a top-level `return`, which `agent-browser eval` rejects:

```
✗ Evaluation error: SyntaxError: Illegal return statement
exit=1
```

The Step 4 script additionally uses top-level `await`:
`✗ Evaluation error: SyntaxError: await is only valid in async functions and the top level bodies of modules`.

`agent-browser eval` evaluates the script as an expression, not as a function body. The working forms,
executed and confirmed:

```
# bare expression
({ scrollWidth: document.documentElement.scrollWidth, viewportWidth: window.innerWidth })
→ {"scrollWidth":1280,"viewportWidth":1280}   exit=0

# async IIFE
(async () => { const s = document.createElement('script'); s.src = '...axe.min.js';
  document.head.appendChild(s); await new Promise(r => s.onload = r); return typeof axe; })()
→ "object"   exit=0
```

Impact: the WCAG accessibility audit, the responsive-overflow measurement, and the Core Web Vitals fallback
all fail at runtime. These are three of the eight evidence-producing steps. This is the exact failure class
this change exists to eliminate: syntax that looks authoritative and does not run.
Fix: rewrite the three scripts as bare expressions or async IIFEs.

**C2 — `qa-browser/SKILL.md:76` instructs a BLOCKER at Oracle Tier L4, which the blocking matrix forbids.**

> Report as **BLOCKER**: "Application unreachable at {url}" — Oracle Tier: L4 (advisory) unless a spec covers availability.

This contradicts `oracle-contract.md:181` ("L4 | **Must NOT** | Advisory only. Cap at WARNING."),
`severity-contract.md:25`, and the same file's own Step 4 rule at `qa-browser:126`
("BLOCKER is NOT permitted at L4 — cap at WARNING regardless"). `qa-report` Gate 1 would downgrade the
finding and record a tier-gate-violation, so an unreachable application — the single most severe runtime
state — is reported as a WARNING while the skill promises a BLOCKER.

This is demonstrably a mistake rather than a deliberate exception: `qa-visual/SKILL.md:74` handles the
identical scenario correctly — *"Report as **WARNING**: 'Application unreachable at {url}' — Oracle Tier L4;
WARNING cap applies."* The two runtime specialists disagree on the same case.
Fix: change `qa-browser:76` to WARNING at L4, matching `qa-visual:74`.

**C3 — `qa-visual/SKILL.md` instructs authoring BLOCKERs at five sites while declaring it must never produce one.**
`:128` ("BLOCKER for critical inconsistencies"), `:233` ("BLOCKER for normal text below 4.5:1"),
`:234` ("BLOCKER for large text below 3:1"), `:328` ("SEVERITY: BLOCKER if navigation or main content
unreachable"), `:386` ("SEVERITY: BLOCKER if navigation disappears entirely").

Directly contradicted in the same file by `:720` ("All findings are subject to the L4 WARNING cap —
qa-visual MUST NOT produce BLOCKERs"), `:682` ("Finding severities reported | WARNING only (L4 cap)"),
and `:628` (breakdown hardcodes `L1: 0, L2: 0, L3-schema: 0`). `severity-contract.md:102` makes the
author-side ceiling normative: *"Authors of runtime findings MUST NOT assign a severity above the tier ceiling."*

The apply phase added the L4 cap language to qa-visual but never revised the per-step severity instructions
underneath it. An agent executing Steps 2, 4, 6 or 7 follows the step instruction and emits a malformed
BLOCKER on every run. The tier ceiling is stated but not enforced in the writing — answering verification
question 2 in the negative for qa-visual.
Fix: change all five to WARNING (or gate them behind an explicit non-L4 tier resolution).

**C4 — `qa-init/SKILL.md:171` asserts a smoke-test output shape that `agent-browser` does not produce.**
The skill states the preflight passes when *"`get url --json` returns `{"url":"about:blank"}`"*. Actual
output, executed verbatim:

```
{"success":true,"data":{"lifecycle":{...},"url":"about:blank"},"error":null}
```

`url` is nested under `data`, not at the top level. An agent applying the stated predicate literally records
`smoke_test: failed`, `runtime_available: false`, `unavailable_reason: "smoke-test-failed"`. Because
`qa-browser:50` and `qa-visual:47` both SKIP the entire skill unless `runtime_available == true`, this single
inaccurate assertion can silently disable the whole runtime evidence pipeline on a fully working machine —
the exact false-negative class that R4 (multi-name Chrome probing) was designed to prevent, reintroduced one
step later.
Fix: assert `data.url == "about:blank"`, or state the predicate as "the `url` field resolves to `about:blank`".

**C5 — `qa-browser/SKILL.md:124` waits for an element id that is never assigned.**
`agent-browser --session "$S" wait "#axe-core-script"` — the injection script two lines above creates the
`<script>` element with `document.createElement('script')` and sets only `.src`. No `id` is ever set, so no
element matching `#axe-core-script` can exist. Measured:

```
timeout 20 agent-browser --session "$S" wait "#axe-core-script"
wait-axe exit=124   (still waiting when killed; agent-browser default timeout is 25000 ms)
```

Combined with C1, Step 4 (Accessibility Audit) cannot complete: the injection errors, then the guard blocks
for 25 s and fails. Fix: drop the wait (the IIFE already awaits `onload`) or set `s.id = 'axe-core-script'`.

#### WARNING

**W1 — `qa-report/SKILL.md` still names only qa-security and qa-architect as veto holders in two places.**
`:16` (Purpose) — *"apply veto logic (qa-security and qa-architect BLOCKERs)"* — and `:165` (the VETO report
template) — *"**VETO**: qa-security and/or qa-architect found critical issues..."*. The normative Step 3
pseudocode `:96-99` and the specialist table `:187` were both updated for tier-gated qa-browser; these two
were not. Consequence: a qa-browser L1/L2/L3-schema veto fires correctly in the logic but renders a report
line that attributes it to the wrong agents. `git diff skills/qa-report/SKILL.md` confirms neither line
was touched.

**W2 — Metadata key spelling diverges between producers and consumer.**
Producers emit `oracle-tier-breakdown` (hyphen): `qa-browser:455`, `qa-visual:628`, `issue-format.md:227,235`.
Consumer and spec use `oracle_tier_breakdown` (underscore): `qa-report:249`,
`specs/oracle-contract/spec.md:160` (*"the format MUST be: `oracle_tier_breakdown: {...}`"*),
`specs/flow-evidence/spec.md:276`. qa-report parses specialist metadata blocks; a literal key lookup misses.

**W3 — The spec's own mechanical check for `wait --load` fails, and the task that claimed to run it is checked.**
`specs/browser-backend-migration/spec.md:195` requires `rg -n "wait networkidle" skills/` to return zero matches.
It returns 2: `qa-browser:500` and `qa-visual:729`, both inside the negative rule *"`wait networkidle` is
invalid — use `wait --load networkidle`"*. No invalid command actually exists, so the intent is met — but
task 4.4 ("Verify wait --load Correctness") is marked `[x]` while its stated criterion is literally unmet.
Either the spec check needs an exclusion for the rule text, or the rule needs rewording.

**W4 — qa-browser's new veto power is unreachable in the default invocation.**
Steps 2–8 hardcode `Oracle Tier: L4` with an explicit WARNING cap (`:88, :105, :125, :150, :170, :196, :229`).
Only Step 9 (Flow Engine) runs the Oracle Resolution Algorithm and can reach L1/L2/L3-schema, and Step 9 only
executes when the orchestrator supplies user flows (`:388` — "If NO user flows provided: skip this step").
The only BLOCKER authored outside Step 9 is the malformed one in C2. So without explicit flows, qa-browser
can produce zero BLOCKERs and its veto never fires. That is coherent with the change's thesis, but
`README.md:229` and `.atl/skill-registry.md:92` advertise "TIER-GATED VETO POWER" with no such caveat.

**W5 — Task count mismatch.** `tasks.md` contains 25 tasks (1.1–1.7 = 7, 2.1–2.7 = 7, 3.1–3.3 = 3,
4.1–4.8 = 8). The tasks artifact and `apply-progress.md` both report 22. All 25 are checked and 0 unchecked,
so nothing is missing — but "22/22 complete" is not the state of the file.

**W6 — `cookies get` scenario has no implementation.**
`specs/browser-backend-migration/spec.md:178-186` specifies `agent-browser cookies get` / `cookies set` /
`cookies clear`. `rg 'cookies' skills/` returns only two prose mentions
(`qa-visual:709` about script restrictions, `qa-browser:385` about session isolation) — zero commands.
The scenario is phrased conditionally ("WHEN the command is written, THEN it MUST use..."), so it is
vacuously satisfied rather than violated, but no capability was delivered for it.

**W7 — "vitals verified via help" is not verification, and the skill records it as if it were.**
`qa-browser:214-215` states: *"(verified via `agent-browser vitals --help`: falls through to top-level help,
confirming `vitals [url] [--json]` is valid)"*. A fall-through to top-level help proves only that `vitals`
has no dedicated help page — it does not execute anything. `apply-progress.md` deviation 3 repeats the claim.
`vitals --json` does in fact work (executed above, exit 0), so the conclusion is correct and the reasoning is
not. In a change whose thesis is "executed evidence over confident inference", leaving that sentence in the
skill teaches the wrong standard.

#### SUGGESTION

**S1 — `scroll down` (`qa-browser:295`) is absent from `agent-browser-command-reference.md`.**
`specs/browser-backend-migration/spec.md:206-213` designates that file as the verification authority. The
command is valid (`scroll --help`: `direction: up, down, left, right`), so this is a gap in the reference doc,
not in the skill. Add `scroll` to the reference.

**S2 — `severity-contract.md:117` conflicts with the tier ceilings.**
*"When in doubt between two levels, choose the HIGHER one and explain why"* sits 15 lines below the runtime
ceiling table that forbids exactly that for tiered findings. Add a carve-out: "does not apply to runtime
findings — the Oracle Tier ceiling is absolute."

**S3 — Citation correctness is unenforced; only citation presence is gated.**
`qa-report` Gate 1 (`:90`) tests `citation missing`. Nothing tests whether the cited `path:line` actually
contains the quoted literal. `oracle-contract.md:200` (anti-inflation rule 5) assigns that to a human
reviewer with no mechanical backstop, so a fabricated-but-well-formed `path:line` citation passes the gate
and carries BLOCKER + veto. Consider a verify-time check that resolves cited `path:line` pairs.

**S4 — qa-browser's stale-cache branch omits the mandated wording.**
`persistence-contract.md:56` requires the specialist to report
*"runtime_available: unknown — preflight cache stale, re-run /qa-init"*. `qa-browser:56-60` collapses stale
into the generic skip branch with `"Runtime backend unavailable: {cached unavailable_reason}"`, which for a
stale cache is empty. `qa-visual:50-52` has the same shape.

**S5 — The CWV report table assumes scalar metrics.**
`qa-browser:439` renders `LCP | {value}s`, but `vitals --json` returns
`"lcp":{"element":"p","size":12461,"startTime":220,"url":null}`. The value to render is `lcp.startTime`.
`cls` is likewise `{"entries":[],"score":0.0}`.

**S6 — qa-visual's `eval --stdin` usage is narrative-only, which propagates the C1 defect.**
Ten sites (`:88, :143, :181, :257, :318, :431, :444, :474`) say `eval --stdin → <description> (batch)` with no
script body. Given that every literal script in the sibling skill uses the broken `return` form, an executor
writing qa-visual's scripts from scratch will reproduce it. Add one canonical worked example showing the bare
expression / async-IIFE form.

---

### Scope Discipline

**PASS.** No API/endpoint contract testing and no DB/SQL verification leaked in.
`rg -in 'openapi|swagger|endpoint contract|api contract|SQL|database (query|verif)|migration'` across the
runtime skills and the oracle contract returns three hits, all legitimate:
- `oracle-contract.md:25,43` — OpenAPI/Prisma/GraphQL named as **sources to read for L3-schema expectations**, not as contracts to test.
- `qa-init:43` — pre-existing stack detection.
- `qa-init:192` — explicitly *refuses* the deferred behaviour: *"QASE will not invent cleanup, run migrations, or truncate tables."*

### Engram-Mode Baseline Diff Limitation

**PASS.** `qa-visual/SKILL.md:512-516` states it explicitly and refuses to fail silently:
*"Visual baseline diff is UNAVAILABLE in engram mode — engram stores markdown, not image bytes... Do NOT
silently drop this step — the limitation must appear in the report."* Step 8b is gated on
`artifact_store.mode == "openspec"` at `:500`.

### qa-visual Size Assessment

730 lines; diff is 107 additions / 58 deletions = **165 changed lines vs the ~65 forecast (2.5x)**. Assessed
for bloat: no duplicated headings, 11 distinct steps, viewport lists appear only twice (Step 6 spec at
`:303-305` and the Depth Controls table at `:674`), which is normal spec/summary pairing. The growth is
attributable to the new Step 8b (23 lines) and per-step oracle/severity language. **Structurally coherent —
no accumulated duplication.** The substantive problem is C3 (contradictory severity instructions), not size.

### Untracked Artifacts

`git status --short`: 12 tracked modifications, 2 untracked paths — `openspec/changes/runtime-proof-e2e/`
(the change's own artifacts) and `skills/_shared/qase/oracle-contract.md` (the new shared contract, task 1.1).
Both expected. `.atl/` is gitignored by design and its two rows were verified present and correct. Nothing
unexpected was created.

`git diff --stat`: 884 insertions, 310 deletions across 12 files.

---

### Verdict: **FAIL**

The command layer — the stated primary risk — is clean: 54 of 54 `agent-browser` command strings verified
against live `--help`, zero fabrications, zero invented flags, correct global-flag ordering everywhere. The
veto invariant holds, the R11 duplicate-veto-definition risk is resolved, the MCP migration is complete, the
registry is updated, scope discipline held, and both linters pass.

The change fails on execution, not on syntax. Three of eight evidence-producing steps in `qa-browser` are
built on JavaScript that raises `SyntaxError` on the first call (C1, C5), and the preflight gate that decides
whether any of it runs asserts an output shape `agent-browser` does not emit (C4). Two severity contradictions
(C2, C3) mean both runtime specialists are instructed to author findings their own tier ceilings forbid.

None of the five CRITICAL findings would have been caught by reading. All were found by running the code.
That is the thesis of this change, applied to the change itself.

**Do not archive.** Return to `sdd-apply` for C1–C5.
