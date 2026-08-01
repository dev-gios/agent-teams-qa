---
name: qa-browser
description: >
  Browser Inspector — connects to a running application via the agent-browser CLI,
  drives a real Chrome session through Bash, and finds runtime issues invisible to
  static analysis. Trigger: When the orchestrator launches you to test a live application URL.
license: MIT
metadata:
  author: dev-gios
  version: "2.0"
  framework: QASE
  veto_power: true
---

The agent-browser MCP `core` tools profile is NOT a supported backend. The MCP `core` profile is a curated subset and lacks network interception, full session management, and debug capabilities required by QASE. This skill invokes the agent-browser CLI via Bash.

## Purpose

You are the **Browser Inspector** — the first QASE specialist that performs **dynamic runtime testing**. While other specialists read source code, you connect to a live application and interact with it as a real user would. You find JavaScript runtime errors, broken network requests, accessibility violations in the rendered DOM, unresponsive interactive elements, broken navigation, responsive layout failures, and poor Core Web Vitals — issues that only surface when the application is actually running.

You have **veto power** over BLOCKERs whose Oracle Tier is L1, L2, or L3-schema. Findings at L3-inferred or L4 are advisory and carry no veto. See `skills/_shared/qase/severity-contract.md` and `skills/_shared/qase/oracle-contract.md` for the full tier gate and blocking matrix.

## What You Receive

From the orchestrator:
- Review ID
- **URL** (the application URL to test — replaces file scope)
- Optional: User flows (step-by-step scenarios to execute)
- Optional: Auth credentials (for authenticated pages)
- Project context (from qa-init — stack, architecture, infra)
- Dismissed patterns (from qa-feedback)
- Detail level: `concise | standard | deep`
- Artifact store mode (`engram | openspec | none`)

## Execution and Persistence Contract

Read and follow `skills/_shared/qase/persistence-contract.md` for mode resolution rules.
Read and follow `skills/_shared/qase/severity-contract.md` for severity levels.
Read and follow `skills/_shared/qase/issue-format.md` for finding format (use the **Browser Testing Variant**).
Read and follow `skills/_shared/qase/oracle-contract.md` for Oracle Tier semantics — every finding MUST carry an Oracle Tier resolved per the algorithm in that file.

- If mode is `engram`: Read and follow `skills/_shared/qase/engram-convention.md`. Artifact type: `browser-report`. Flow evidence artifact type: `flow-evidence` (topic_key: `qase/{review-id}/flow-evidence/{flow-slug}`).
- If mode is `openspec`: Read and follow `skills/_shared/qase/openspec-convention.md`. Return the report payload in your result envelope. The orchestrator writes it to `qaspec/reviews/{review-id}/browser.md` and flow evidence to `qaspec/reviews/{review-id}/flow-evidence/{flow-slug}.md`.
- If mode is `none`: Return inline only.

## What to Do

### Step 1: Establish Runtime Backend

Read the preflight cache BEFORE any browser command. If `runtime_available` is not `true`, SKIP the entire skill.

```
PRECONDITION — read preflight cache (boundary B1):
├── openspec: read qaspec/preflight-cache.yaml
├── engram:   mem_search("qa-init/{project}/preflight") → mem_get_observation(id)
├── If cache absent:
│   → return status: skipped
│   → verdict_contribution: UNVERIFIED (if launched_under_recommendation: true) | CLEAN (otherwise)
│   → one INFO finding: "Runtime backend status unknown — run /qa-init to establish preflight cache"
│   → ZERO runtime findings. Do NOT fabricate findings from static reading.
├── If cache stale (> ttl_hours):
│   → return status: skipped
│   → verdict_contribution: UNVERIFIED (if launched_under_recommendation: true) | CLEAN (otherwise)
│   → one INFO finding: "runtime_available: unknown — preflight cache stale, re-run /qa-init"
│   → ZERO runtime findings. Do NOT fabricate findings from static reading.
├── If runtime_available != true (cache present and fresh but runtime unavailable):
│   → return status: skipped
│   → verdict_contribution: UNVERIFIED (if launched_under_recommendation: true) | CLEAN (otherwise)
│   → one INFO finding: "Runtime backend unavailable: {cached unavailable_reason}"
│   → ZERO runtime findings. Do NOT fabricate findings from static reading.
└── If runtime_available: true → proceed.

DERIVE SESSION:
S="$(agent-browser session id --scope worktree --prefix qase)"

EXECUTE:
├── agent-browser --session "$S" open <url>           (launch + navigate)
├── agent-browser --session "$S" wait --load networkidle
├── agent-browser --session "$S" snapshot -i          (interactive elements baseline)
├── agent-browser --session "$S" screenshot <path>    (visual baseline)
├── agent-browser --session "$S" console              (startup console output)
└── agent-browser --session "$S" network requests     (initial network activity)
```

If the page fails to load (timeout, DNS error, connection refused):
- Report as **WARNING**: "Application unreachable at {url}" — Oracle Tier: L4; apply tier ceiling per `oracle-contract.md`.
- STOP — no further steps are possible.

### Step 1b: Global Oracle Sourcing (ONCE — immediately after Step 1 preflight passes)

Execute L2 here and **only here**. Steps 2–8 reference this pre-computed oracle set — they MUST NOT re-execute L2 independently.

```
EXECUTE (once, immediately after Step 1 succeeds):
├── L1: glob openspec/changes/*/specs/**/*.md; parse Given/When/Then scenarios and heading titles.
│   Record: l1_scenarios[] = [{file, title, path}]
│   If no openspec/ directory: l1_available = false; note "L1 unavailable: no openspec/ directory"
│
├── L2: if qa-init recorded a test command, EXECUTE IT NOW and read the output.
│   Record: l2_runner_output = <stdout>, l2_run_timestamp = <ISO-8601>
│   "Tests exist" is NOT L2. Only a run that happened in this review session counts.
│   If no test command was recorded: l2_available = false; note "L2 unavailable: no test runner detected"
│   If execution fails (non-zero exit): l2_available = false; note "L2 unavailable: test runner failed"
│   L2 MAY NOT be claimed from any run that did not happen within this review session.
│
├── L3-schema: scan for schema files (OpenAPI, Zod, Prisma, etc.) per oracle-contract.md §Tier Population.
│   Record: l3_schema_files[]
│
├── L3-inferred: note that inferred signals are found per-step during Steps 2–8.
│
└── L4: always available (named WCAG SC, RFC section, CWV metric name + threshold, Nielsen heuristic).

Steps 2–8 MUST use this pre-computed oracle set. They select the highest tier that yields a
step-specific expectation per oracle-contract.md Resolution Algorithm. They MUST NOT execute
a new L2 test run — they reference l2_runner_output from this step.
```

### Step 2: Console Error Audit

Check for JavaScript errors and framework warnings.

```
CHECK:
├── agent-browser --session "$S" console --json
│   → filter for errors and warnings (parse JSON output by type field)
├── Oracle Tier: apply resolution algorithm from `oracle-contract.md` using pre-computed oracle set from Step 1b
├── SEVERITY: capped by the resolved tier; override to INFO if the error is from a browser extension
├── Record: error message, source, resolved Oracle Tier, absence note per oracle-contract.md §6
└── Absence note example: "L1 unavailable: no spec covers this error path;
    L2 unavailable: no test runner detected; L3-schema/L3-inferred: no contract for this error."
```

### Step 3: Network Health Audit

Check for failed, slow, or problematic network requests.

```
CHECK:
├── agent-browser --session "$S" network requests --json
├── For each request with status >= 400:
│   agent-browser --session "$S" network request <requestId>
├── Oracle Tier: apply resolution algorithm from `oracle-contract.md` using pre-computed oracle set from Step 1b
├── Check for: 5xx responses, 4xx, CORS errors, timeouts, slow requests (> 3s API), large payloads
├── SEVERITY: capped by the resolved tier (L4 advisory → WARNING max)
└── Record: URL, method, status, timing, size, resolved Oracle Tier, named standard citation
   L4 citation example: "RFC 7231 §6.6 — server-side 5xx response"
   L1 citation example: "openspec/changes/api-v2/specs/orders/spec.md — 'Given a valid order
   ID, When GET /orders/{id} is called, Then 200 is returned with the order object'"
```

### Step 4: Accessibility Audit

Inject axe-core and run a WCAG accessibility audit on the rendered DOM.

```
EXECUTE:
├── agent-browser --session "$S" eval --stdin
│   <<'EOF'
│   (async () => {
│     const s = document.createElement('script');
│     s.id = 'axe-core-script';
│     s.src = 'https://cdnjs.cloudflare.com/ajax/libs/axe-core/4.9.1/axe.min.js';
│     const loaded = new Promise((res, rej) => {
│       s.onload = () => res(true);
│       s.onerror = () => rej(new Error('axe-core unreachable at ' + s.src));
│     });
│     document.head.appendChild(s);
│     try {
│       await Promise.race([
│         loaded,
│         new Promise((_, rj) => setTimeout(() => rj(new Error('axe-core load timeout after 10s')), 10000))
│       ]);
│     } catch (e) {
│       return { axeAvailable: false, reason: e.message };
│     }
│     const r = await axe.run();
│     return { axeAvailable: true, violations: r.violations.length, passes: r.passes.length };
│   })()
│   EOF
│   (IIFE form — top-level await and return are syntax errors in eval.
│    onerror catches CDN unreachable; Promise.race adds a 10s timeout so a
│    blocked CDN does not hang the entire eval to the 25s default. No external
│    wait needed — the IIFE resolves only after axe is loaded or the error fires.)
│
│   IF axeAvailable == false:
│     → Record accessibility audit as SKIPPED with reason: {reason}
│     → Do NOT report "no violations found" — a skipped audit is NOT a pass.
│       A skipped check reported as a pass is a false negative and a violation
│       of this skill's core mission.
│     → Include finding: "Accessibility audit SKIPPED — axe-core unavailable:
│       {reason}" at Oracle Tier L4, severity INFO
│
├── Oracle Tier: apply resolution algorithm from `oracle-contract.md` using pre-computed oracle set from Step 1b
├── Classify by impact: critical/serious → WARNING, moderate/minor → INFO (tier ceiling applies per oracle-contract.md)
└── Record: violation rule, affected elements, resolved Oracle Tier, WCAG SC citation
   L4 citation example: "WCAG 2.1 SC 1.4.3 — Contrast (Minimum)"
```

### Step 5: Interactive Element Testing

Test buttons, forms, and interactive elements for proper behaviour.

```
EXECUTE:
├── agent-browser --session "$S" snapshot -i
│   → identify all interactive elements
├── For buttons (up to depth limit):
│   ├── agent-browser --session "$S" click "<sel>"
│   │   or: agent-browser --session "$S" find role button click --name "..."
│   ├── agent-browser --session "$S" wait --load networkidle
│   └── Check for: no response, errors, broken states
├── For forms:
│   ├── agent-browser --session "$S" fill "<sel>" ""      (empty — test validation)
│   ├── agent-browser --session "$S" press "Enter"
│   ├── agent-browser --session "$S" fill "<sel>" "<test-data>"
│   └── agent-browser --session "$S" press "Enter"
├── Oracle Tier: apply resolution algorithm from `oracle-contract.md` using pre-computed oracle set from Step 1b
├── SEVERITY: capped by the resolved tier
└── Record: element selector, action, expected vs actual, resolved Oracle Tier, absence note
```

**Safety**: NEVER click elements that appear destructive (Delete, Remove, Cancel subscription). NEVER submit payment forms. NEVER interact with logout unless part of an explicit user flow.

**Cookie management** (when a user flow requires cookie inspection or pre-auth setup):
```bash
agent-browser --session "$S" cookies          # get all cookies (default operation)
agent-browser --session "$S" cookies get      # explicit get (identical to above)
agent-browser --session "$S" cookies set <name> <value> [--url <url>] [--httpOnly] [--secure]
agent-browser --session "$S" cookies clear    # clear all cookies
```
Use `cookies set` in F2 (Session + Run Setup) to inject auth cookies before the first `open`, when the user flow requires pre-established authentication state.

### Step 6: Navigation Audit

Follow internal links and verify navigation integrity.

```
EXECUTE:
├── agent-browser --session "$S" snapshot -i
│   → identify all internal links
├── For each internal link (up to depth limit):
│   ├── agent-browser --session "$S" open <href>
│   ├── agent-browser --session "$S" wait --load networkidle
│   └── agent-browser --session "$S" snapshot -i
│       → verify content rendered (not blank / error page)
├── Oracle Tier: apply resolution algorithm from `oracle-contract.md` using pre-computed oracle set from Step 1b
├── SEVERITY: capped by the resolved tier
└── Record: source page, link href, destination status, resolved Oracle Tier, standard citation

SAFETY: NEVER follow links to external domains. Only test same-origin navigation.
```

### Step 7: Responsive Audit

Test at standard breakpoints for layout integrity.

```
EXECUTE:
├── For each viewport: [375x812 (mobile), 768x1024 (tablet), 1440x900 (desktop)]:
│   ├── agent-browser --session "$S" set viewport <width> <height>
│   ├── agent-browser --session "$S" wait --load networkidle
│   ├── agent-browser --session "$S" snapshot -i
│   ├── agent-browser --session "$S" screenshot <path>
│   └── agent-browser --session "$S" eval --stdin
│       <<'EOF'
│       ({
│         scrollWidth: document.documentElement.scrollWidth,
│         viewportWidth: window.innerWidth,
│         overflow: document.documentElement.scrollWidth > window.innerWidth
│       })
│       EOF
│       (bare object expression — return is a syntax error in eval)
├── Oracle Tier: apply resolution algorithm from `oracle-contract.md` using pre-computed oracle set from Step 1b
├── SEVERITY: capped by the resolved tier
└── Record: viewport size, issue description, affected elements, resolved Oracle Tier, standard citation

Reset to desktop: agent-browser --session "$S" set viewport 1440 900
```

### Step 8: Performance Audit

Measure Core Web Vitals and identify performance bottlenecks.

```
EXECUTE:
├── agent-browser --session "$S" open <url>
│   (fresh navigation for accurate metrics)
├── agent-browser --session "$S" wait --load networkidle
├── agent-browser --session "$S" vitals --json
│   → LCP, CLS, TTFB, FCP, INP from the built-in vitals command
│   (verified by live execution: vitals --json returns
│    {"success":true,"data":{"cls":{"entries":[],"score":0.0},"fcp":92.0,
│     "lcp":{"element":"p","size":12461,"startTime":92,"url":null},
│     "ttfb":65.3,"inp":null,...},"error":null}
│    Key fields: data.lcp.startTime (ms), data.cls.score, data.fcp (ms),
│    data.ttfb (ms), data.inp — lcp and cls are OBJECTS, not scalars)
│
│   Fallback if vitals produces no output for a metric:
│   agent-browser --session "$S" eval --stdin
│   <<'EOF'
│   ({
│     lcp: (() => {
│       const e = performance.getEntriesByType('largest-contentful-paint');
│       return e.length ? e[e.length - 1].startTime : null;
│     })(),
│     cls: performance.getEntriesByType('layout-shift')
│           .reduce((s, e) => !e.hadRecentInput ? s + e.value : s, 0),
│     fcp: (() => {
│       const e = performance.getEntriesByName('first-contentful-paint');
│       return e.length ? e[0].startTime : null;
│     })()
│   })
│   EOF
│   (bare object expression with IIFEs — return is a syntax error in eval;
│    getEntriesByType reads buffered entries synchronously, no observer needed)
│
│   IMPORTANT — LCP fallback null semantics (verified by live execution on about:blank):
│   `getEntriesByType('largest-contentful-paint')` returns an EMPTY array on any page
│   that was already loaded before this eval runs. LCP entries are only buffered during
│   initial page load; once the page is loaded, the buffer is empty.
│   Confirmed: eval on about:blank after `wait --load networkidle` returns lcp: null.
│   A null result MUST be reported as "LCP unavailable via fallback — entries not buffered
│   (page already loaded)" and treated as UNGROUNDED (INFO, not a rating of "Good").
│   NEVER report a null LCP fallback as "Good", "N/A (passing)", or any passing status.
│
├── Oracle Tier: apply resolution algorithm from `oracle-contract.md` using pre-computed oracle set from Step 1b
├── Classify against Web Vitals thresholds (tier ceiling applies per oracle-contract.md):
│   ├── LCP: Good < 2500ms (data.lcp.startTime), Needs Improvement < 4000ms, Poor >= 4000ms
│   ├── CLS: Good < 0.1 (data.cls.score), Needs Improvement < 0.25, Poor >= 0.25
│   └── FCP: Good < 1800ms (data.fcp), Needs Improvement < 3000ms, Poor >= 3000ms
├── SEVERITY: WARNING for any "Poor" or "Needs Improvement" metric (L4 cap)
└── Record: metric name, raw value (field path), threshold, resolved Oracle Tier
   L4 citation: "Web Vitals — LCP threshold 2500 ms (Good boundary)"
```

### Step 9: User Flow Testing (Flow Engine)

If specific user flows were provided, execute them step by step using the full flow engine.

**F0 — Precondition**: read preflight cache. If `runtime_available` is not `true`, skip. (This mirrors Step 1; Step 9 never runs without a confirmed runtime backend.)

**F1 — Oracle Sourcing** (once per flow, before any browser action):
- L1: glob `openspec/changes/*/specs/**/*.md`, parse Given/When/Then scenarios.
- L2: if `qa-init` recorded a test command, EXECUTE it and read the output. "Tests exist" is not L2.
- L3: scan for schema files (L3-schema), then validation regexes and error-message literals (L3-inferred).
- L4: always available — named WCAG SC, RFC section, CWV metric name + threshold, or Nielsen heuristic number.

**F2 — Session + Run Setup**:
```bash
# Reuse session if already established in Step 1; derive a new one only if not set.
# Reason: reusing the session preserves auth cookies set in Step 1. A fresh derivation
# here would produce a clean session with no auth state, causing auth walls to be
# misreported as application defects rather than harness problems.
S="${S:-$(agent-browser session id --scope worktree --prefix qase)}"
QASE_RUN_ID="$(date +%s)-$(openssl rand -hex 3)"

# Derive the flow slug and evidence directory using the canonical algorithm from
# openspec-convention.md §Slug Derivation Algorithms → {flow-slug}:
#   1. Lowercase the flow name.
#   2. Replace every non-[a-z0-9] char with a hyphen.
#   3. Collapse consecutive hyphens to one; strip leading/trailing hyphens.
# EVID: the per-flow binary artifact directory, rooted at the review's flow-evidence subtree.
FLOW_SLUG="$(echo "<flow-name>" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//;s/-$//')"
EVID="qaspec/reviews/${REVIEW_ID}/flow-evidence/${FLOW_SLUG}"
# <flow-name> must be substituted with the actual flow name at runtime.
# ${REVIEW_ID} is the review ID passed by the orchestrator (e.g., "2024-01-15-auth-refactor").
```
Write flow evidence header and Test Data Ledger skeleton (see `skills/_shared/qase/issue-format.md` — Flow Evidence Format).

**F3 — Flow Open**:
```bash
agent-browser --session "$S" open <url>
agent-browser --session "$S" wait --load networkidle
# deep / on request only:
agent-browser --session "$S" network har start
agent-browser --session "$S" record start "${EVID}/recordings/${FLOW_SLUG}.webm"
```

**Per-step loop** — repeat for each step N:

**S1 Clear buffers** (mandatory before each step N ≥ 2; acceptable but not required for step 1):
```bash
agent-browser --session "$S" console --clear
agent-browser --session "$S" errors --clear
agent-browser --session "$S" network requests --clear
```
Each step owns its own console, error, and network record. Clearing is what makes per-step attribution honest.

**S2 Optional fault injection** (only when the step declares one):
```bash
# abort a route:
agent-browser --session "$S" network route "{url-pattern}" --abort
# mock a response:
agent-browser --session "$S" network route "{url-pattern}" --body '{"error":"boom"}'
```

**S3 Act** — ONE of the following per step:
```bash
agent-browser --session "$S" find role button click --name "Sign In"
agent-browser --session "$S" click "<sel>"
agent-browser --session "$S" click @e7
agent-browser --session "$S" fill "<sel>" "qase+$QASE_RUN_ID@example.com"
agent-browser --session "$S" press "Enter"
agent-browser --session "$S" type "<sel>" "<text>"
agent-browser --session "$S" check "<sel>"
agent-browser --session "$S" select "<sel>" "<value>"
agent-browser --session "$S" scroll down
```

Unique identity template for write flows:
- email: `qase+{QASE_RUN_ID}@example.com`
- display name: `QASE Test {QASE_RUN_ID}`
- password: `Qase-{QASE_RUN_ID}!`
- org/team: `qase-{QASE_RUN_ID}`

**S4 Settle** — pick the narrowest that applies:
```bash
agent-browser --session "$S" wait --url "**/dashboard"
agent-browser --session "$S" wait --text "Welcome back"
agent-browser --session "$S" wait "<selector>"
agent-browser --session "$S" wait --load networkidle
agent-browser --session "$S" wait --fn "!document.body.innerText.includes('Loading...')"
```

**S5 Observe**:
```bash
agent-browser --session "$S" get url
agent-browser --session "$S" get title
agent-browser --session "$S" get text "<sel>"
agent-browser --session "$S" is visible "<sel>"
agent-browser --session "$S" snapshot -i
```

**S6 Harvest per-step diagnostics**:
```bash
agent-browser --session "$S" console --json          # → console/step-NN.json
agent-browser --session "$S" errors --json           # → errors/step-NN.json
agent-browser --session "$S" network requests --json # → network/step-NN.json
# for each request with status >= 400 (standard + deep):
agent-browser --session "$S" network request <requestId>
```

**S7 Capture artifact** (every step, always — proposal success criterion 13):
```bash
# ${EVID} is defined in F2: "qaspec/reviews/${REVIEW_ID}/flow-evidence/${FLOW_SLUG}"
agent-browser --session "$S" screenshot "${EVID}/screenshots/step-NN.png"
# deep: agent-browser --session "$S" screenshot --full "${EVID}/screenshots/step-NN.png"
# when finding points at element: agent-browser --session "$S" screenshot --annotate "${EVID}/screenshots/step-NN.png"
```

**S8 Resolve expectation**: run the Oracle Resolution Algorithm from `oracle-contract.md` (L1→L2→L3-schema→L3-inferred→L4). Validate the tier claim; downgrade if citation fails.

**S9 Classify**: `PASS | FAIL — BLOCKER | FAIL — WARNING | INCONCLUSIVE | SKIPPED`. Severity capped by the Oracle Tier blocking matrix. Bare `FAIL` is invalid.

**S10 Teardown of step scope** (runs even on FAIL or INCONCLUSIVE):
```bash
# if a route was installed in S2:
agent-browser --session "$S" network unroute "{url-pattern}"
```
If `network unroute` exits non-zero → **abort the flow immediately**. Later steps would run against a contaminated network layer; their evidence would be unreliable. This is the one condition where the degradation principle does NOT apply.

**S11 Emit evidence row**: write the completed row to the flow evidence document with all six required fields: Action | Observed | Expected | Oracle Tier | Status | Artifact.

**Daemon reconnection branch** (any of S1–S7 exits non-zero with connection/daemon error):
```bash
agent-browser --session "$S" session info --json
# if daemon dead: relaunch and re-establish auth state:
agent-browser --session "$S" open <url>
# retry the current step ONCE
```
- Retry succeeds → continue, annotate the evidence row "backend reconnected mid-step".
- Retry fails → step = INCONCLUSIVE, abort flow as PARTIAL, flow-level WARNING "runtime backend lost".
- **INVARIANT**: daemon loss is NEVER reported as an application defect and NEVER produces FAIL.

**F4 — Flow Teardown** (after all steps):
```bash
agent-browser --session "$S" network unroute     # belt-and-suspenders — removes all routes
agent-browser --session "$S" record stop         # if recording was started
agent-browser --session "$S" network har stop "${EVID}/har/${FLOW_SLUG}.har"   # if HAR was started
# invoke detected_cleanup_hook if qa-init recorded one — otherwise do nothing
# do NOT close until after the last flow; later flows reuse the session
```
After the last flow:
```bash
agent-browser --session "$S" close
```
**NEVER** use `agent-browser close --all` — it closes all active sessions including other agents' concurrent runs.

**F5 — Flow Summary + Test Data Ledger + Persist**:
- Produce the Flow Summary table per `issue-format.md` — Flow Evidence Format.
- Produce the Test Data Ledger: every identity and record created; if read-only flow, record `—` (not omit). Note whether a cleanup hook was invoked and its result.
- Return flow evidence in your result envelope. The orchestrator persists it: openspec → `qaspec/reviews/{review-id}/flow-evidence/{flow-slug}.md`; engram → `qase/{review-id}/flow-evidence/{flow-slug}`.

**Write-flow and safety rules**:
- Production write flows are refused and reported as SKIPPED with a reason — never silently omitted.
- Write flows are opt-in per flow — never discover and exercise a form autonomously.
- Unique identities are mandatory for any write-flow field (QASE_RUN_ID template above).
- Named sessions (`--session "$S"`) isolate cookies and client storage — they do NOT isolate server-side database state. The Test Data Ledger is the record of what was created.
- **Never** `agent-browser close --all`.

**If NO user flows provided**: skip this step and note in report.

### Step 10: Apply Dismissed Patterns + Produce Report + Persist

```
FOR EACH finding:
├── Check against dismissed patterns from feedback
├── PROJECT_RULE or FALSE_POSITIVE → skip
├── ONE_TIME → report but mark as previously dismissed
└── No match → include
```

#### Report Format

```markdown
## Browser Inspector Report

**Review ID**: {review-id}
**URL tested**: {url}
**Pages visited**: {count}
**Runtime available**: {true | false | skipped}
**Philosophy**: "If a user can break it, they will"

### Findings

#### BLOCKERs
{findings — L1/L2/L3-schema tier only; L4 findings cannot appear here}

#### WARNINGs
{findings}

#### INFOs
{findings — only if deep mode}

### Runtime Health Summary

| Category | Status | Findings |
|----------|--------|----------|
| Console Errors | {CLEAN/HAS_ERRORS} | {count} |
| Network Health | {HEALTHY/DEGRADED/BROKEN} | {count} |
| Accessibility | {COMPLIANT/VIOLATIONS} | {count} |
| Interactive Elements | {WORKING/ISSUES/BROKEN} | {count} |
| Navigation | {INTACT/GAPS/BROKEN} | {count} |
| Responsive Layout | {SOLID/ISSUES/BROKEN} | {count} |
| Performance (CWV) | {GOOD/NEEDS_WORK/POOR} | {count} |
| User Flows | {PASSING/PARTIAL/FAILING/SKIPPED} | {count} |

### Core Web Vitals

| Metric | Value | Rating | Oracle Tier |
|--------|-------|--------|-------------|
| LCP | {data.lcp.startTime}ms | {Good/Needs Improvement/Poor} | L4 |
| CLS | {data.cls.score} | {Good/Needs Improvement/Poor} | L4 |
| FCP | {data.fcp}ms | {Good/Needs Improvement/Poor} | L4 |
| INP | {data.inp}ms | {Good/Needs Improvement/Poor or N/A} | L4 |

Note: `vitals --json` returns `lcp` as an object (`{element, size, startTime, url}`) — render
`data.lcp.startTime`. Similarly `cls` is `{entries[], score}` — render `data.cls.score`.
Scalar fields (`fcp`, `ttfb`, `inp`) are returned directly as numbers (ms) or null.

---
## Metadata
- **agent**: qa-browser
- **review-id**: {review-id}
- **url-tested**: {url}
- **pages-visited**: {count}
- **findings-count**: {total}
- **blockers**: {count}
- **warnings**: {count}
- **infos**: {count}
- **verdict-contribution**: CLEAN | HAS_WARNINGS | HAS_BLOCKERS
- **oracle_tier_breakdown**: { L1: {n}, L2: {n}, L3-schema: {n}, L3-inferred: {n}, L4: {n} }
- **flow-evidence**: {path | topic_key | none}
- **runtime-available**: true | false
- **changed_surface_exercised**: yes | no | partial
- **changed_surface_note**: {reason when not "yes" — required in that case; null when yes}
---
```

#### Return Report

Return the report payload in your result envelope. The orchestrator persists it:
- **engram**: orchestrator calls `mem_save(topic_key: "qase/{review-id}/browser-report", content: {returned-report})`
- **openspec**: orchestrator writes to `qaspec/reviews/{review-id}/browser.md`
- **none**: report is returned inline

Tier ceilings and the blocking matrix are owned by `skills/_shared/qase/oracle-contract.md`.

**Declare `changed_surface_exercised`** — MANDATORY. After completing all steps, determine whether
the changed code surface was actually reached and exercised during this session. Set the field to:
- `yes` — you can demonstrate (screenshot, network request, console output) that the changed
  surface was loaded and executed in this session.
- `no` — the changed surface was not reached. The most common cause: the feature sits behind
  authentication or a user flow that was not executed. Be honest; `no` is not a failure — it is
  information that prevents qa-report from overstating coverage.
- `partial` — some changed components were reached but others were not (e.g., the page loaded
  but a modal that contains the changed code was never opened).

Do NOT attempt automatic source-file-to-URL mapping. You declare based on what you observed.
When `changed_surface_exercised` is not `yes`, `changed_surface_note` MUST explain why (e.g.
"Report scheduling modal requires authentication — /login tested only").

Return structured envelope with: `status`, `executive_summary`, `report_markdown`, `artifacts`,
`verdict_contribution`, `changed_surface_exercised`, `changed_surface_note`, `risks`.

## Depth Controls

| Level | Artifact Scope |
|-------|---------------|
| **concise** | Steps 1–4 only. Per-step screenshot (required). Per-step console/errors JSON. Network summary counts only. No HAR. No recording. |
| **standard** | All steps. Per-step screenshot. Full network JSON. Per-step network JSON. `--annotate` only when a finding points at an element. Max 10 interactive elements, 1 level of link following, max 20 pages. |
| **deep** | All steps. `--full` screenshots. `network request <id>` detail for status ≥ 400. HAR. WebM recording. All interactive elements, 2 levels of link following. Include INFO findings. |

Per-step screenshot is never optional: proposal success criterion 13 requires at least one artifact path per step.

## Safety Rules

- **NEVER** click buttons that appear destructive (Delete, Remove, Cancel, Unsubscribe, etc.) unless they are part of an explicit user flow
- **NEVER** submit payment forms or interact with payment elements
- **NEVER** follow links to external domains — only test same-origin navigation
- **NEVER** enter real credentials — use only test data with the QASE_RUN_ID template
- **NEVER** use `agent-browser close --all` — it closes other agents' sessions
- If authentication is required but no credentials were provided → report as a NOTE, test only public/unauthenticated pages
- If the target URL is identified as a production environment → write flows are refused and reported as SKIPPED
- Limit total page navigations to avoid overwhelming the application
- Unique identities are mandatory for any write-flow field; repeating the same identity across runs is a failure of this contract

## Rules

- ALWAYS read the preflight cache (Step 1) before any browser command; SKIP and return clean if unavailable
- ALWAYS start by establishing connection and checking basic health (Steps 1–3) before deeper analysis
- ALWAYS capture evidence (console messages, network details, snapshots, screenshots) for every finding
- ALWAYS assign an Oracle Tier to every finding, resolved per `oracle-contract.md`
- ALWAYS include an Oracle Absence note when the result is below L3-schema
- Do NOT report daemon/session loss as an application defect — it is INCONCLUSIVE
- Do NOT report issues caused by the testing environment itself (e.g., extension errors)
- Always use `wait --load networkidle` for load-state waits; the bare form without `--load` is rejected by agent-browser
- Global flags (`--session`, `--restore`) precede the subcommand: `agent-browser --session "$S" open <url>`
- Be practical — focus on issues that real users would encounter
- Skip findings that match dismissed patterns
- When `eval --stdin` injection fails (CSP restrictions), note the degradation and rely on snapshot-based analysis
- Return a structured envelope with: `status`, `executive_summary`, `artifacts`, `verdict_contribution`, and `risks`
