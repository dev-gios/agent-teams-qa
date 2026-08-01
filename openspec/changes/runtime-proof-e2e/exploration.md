# Exploration: runtime-proof-e2e

## What Was Explored

Migration of `qa-browser` and `qa-visual` from Chrome DevTools MCP to the `agent-browser` CLI backend, plus the addition of end-to-end user-flow evidence capabilities and a 4-tier oracle verification model for QASE.

---

## Problem Statement

QASE produces confident static opinions that pass review while the delivered feature does not actually work. Ten of twelve skills read source and never execute anything. The two that do execute (`qa-browser`, `qa-visual`) are optional dependencies and have no veto power, while the two skills that *can* block delivery (`qa-security`, `qa-architect`) never execute anything.

The goal of this change is to make QASE produce **executed evidence** of user paths — a step-by-step report of what was actually done and observed — and to let that evidence carry weight in the verdict.

---

## Current State

### How QASE Works Today

QASE is a multi-specialist QA framework for Claude Code agents. The two runtime specialists (`qa-browser` and `qa-visual`) connect to a live application for dynamic testing. The other ten specialists are static — they read source files via Read/Grep only and produce findings without executing code.

**Backend today**: Both `qa-browser` and `qa-visual` reference Chrome DevTools MCP tools by name:
`navigate_page`, `take_screenshot`, `take_snapshot`, `evaluate_script`, `wait_for`, `resize_page`, `list_console_messages`, `list_network_requests`, `emulate`.

**Verified facts**:

- `veto_power: true` appears ONLY in `skills/qa-security/SKILL.md:13` and `skills/qa-architect/SKILL.md:12`. Every other skill is `veto_power: false`, including both runtime skills.
- `skills/_shared/qase/` contains exactly six files: `engram-convention.md`, `issue-format.md`, `openspec-convention.md`, `persistence-contract.md`, `routing-rules.md`, `severity-contract.md`.
- Environment: `agent-browser@0.32.2` installed; `chromium` and `google-chrome-stable` present; plain `google-chrome` ABSENT.

### Current Skill Files Affected

| File | Current State |
|------|---------------|
| `skills/qa-browser/SKILL.md` | Multi-step pipeline; references Chrome DevTools MCP tools by name; no flow evidence, no network interception, no session management |
| `skills/qa-visual/SKILL.md` | Same MCP tool references; no baseline diffing, no vitals command |
| `skills/qa-init/SKILL.md` | Detects stack, architecture, quality tooling; NO runtime preflight — no agent-browser detection, no Chrome binary probing, no smoke connection test |
| `skills/_shared/qase/severity-contract.md` | Defines BLOCKER/WARNING/INFO and the veto table; NO oracle tier concept |
| `skills/_shared/qase/issue-format.md` | Browser Testing and Visual Testing finding variants; neither has an oracle tier field |
| `skills/_shared/qase/persistence-contract.md` | Mode resolution rules; NO runtime preflight cache schema |
| `skills/_shared/qase/engram-convention.md` | Artifact type table; no `flow-evidence`, no `preflight-cache` |
| `skills/_shared/qase/openspec-convention.md` | File path table; no flow evidence or preflight paths |
| `skills/_shared/qase/routing-rules.md` | Out-of-band table for qa-browser and qa-visual; no oracle tier routing |

### What QASE Cannot Do Today

1. Verify a complete multi-step user flow (login → navigate → submit → confirm outcome)
2. Intercept and force network failures to test error handling paths
3. Test authenticated pages (no session or credential management)
4. Capture video evidence of a user flow
5. Perform visual regression against a stored baseline
6. Measure Core Web Vitals via a dedicated command (uses manual JS injection today)
7. Declare which oracle tier a finding's expectation came from
8. Know whether a browser backend is installed before attempting browser commands

---

## Verified Ground Truth: agent-browser v0.32.2 Capability Inventory

Source: verified via `agent-browser --help`. This is the authoritative command inventory.

**Important**: the agent-browser MCP `core` tools profile is a curated SUBSET of these capabilities. QASE skills MUST drive agent-browser through the **CLI via Bash**, not through the MCP core tools. An earlier audit that looked only at the MCP profile falsely concluded there were five unresolvable capability gaps.

```
Core:        open, read, click, dblclick, type, fill, press, keyboard type|inserttext, hover, focus,
             check, uncheck, select, drag, upload, download, scroll, scrollintoview, wait,
             screenshot [--full|--annotate], pdf, snapshot [-i], eval, connect <port|url>, close
Navigation:  back, forward, reload
Get Info:    get text|html|value|attr|title|url|count|box|styles|cdp-url
Check State: is visible|enabled|checked
Find:        find role|text|label|placeholder|alt|title|testid|first|last|nth <value> <action>
Mouse:       mouse move|down|up|wheel
Settings:    set viewport <w> <h> | device <name> | geo | offline | headers <json>
             | credentials <user> <pass> | media [dark|light] [reduced-motion]
Network:     network route <url> [--abort|--body <json>] [--resource-type <csv>]
             network unroute | network requests [--clear] [--filter <pattern>]
             network har start|stop [path]
Storage:     cookies [get|set|clear], storage <local|session>
Tabs:        tab [new|list|close|<n>]
Diff:        diff snapshot | diff screenshot --baseline | diff url <u1> <u2>
Debug:       trace start|stop, profiler start|stop, record start|stop (WebM video),
             console [--clear], errors [--clear], highlight, inspect, clipboard
Performance: vitals [url] [--json]  -> Core Web Vitals LCP/CLS/TTFB/FCP/INP + React hydration summary
React:       react tree|inspect|renders start|stop|suspense  (requires `open --enable react-devtools`)
SPA:         pushstate <url>
Session:     --session <name>, --restore, --profile <name>, --cdp <port>, --auto-connect,
             --color-scheme dark, --allowed-domains, --init-script, -p ios
Chaining:    commands chain with && in one shell call; browser persists via a daemon
Skills:      agent-browser skills get core --full
```

**`wait` subcommand — verified exact syntax** (a prior draft of this document had this wrong):

```
agent-browser wait <selector|ms|option>
  <selector>           Wait for element to appear
  <ms>                 Wait for specified milliseconds
  --url <pattern>      Wait for URL to match pattern
  --load <state>       Wait for load state (load, domcontentloaded, networkidle)
  --fn <expression>    Wait for JavaScript expression to be truthy
  --text <text>        Wait for text to appear on page (substring match)
  --download [path]    Wait for a download to complete
```

`wait networkidle` is INVALID. The correct form is `wait --load networkidle`.

**Official usage guide**: `agent-browser skills get core --full` (2649 lines) ships version-matched with the CLI. Its files live at:
`/home/devgio/.local/share/mise/installs/node/25.9.0/lib/node_modules/agent-browser/skill-data/core`

Spec and implementation authors MUST consult it before writing command examples.

**Invocation pattern**: commands chain with `&&` in a single shell call; the browser daemon persists between calls.

```bash
agent-browser open https://example.com && agent-browser screenshot && agent-browser network requests
```

---

## Affected Areas

| File/Path | Why Affected |
|-----------|-------------|
| `skills/qa-browser/SKILL.md` | Primary migration target: replace all Chrome DevTools MCP tool references with agent-browser CLI commands; add flow evidence; add network interception; add session management; add console/errors capture |
| `skills/qa-visual/SKILL.md` | Secondary migration target: replace MCP tool references with CLI equivalents; add `diff screenshot --baseline`; add `vitals --json` |
| `skills/qa-init/SKILL.md` | Add runtime preflight step — detect agent-browser, probe Chrome binary names, run smoke connection, cache result |
| `skills/_shared/qase/severity-contract.md` | Thread oracle tier into severity and verdict rules |
| `skills/_shared/qase/issue-format.md` | Add `Oracle Tier` field to Browser and Visual Testing variants |
| `skills/_shared/qase/persistence-contract.md` | Add runtime preflight cache schema |
| `skills/_shared/qase/engram-convention.md` | Add `flow-evidence` and `preflight-cache` artifact types |
| `skills/_shared/qase/openspec-convention.md` | Add `flow-evidence.md` and `preflight-cache.yaml` paths |
| NEW `skills/_shared/qase/oracle-contract.md` | Define the 4-tier oracle model and blocking rules |

---

## Investigation 1: qa-init Runtime Preflight

### Extension Point

The preflight belongs as a new final step in `qa-init` — after the existing project-context detection steps and before the return summary. Name it **Runtime Preflight (Browser Backend)**.

### Preflight Logic

```
DETECT:
├── Check agent-browser availability
│   ├── Try: agent-browser --version  (exit 0 = found)
│   ├── If found: record version string
│   └── If not found: record unavailable; offer install instructions
│         npm install -g agent-browser | brew install agent-browser | cargo install agent-browser
│
├── Probe Chrome binary names (in order, stop at first found)
│   ├── chromium
│   ├── google-chrome-stable
│   ├── google-chrome          (VERIFIED ABSENT on the reference machine — never assume)
│   ├── chrome
│   └── Fallback: agent-browser install   (downloads Chrome on first use)
│
├── Smoke connection test (only if agent-browser AND a Chrome binary were found)
│   ├── agent-browser open about:blank && agent-browser close
│   ├── SUCCESS -> runtime_available: true
│   └── FAILURE -> runtime_available: false, error: {message}
│
└── Persist preflight result to the active artifact store
```

The preflight must prove **connectivity**, not presence. An installed-but-broken browser is the failure mode that silently turns runtime QA back into static opinion.

### Preflight Cache Schema

**openspec mode** — `qaspec/preflight-cache.yaml`;
**engram mode** — topic_key `qa-init/{project}/preflight`.

```yaml
preflight:
  agent_browser:
    available: true | false
    version: "0.32.2" | null
  chrome_binary:
    available: true | false
    name: "chromium" | "google-chrome-stable" | null
  runtime_available: true | false
  smoke_test: passed | failed | skipped
  error: null | "error message"
  probed_at: "ISO-8601 timestamp"
```

### App Start Command — SUGGEST, NEVER AUTO-RUN

`qa-init` detects the app's likely start command and reports it as a suggestion. It MUST NOT execute it — starting a user's application is a side effect outside the agent's mandate.

Detection sources:

- `package.json` -> `scripts.dev`, `scripts.start`, `scripts.serve`
- `Makefile` -> `run`, `serve`, `dev` targets
- `Procfile` -> `web:` entry
- `docker-compose.yml` -> `services.*.ports`, `services.*.command`
- `README.md` -> "Getting Started" section
- `go.mod` / `main.go` -> `flag.Int("port", ...)` patterns
- `.env.example` -> `PORT=` entry

```yaml
detected_start_hints:
  - command: "npm run dev"
    source: "package.json scripts.dev"
    likely_port: 3000
```

Once the user confirms the app is running, connectivity is verified with
`agent-browser open http://localhost:{detected-port}`.

---

## Investigation 2: Migration Map — Chrome DevTools MCP to agent-browser CLI

| MCP Tool Call | agent-browser CLI Replacement | Notes |
|---------------|-------------------------------|-------|
| `navigate_page(url)` | `agent-browser open <url>` | Primary navigation |
| `wait_for("load")` | `agent-browser wait --load networkidle` | States: `load`, `domcontentloaded`, `networkidle` |
| `take_screenshot()` | `agent-browser screenshot` | `--full` for full page, `--annotate` for labeled elements |
| `take_snapshot()` | `agent-browser snapshot` | `-i` for interactive elements only; returns stable `@ref` handles |
| `evaluate_script(code)` | `agent-browser eval "<code>"` | |
| `list_console_messages()` | `agent-browser console` | `--clear` to reset the buffer between steps |
| `get_console_message(id)` | `agent-browser console` | Filter output client-side |
| `list_network_requests()` | `agent-browser network requests` | |
| `get_network_request(id)` | `agent-browser network requests --filter <pattern>` | |
| `resize_page(w, h)` | `agent-browser set viewport <w> <h>` | Also `set device <name>` |
| `emulate({reducedMotion})` | `agent-browser set media reduced-motion` | `set media` with no args resets |
| `performance_start_trace()` | `agent-browser trace start` | Also `profiler start` |
| `performance_stop_trace()` | `agent-browser trace stop [path]` | |
| `performance_analyze_insight()` | `agent-browser vitals --json` | One command replaces the whole trace-analysis path |
| `click(selector)` | `agent-browser click "<sel>"` or `find role button click --name X` | |
| `fill(selector, value)` | `agent-browser fill "<sel>" "<value>"` | |
| `press_key(key)` | `agent-browser press "<key>"` | |
| `navigate_back()` | `agent-browser back` | |

**No genuine capability gaps.** Every current Chrome DevTools MCP capability maps cleanly to a CLI command, and the CLI additionally provides capabilities the MCP backend never had.

---

## Investigation 3: Capability Upside

New verification abilities unlocked, ranked by value for the first slice.

### Tier 1 — Essential

1. **`network requests [--clear] [--filter <pattern>]`** — verify which API calls a flow actually made, detect unexpected requests, confirm payloads. `--clear` between steps gives per-step attribution.
2. **`console [--clear]` and `errors [--clear]`** — `errors` is new: runtime JS errors captured specifically. Clear before each step, read after, and every step gets its own error record.
3. **`--session <name>` and `--restore`** — persist cookies and localStorage under a named session; authenticate once, replay authenticated state on every later run.
4. **`cookies [get|set|clear]` and `set credentials <user> <pass>`** — inject auth tokens and session cookies; `set credentials` handles HTTP Basic Auth dialogs.
5. **`record start/stop`** — WebM video of the complete flow. Direct answer to "prove the flow ran".

### Tier 2 — High Value

6. **`network route <url> [--abort|--body <json>]`** — force API failures and inject mock responses. This makes `qa-advocate`'s "What if X fails?" hypotheses **executable** instead of statically reasoned. Example: `network route /api/payment --abort` then verify the user actually sees an error state.
7. **`vitals [url] --json`** — LCP, CLS, TTFB, FCP, INP plus React hydration summary in one command; replaces multi-step JS injection.
8. **`diff screenshot --baseline`** — true visual regression against a stored baseline; replaces "screenshots as documentation".

### Tier 3 — Reproducibility

9. **`storage <local|session>`** — inject test fixtures, clean up after write flows.
10. **`network har start|stop [path]`** — full HAR capture for post-hoc analysis.
11. **`react tree|inspect|renders|suspense`** — React component tree, render counts, Suspense boundary classification (requires `open --enable react-devtools`).

---

## Investigation 4: Oracle Contract and Shared-Contract Threading

### The 4-Tier Oracle Model

Every runtime finding MUST declare which oracle its expectation came from. Verdict strength follows oracle strength. This is what allows QASE to work on **any project, in any language, with or without SDD**.

| Tier | Name | Source | Available When | Can BLOCK |
|------|------|--------|----------------|-----------|
| L1 | SDD spec scenarios | `openspec/changes/*/specs/**/*.md` | An SDD change exists | YES |
| L2 | Repo test suite, executed | Project test runner output | The project has tests | YES |
| L3 | Code contract | What the source PROMISES: validation rules, error messages, redirect targets, schemas | **Always** | YES |
| L4 | Universal heuristics | WCAG, Nielsen, HTTP semantics, timeout thresholds | Always | Advisory only |

L3 is the tier that makes the system universal. If the code promises a validation and the running app does not enforce it, that is an objective defect — no spec and no tests required.

### Where the Oracle Field Must Be Threaded

- **NEW `skills/_shared/qase/oracle-contract.md`** — defines the tier model, how each tier is populated, and the blocking rules.
- **`issue-format.md`** — add `**Oracle Tier**: L1 | L2 | L3-schema | L3-inferred | L4` to the Browser Testing and Visual Testing variants; add `oracle_tier_breakdown` to the metadata envelope.
- **`severity-contract.md`** — add an "Oracle Tier and Verdict" section. Core rules: L4 findings NEVER produce BLOCKER; `L3-inferred` (pattern-derived) caps at WARNING; `L1`, `L2`, and `L3-schema` may produce BLOCKER.
- **`engram-convention.md`** — add `flow-evidence` and `preflight-cache` artifact types.
- **`openspec-convention.md`** — add `flow-evidence.md` and `preflight-cache.yaml` paths.
- **`persistence-contract.md`** — add the preflight cache schema.

### Veto Power — OPEN DECISION FOR DESIGN

Veto power is currently granted in two places that must stay in sync: the skill's YAML frontmatter (`veto_power: true|false`) and the veto table in `severity-contract.md`.

Today the runtime skills have `veto_power: false`, meaning executed evidence cannot block delivery while unexecuted static opinion can. That inversion is the core problem this change exists to fix.

Two candidate resolutions — **the design phase must choose explicitly**:

- **(a) Grant `veto_power: true`** to the runtime skill, gated on the finding's oracle tier being L1/L2/L3-schema.
- **(b) Leave the veto flags untouched** and escalate through severity rules in `severity-contract.md`, so an L1/L2 failure produces a BLOCKER that drives the verdict without a new veto holder.

This is the single most consequential open decision in the change.

---

## Investigation 5: Flow Evidence Format

The step-by-step evidence report is the primary deliverable of this change. Each flow step produces one evidence entry.

```markdown
## Flow Evidence: {flow-name}

**Started at**: {ISO-8601}
**App URL**: {url}
**Session**: {session-name | anonymous}
**Oracle sources consulted**: L1 {spec path} | L2 {test command} | L3 {schema path} | L4 heuristics

### Step 1: Submit the sign-in form

| Field | Value |
|-------|-------|
| **Action** | `agent-browser find role button click --name "Sign In"` |
| **Observed** | Redirected to /dashboard; HTTP 200 |
| **Expected** | Navigate to authenticated dashboard |
| **Oracle Tier** | L1 — spec scenario "Login with valid credentials" |
| **Status** | PASS |
| **Artifact** | `screenshots/flow-login-step-01.png` |

### Step 2: Reject an invalid email

| Field | Value |
|-------|-------|
| **Action** | `agent-browser fill "#email" "not-an-email" && agent-browser click "@submit"` |
| **Observed** | Form submitted; no validation message rendered |
| **Expected** | Inline error "Invalid email address" |
| **Oracle Tier** | L3-schema — the Zod schema in `src/schemas/auth.ts` declares `z.string().email()` with that exact message |
| **Status** | FAIL — BLOCKER |
| **Artifact** | `screenshots/flow-login-step-02.png`, `console/step-02.txt` |

### Step 3: Degrade gracefully when the API is down

| Field | Value |
|-------|-------|
| **Action** | `agent-browser network route "**/api/login" --abort && agent-browser click "@submit"` |
| **Observed** | Blank screen; no user-facing error |
| **Expected** | User-visible error state on network failure |
| **Oracle Tier** | L4 — universal heuristic (no spec or code contract covers this path) |
| **Status** | FAIL — WARNING (advisory: L4 cannot block) |
| **Artifact** | `screenshots/flow-login-step-03.png` |

### Flow Summary

| Metric | Value |
|--------|-------|
| Steps executed | 3 |
| Passed / Failed | 1 / 2 |
| BLOCKERs / WARNINGs | 1 / 1 |
| Video evidence | `recordings/flow-login.webm` |
| Network log | `har/flow-login.har` |
```

### Evidence Artifact Storage

- **engram mode**: topic_key `qase/{review-id}/flow-evidence/{flow-slug}`
- **openspec mode**: `qaspec/reviews/{review-id}/flow-evidence/{flow-slug}.md`
- Screenshots, recordings, and HAR files referenced by relative path alongside the review.

---

## Investigation 6: Blockers on an Arbitrary Project

### Dirty State and Test Data for Write Flows

A signup flow creates a real user. On the second run the email already exists and the report emits a false positive. Three strategies:

- **A — Unique generated identities**: `test+{epoch}@example.com`. Each run uses a fresh identity, no collision, no cleanup required. Downside: test data accumulates.
- **B — `--session` isolation**: isolates client-side state (cookies, localStorage) per run. Does NOT isolate server-side database state.
- **C — Explicit teardown hook**: only when the target project exposes a cleanup endpoint; `qa-init` records it if detected.

**Recommended for the first slice**: Strategy A as the default, with Strategy B for session isolation and Strategy C recorded as an optional hint. Accumulated test data is documented as a known limitation.

### Reproducibility

```bash
# First run — authenticate once and persist the session
agent-browser open --session qa-auth https://app.example.com && \
  agent-browser fill "#email" "qa@example.com" && \
  agent-browser fill "#password" "qa-password" && \
  agent-browser click "@submit" && \
  agent-browser wait --load networkidle

# Later runs — restore authenticated state directly
agent-browser open --session qa-auth --restore https://app.example.com/dashboard
```

Combined with `diff screenshot --baseline` and unique test identities, a run becomes repeatable and its deltas attributable.

---

## Investigation 7: L3 Code-Contract Oracle

How a skill extracts "what the code promises" from arbitrary source in an arbitrary language.

| Approach | Description | Pros | Cons | Effort |
|----------|-------------|------|------|--------|
| **A — Schema-first extraction** | Read only structured, machine-readable sources: OpenAPI/Swagger, JSON Schema, Zod/Pydantic/class-validator schemas, Prisma, GraphQL SDL | Unambiguous; very low false-positive rate; simple to implement | Silent when no schema files exist; misses validation co-located in handlers; no UI-level promises | Low-Medium |
| **B — Static pattern extraction** | Read handlers and components; extract validation regexes, error message literals, redirect targets, guard clauses | Works on any codebase; captures UI-level promises; yields concrete assertions | False positives from dead code and feature flags; misses i18n-keyed messages; needs a per-framework pattern library | Medium |
| **C — Live endpoint probing** | Probe the running app and record actual response shapes as the baseline | Ground truth; always current | Requires the app running; POST probes have side effects; blocked by auth | Medium-High |

**Recommendation**: **A as primary, B as fallback**, with findings annotated `L3-schema` (from A) versus `L3-inferred` (from B) to encode confidence. `L3-inferred` caps at WARNING severity to prevent false-positive BLOCKERs from degrading signal. C is deferred to a later slice — it overlaps the deferred API/endpoint testing scope.

**Graceful degradation**: when no L3 source exists, the finding falls back to L4 and states explicitly that no code contract was consulted.

---

## Investigation 8: Skill Topology

| Option | Description | Pros | Cons | Effort |
|--------|-------------|------|------|--------|
| **A — Extend qa-browser in place** | Add flow evidence, network interception, session management, and oracle tiers to the existing skill | One skill to maintain; existing orchestrator routing unchanged; unified finding format; qa-browser already has a User Flow Testing step as the natural home | SKILL.md grows large; mixes passive inspection with active flow execution in one file | Medium |
| **B — New `qa-flow` skill** | Dedicated user-flow specialist; qa-browser keeps runtime health only | Clean separation; each skill independently useful; passive/active split explicit | Two skills to maintain; new routing rules; new issue-format variant | High |
| **C — Split into passive/active skills** | Rename and split qa-browser | Maximum conceptual clarity | Breaking change to orchestrator commands and engram topic keys | High |

**Recommendation: Option A** for the first slice — it is the minimal change that delivers executed flow evidence, and `qa-flow` can be extracted later if qa-browser grows unwieldy. Note this recommendation is **contested**: an earlier exploration pass favoured Option B on separation-of-concerns grounds. The proposal should settle it, weighing that the runtime skill may also need to acquire veto power (see Investigation 4).

---

## Recommendation

Full CLI migration + oracle tier model + flow evidence in `qa-browser` + `qa-init` runtime preflight.

### First Slice Boundary (this change)

- End-to-end user-flow verification with the step-by-step flow evidence format
- agent-browser CLI migration across `qa-browser` and `qa-visual` (Chrome DevTools MCP removed)
- Oracle tier model L1-L4 with blocking rules, in a new `oracle-contract.md`
- `qa-init` runtime preflight: agent-browser detection, multi-name Chrome probing, smoke connection, cache
- Authenticated flow support (`--session`, `--restore`, `cookies`, `set credentials`)
- Network interception for failure hypothesis testing (`network route --abort`)
- Per-step console and error capture
- Video evidence (`record start/stop`)

### Explicitly Deferred

- API/endpoint contract testing as a standalone capability
- Database/SQL verification
- Live endpoint probing (L3 Approach C)
- `qa-flow` as a separate skill
- React DevTools integration

---

## Risks

1. **Bash is mandatory.** agent-browser is CLI-driven. Any executor without a Bash tool cannot run browser commands. The preflight must verify Bash availability, and skill authoring must account for it. (This exploration itself hit this limit — the `sdd-explore` executor has no Bash and could not run `agent-browser skills get core --full`.)
2. **Chrome binary name variability.** `google-chrome` is ABSENT on the reference machine while `chromium` and `google-chrome-stable` are present. Probing a single name produces a false "not found" on working environments.
3. **Dirty state from write flows.** Unique-identity generation is the minimum viable mitigation; it does not eliminate data accumulation.
4. **L3 oracle quality varies by project.** Projects without schemas, with stale docs, or with i18n-keyed messages weaken L3. Degradation to L4 must be graceful and explicitly declared in the finding.
5. **`L3-inferred` BLOCKER inflation.** If pattern-derived contracts can emit BLOCKERs, false positives will erode trust. The severity contract must cap `L3-inferred` at WARNING.
6. **Command examples must be validated.** All command syntax in specs must be checked against `agent-browser skills get core --full` (2649 lines, at `.../node_modules/agent-browser/skill-data/core`). A prior draft of this document contained `wait networkidle`, which is invalid — the correct form is `wait --load networkidle`.
7. **Daemon lifecycle.** The agent-browser daemon persists between calls but may time out on long sessions; skills must handle reconnection.

---

## Ready for Proposal

Yes. The proposal must resolve:

- Skill topology: extend `qa-browser` versus a new `qa-flow` skill (Investigation 8)
- Veto power: grant it to the runtime skill versus escalate via severity rules (Investigation 4) — the most consequential open decision
- L3 extraction approach and the `L3-schema` / `L3-inferred` severity cap
- Test data and dirty-state policy for write flows
- Rollback plan: all changes are Markdown skill files; revert is a file-level revert with no infrastructure impact
