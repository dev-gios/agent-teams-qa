<p align="center">
  <h1 align="center">QASE — QA-Squad-Excellence</h1>
  <p align="center">
    <strong>Agent-Team Orchestration for Code Quality Review</strong>
    <br />
    <em>A squad of specialized AI sub-agents that review your code in parallel — then produce a consensus verdict.</em>
    <br />
    <em>Zero dependencies. Pure Markdown. Works everywhere.</em>
    <br />
    <em>Optional: <a href="https://github.com/nicholasgriffintn/chrome-devtools-mcp">Chrome DevTools MCP</a> + <a href="https://github.com/gentleman-programming/engram">Engram</a> unlock runtime visual &amp; browser testing.</em>
  </p>
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#how-it-works">How It Works</a> &bull;
  <a href="#commands">Commands</a> &bull;
  <a href="#installation">Installation</a> &bull;
  <a href="#supported-tools">Supported Tools</a>
</p>

---

Built for [Claude Code](https://claude.ai/claude-code). Inspired by the skill/orchestrator patterns from [agent-teams-lite](https://github.com/Gentleman-Programming/agent-teams-lite).

## Philosophy

**SOLID-First. Adaptability over dogmatism.**

QASE doesn't impose architecture — it vets code for quality using the project's own established patterns as the baseline. The Adaptive Architect doesn't demand microservices from a monolith. The Security Shield doesn't flag CSRF when the framework handles it. Every specialist adapts to YOUR stack.

## How It Works

```
/qa-review --staged
       │
  ┌────▼─────┐
  │ qa-scan  │  classifies changes, routes to specialists
  └────┬─────┘
       │
  ┌────▼───────────────────────────────────┐
  │   PARALLEL: activated specialists only  │
  ├────┬──────┬──────┬──────┬──────┬───────┤
  │ARCH│SECUR │ADVOC │INCL  │PERF  │ TEST  │
  └────┴──────┴──┬───┴──────┴──────┴───────┘
                 │
            ┌────▼─────┐
            │qa-report │  APPROVE | APPROVE WITH WARNINGS | REJECT
            └──────────┘
```

**Smart routing**: Not every change needs every specialist. CSS-only changes get Inclusion + Architect. Auth changes get the full squad. qa-scan decides.

## The Squad (7 Static + 2 Runtime Specialists)

| Specialist | Role | Veto Power |
|-----------|------|:----------:|
| **qa-architect** | SOLID guardian, clean architecture | Yes |
| **qa-security** | OWASP Top 10, prompt injection | Yes |
| **qa-advocate** | "What if X fails?", resilience | No |
| **qa-inclusion** | WCAG 2.1 AA, accessibility | No |
| **qa-performance** | N+1 queries, O(n^2), memory leaks | No |
| **qa-test-strategy** | Coverage gaps, test quality | No |
| **qa-report** | Consensus engine, dedup, verdict | — |

**Runtime specialists** (require [Chrome DevTools MCP](https://github.com/nicholasgriffintn/chrome-devtools-mcp)):

| Specialist | Role | Scope |
|-----------|------|-------|
| **qa-browser** | Console errors, network health, interactions, Core Web Vitals | Live URL |
| **qa-visual** | Design system compliance, WCAG contrast, responsive layout, animations | Live URL |

> qa-browser answers "does the app **work**?", qa-visual answers "does the app **look** correct?"

Plus: **qa-init** (stack detection), **qa-scan** (triage/routing), **qa-feedback** (institutional memory).

## Install

```bash
# Clone the repo
git clone https://github.com/dev-gios/agent-teams-qa.git

# Run the installer
cd agent-teams-qa
bash scripts/install.sh
```

The installer detects your OS, asks which tool you use, and copies skills to the correct location. It discovers tools dynamically from `examples/*/qase.json` metadata.

### Supported Systems

QASE works with 7 AI coding tools:

| System | Orchestrator File | Skills Location |
|--------|------------------|----------------|
| **Claude Code** | `~/.claude/CLAUDE.md` | `~/.claude/skills/` |
| **Cursor** | `.cursorrules` | `~/.cursor/skills/` |
| **Gemini CLI** | `~/.gemini/GEMINI.md` | `~/.gemini/skills/` |
| **Codex** | `~/.codex/agents.md` | `~/.codex/skills/` |
| **Antigravity** | `.agent/rules/qase-orchestrator.md` | `~/.gemini/antigravity/skills/` |
| **VS Code Copilot** | `.github/copilot-instructions.md` | `.vscode/skills/` |
| **OpenCode** | `~/.config/opencode/opencode.json` | `~/.config/opencode/skills/` |

After installing skills, add the orchestrator instructions from `examples/{your-tool}/` to your tool's config file.

## Quick Start

```bash
# 1. Initialize QASE in your project
/qa-init

# 2. Make some changes, then review
/qa-review --staged

# 3. Or review last 3 commits
/qa-review HEAD~3

# 4. Or review a PR
/qa-review --pr 42
```

## Commands

| Command | What it does |
|---------|-------------|
| `/qa-init` | Detect stack, architecture DNA, quality tooling |
| `/qa-review [scope]` | Full pipeline: scan → specialists → verdict |
| `/qa-scan [scope]` | Scan only: show routing manifest |
| `/qa-architect [scope]` | Solo: SOLID analysis |
| `/qa-advocate [scope]` | Solo: Resilience analysis |
| `/qa-security [scope]` | Solo: Security analysis |
| `/qa-inclusion [scope]` | Solo: Accessibility analysis |
| `/qa-performance [scope]` | Solo: Performance analysis |
| `/qa-test-strategy [scope]` | Solo: Test strategy analysis |
| `/qa-browser [url]` | Solo: Runtime functional testing (requires Chrome DevTools MCP) |
| `/qa-visual [url]` | Solo: Visual regression & design system audit (requires Chrome DevTools MCP) |
| `/qa-feedback` | Process dismissals, build institutional memory |

### Scope Syntax

| Syntax | Meaning |
|--------|---------|
| `HEAD~3` | Last 3 commits |
| `--staged` | Staged changes (default) |
| `src/auth.ts` | Single file |
| `src/auth/` | Directory |
| `--pr 42` | Pull request |
| `--full` | Force all specialists |
| `--deep` | Include INFO-level findings |

## Severity Levels

| Level | Meaning | Verdict Impact |
|-------|---------|---------------|
| **BLOCKER** | Must fix | REJECT |
| **WARNING** | Should fix | APPROVE WITH WARNINGS |
| **INFO** | Suggestion | None (shown with `--deep`) |

**Veto power**: qa-security and qa-architect BLOCKERs require explicit user acknowledgment to override.

## Feedback Loop

QASE learns from your decisions:

1. Review finds issues → you dismiss some findings
2. `/qa-feedback` asks "Why?" for each dismissal
3. Classifies: `PROJECT_RULE` (permanent), `ONE_TIME` (exception), `FALSE_POSITIVE` (agent bug)
4. Future reviews skip known-accepted patterns
5. Dismissals decay after 180 days (re-evaluated)

### Example Flow

```
You: /qa-review --staged

AI:  Detecting Engram... ✓ available, artifacts will be persisted.
     Launching qa-scan...
     ✓ 12 files changed, 3 categories detected
       Risk level: HIGH (auth + database changes)
       Activating: architect, security, advocate, performance, test-strategy
       Skipping: inclusion (no UI changes)

     Launching 5 specialists in parallel...
     ✓ qa-architect: 1 BLOCKER, 2 WARNINGs
     ✓ qa-security: 0 BLOCKERs, 1 WARNING
     ✓ qa-advocate: 0 BLOCKERs, 3 WARNINGs
     ✓ qa-performance: 1 BLOCKER, 0 WARNINGs
     ✓ qa-test-strategy: 0 BLOCKERs, 2 WARNINGs

     Launching qa-report (consensus engine)...

     ## Review Complete: REJECT

     **Review ID**: 2026-03-03-staged
     **Risk Level**: HIGH
     **Specialists**: 5 active, 1 skipped

     ### Summary
     - BLOCKERs: 2 (veto: 1 from architect)
     - WARNINGs: 8
     - INFOs: 3

     ### Top Findings
     1. BLOCKER: God class in AuthService (SRP violation) — qa-architect
     2. BLOCKER: N+1 query in user listing — qa-performance
     3. WARNING: Missing rate limiting on login endpoint — qa-security

     Fix 2 BLOCKERs and re-run /qa-review
```

---

## The Sub-Agents

Each sub-agent is a `SKILL.md` file — pure Markdown instructions that any AI assistant can follow.

| Sub-Agent | Skill File | What It Does |
|-----------|-----------|-------------|
| **Init** | `qa-init/SKILL.md` | Detects project stack, architecture DNA, quality tooling |
| **Scanner** | `qa-scan/SKILL.md` | Ingests diffs, classifies by category, produces routing manifest |
| **Architect** | `qa-architect/SKILL.md` | SOLID guardian, clean architecture. **Veto power** |
| **Security** | `qa-security/SKILL.md` | OWASP Top 10, prompt injection, auth flaws. **Veto power** |
| **Advocate** | `qa-advocate/SKILL.md` | "What if X fails?", resilience, chaos analysis |
| **Inclusion** | `qa-inclusion/SKILL.md` | WCAG 2.1 AA, semantic HTML, screen reader support |
| **Performance** | `qa-performance/SKILL.md` | N+1 queries, O(n^2), memory leaks, bundle size |
| **Test Strategy** | `qa-test-strategy/SKILL.md` | Coverage gaps, test quality, missing edge cases |
| **Report** | `qa-report/SKILL.md` | Consensus engine, deduplication, veto logic, verdict |
| **Feedback** | `qa-feedback/SKILL.md` | Processes dismissals, builds institutional memory |
| **Browser** | `qa-browser/SKILL.md` | Runtime functional testing via Chrome DevTools MCP |
| **Visual** | `qa-visual/SKILL.md` | Visual regression & design system compliance via Chrome DevTools MCP |

### Shared Conventions

All 12 skills reference six shared convention files in `skills/_shared/qase/` instead of inlining review logic. This removes duplication and ensures consistent behavior across the entire squad.

| File | Purpose |
|------|---------|
| `severity-contract.md` | BLOCKER/WARNING/INFO levels, veto power rules, verdict logic |
| `issue-format.md` | Standard finding format with metadata envelope for qa-report |
| `routing-rules.md` | Category detection patterns, routing matrix, risk calculation |
| `persistence-contract.md` | Mode resolution rules (engram/openspec/none), Engram detection |
| `engram-convention.md` | Deterministic naming (`qase/{review-id}/{type}`), 2-step recovery, SDD bridge |
| `openspec-convention.md` | File paths, directory structure, archive layout |

### Sub-Agent Result Contract

Each sub-agent returns a structured payload:

```json
{
  "status": "ok | warning | blocked | failed",
  "executive_summary": "short decision-grade summary",
  "artifacts": [
    {
      "name": "architect-report",
      "store": "engram | openspec | none",
      "ref": "observation-id | file-path | null"
    }
  ],
  "verdict_contribution": "APPROVE | APPROVE_WITH_WARNINGS | REJECT",
  "risks": ["optional risk list"]
}
```

---

## Runtime Prerequisites (for qa-browser & qa-visual)

The static specialists (architect, security, etc.) work out of the box — no extra dependencies. The two **runtime specialists** require external MCP servers:

| Dependency | Required For | What It Does |
|-----------|-------------|-------------|
| [Chrome DevTools MCP](https://github.com/nicholasgriffintn/chrome-devtools-mcp) | qa-browser, qa-visual | Connects to a running browser for screenshots, DOM inspection, network monitoring, viewport resizing |
| [Engram](https://github.com/gentleman-programming/engram) | All (recommended) | Persists reports across sessions, enables feedback loop and SDD bridge |

### Setup

**1. Chrome DevTools MCP** — add to your MCP config (`claude_desktop_config.json` or `.mcp.json`):

```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "@anthropic/chrome-devtools-mcp"]
    }
  }
}
```

**2. Engram** — add to your MCP config:

```json
{
  "mcpServers": {
    "engram": {
      "command": "npx",
      "args": ["-y", "@anthropic/engram-mcp"]
    }
  }
}
```

> Without Chrome DevTools MCP, `/qa-browser` and `/qa-visual` will report a BLOCKER and stop. Without Engram, reviews still work but results are inline-only (no cross-session persistence or feedback loop).

---

## Persistence

QASE supports three persistence modes:

| Mode | Where | Best for |
|------|-------|----------|
| `engram` | [Engram](https://github.com/gentleman-programming/engram) memory | Recommended — persists across sessions |
| `openspec` | `qaspec/` in project | When you want file artifacts in git |
| `none` | Nowhere | Quick one-off reviews |

Default: Engram if available (detected via `mem_stats()`), otherwise `none`. `openspec` is never chosen automatically — only when the user explicitly asks.

---

## Architecture

QASE uses a **fan-out/fan-in** pattern (unlike SDD's sequential DAG):

```
┌──────────────────────────────────────────────────────────┐
│  ORCHESTRATOR (your main agent)                          │
│                                                          │
│  Responsibilities:                                       │
│  • Detect Engram availability (mem_stats)                │
│  • Launch sub-agents via Task tool                       │
│  • Show summaries to user                                │
│  • Track state: which specialists reported, verdicts     │
│                                                          │
│  Context usage: MINIMAL (only state + summaries)         │
└──────────────┬───────────────────────────────────────────┘
               │
               │ Task(subagent_type: 'general-purpose', prompt: 'Read skill...')
               │
    ┌──────────┴──────────────────────────────────────────┐
    │                                                      │
    ▼          ▼          ▼         ▼         ▼           ▼
┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
│  ARCH  ││SECURITY││ADVOCATE││INCLUS. ││ PERF   ││  TEST  │
│        ││        ││        ││        ││        ││        │
│ Fresh  ││ Fresh  ││ Fresh  ││ Fresh  ││ Fresh  ││ Fresh  │
│context ││context ││context ││context ││context ││context │
└────┬───┘└────┬───┘└────┬───┘└────┬───┘└────┬───┘└────┬───┘
     └─────────┴─────────┴────┬────┴─────────┴─────────┘
                              │
                         ┌────▼─────┐
                         │qa-report │  fan-in: dedup + veto + verdict
                         └──────────┘
```

- **qa-scan** classifies changes and decides which specialists to activate
- **Specialists** run in parallel — no data dependencies between them
- **qa-report** aggregates, deduplicates, applies veto logic, produces verdict

This means reviews are fast — specialists don't wait for each other.

### SDD Bridge (Cross-System Integration)

When using `engram` mode and the verdict is REJECT or APPROVE WITH WARNINGS, qa-report generates an **actionable-issues** artifact. This bridges QASE with [SDD](https://github.com/Gentleman-Programming/agent-teams-lite) (or any fix-automation system).

```
QASE reviews → finds issues → persists actionable-issues → SDD discovers & creates fix proposals
```

SDD can search for these artifacts:
```
mem_search(query: "qase/actionable-issues", project: "{project}")
```

The bridge is **one-way** — QASE writes, SDD reads. No coupling between the systems.

---

## Installation

Dedicated setup guides for all supported tools:

- [Claude Code](#claude-code) — Full sub-agent support via Task tool
- [OpenCode](#opencode) — Full sub-agent support via Task tool
- [Gemini CLI](#gemini-cli) — Inline skill execution
- [Codex](#codex) — Inline skill execution
- [VS Code (Copilot)](#vs-code-copilot) — Agent mode with context files
- [Antigravity](#antigravity) — Native skill support
- [Cursor](#cursor) — Inline skill execution

### Claude Code

**1. Copy skills:**

```bash
# Using the install script
./scripts/install.sh  # Choose Claude Code

# Or manually
cp -r skills/qa-* ~/.claude/skills/
mkdir -p ~/.claude/skills/_shared/qase
cp skills/_shared/qase/*.md ~/.claude/skills/_shared/qase/
```

**2. Add orchestrator to `~/.claude/CLAUDE.md`:**

Append the contents of [`examples/claude-code/CLAUDE.md`](examples/claude-code/CLAUDE.md) to your existing `CLAUDE.md`.

**3. Verify:**

Open Claude Code and type `/qa-init` — it should recognize the command.

---

### OpenCode

**1. Copy skills and commands:**

```bash
# Using the install script (installs both skills + commands)
./scripts/install.sh  # Choose OpenCode

# Or manually
cp -r skills/qa-* ~/.config/opencode/skills/
cp examples/opencode/commands/qa-*.md ~/.config/opencode/commands/
```

**2. Add orchestrator agent to `~/.config/opencode/opencode.json`:**

Merge the `agent` block from [`examples/opencode/opencode.json`](examples/opencode/opencode.json) into your existing config.

**3. Verify:**

Open OpenCode, use the agent picker (Tab), choose `qase-orchestrator`, and type `/qa-init`.

---

### Gemini CLI

**1. Copy skills:**

```bash
./scripts/install.sh  # Choose Gemini CLI

# Or manually
cp -r skills/qa-* ~/.gemini/skills/
```

**2. Add orchestrator to `~/.gemini/GEMINI.md`:**

Append the contents of [`examples/gemini-cli/GEMINI.md`](examples/gemini-cli/GEMINI.md) to your Gemini system prompt file.

**3. Verify:**

Open Gemini CLI and type `/qa-init`.

> **Note:** Gemini CLI doesn't have a native Task tool for sub-agent delegation. Skills work as inline instructions. For true sub-agent experience, use Claude Code or OpenCode.

---

### Codex

**1. Copy skills:**

```bash
./scripts/install.sh  # Choose Codex

# Or manually
cp -r skills/qa-* ~/.codex/skills/
```

**2. Add orchestrator to `~/.codex/agents.md`:**

Append the contents of [`examples/codex/agents.md`](examples/codex/agents.md).

**3. Verify:**

Open Codex and type `/qa-init`.

---

### VS Code (Copilot)

**1. Copy skills to workspace:**

```bash
# Per-project (recommended)
cp -r skills/qa-* ./your-project/.vscode/skills/

# Or using the install script
./scripts/install.sh  # Choose VS Code
```

**2. Add orchestrator instructions:**

Append the contents of [`examples/vscode/copilot-instructions.md`](examples/vscode/copilot-instructions.md) to `.github/copilot-instructions.md`.

**3. Verify:**

Open VS Code Chat panel and type `/qa-init`.

---

### Antigravity

**1. Copy skills:**

```bash
# Global (available across all projects)
./scripts/install.sh  # Choose Antigravity

# Or manually (global)
cp -r skills/qa-* ~/.gemini/antigravity/skills/

# Workspace-specific (per project)
mkdir -p .agent/skills
cp -r skills/qa-* .agent/skills/
```

**2. Add orchestrator instructions:**

Add the orchestrator as a global rule in `~/.gemini/GEMINI.md`, or create a workspace rule at `.agent/rules/qase-orchestrator.md`.

See [`examples/antigravity/qase-orchestrator.md`](examples/antigravity/qase-orchestrator.md) for the rule content.

**3. Verify:**

Open Antigravity and type `/qa-init`.

---

### Cursor

**1. Copy skills:**

```bash
# Global
./scripts/install.sh  # Choose Cursor

# Or per-project
cp -r skills/qa-* ./your-project/skills/
```

**2. Add orchestrator to `.cursorrules`:**

Append the contents of [`examples/cursor/.cursorrules`](examples/cursor/.cursorrules) to your project's `.cursorrules` file.

**3. Verify:**

Open Cursor and type `/qa-init`.

> **Note:** Cursor runs skills inline rather than as true sub-agents. For fresh-context delegation, use Claude Code or OpenCode.

---

### Other Tools

The skills are pure Markdown. Any AI assistant that can read files can use them.

1. **Copy skills** to wherever your tool reads instructions from.
2. **Add orchestrator instructions** to your tool's system prompt or rules file.
3. **Add a `qase.json`** to `examples/<your-tool>/` and the installer will discover it automatically.

---

## Modular Installer Architecture

The installation system is built on a **discovery-based engine** that follows SOLID principles:

- **Engine (`scripts/install.sh`)**: Agnostic orchestrator that discovers tools dynamically from `qase.json` metadata.
- **Libraries (`scripts/lib/`)**: Modular components for OS detection, JSON parsing, and file operations.
- **Metadata (`qase.json`)**: Each tool in `examples/` defines its own installation paths and orchestrator source.

### How to add a new tool

1. Create a new directory in `examples/<your-tool>/`.
2. Add your orchestrator file (e.g., `INSTRUCTIONS.md`).
3. Create a `qase.json` file:

```json
{
  "id": "tool-id",
  "name": "Tool Name",
  "description": "Short description",
  "install": {
    "linux": "$HOME/.path/to/skills",
    "macos": "$HOME/.path/to/skills",
    "windows": "$USERPROFILE/.path/to/skills"
  },
  "orchestrator": {
    "source": "INSTRUCTIONS.md",
    "target_label": "~/.path/to/config",
    "auto_append": false
  }
}
```

The installer will automatically detect your tool and include it in the selection menu.

---

## Coexistence with SDD

QASE uses the `qa-` prefix. SDD uses the `sdd-` prefix. Both use isolated `_shared/` namespaces (`_shared/qase/` vs `_shared/`). They coexist in the same skills directory without conflict.

When both are installed with Engram, QASE can bridge its findings to SDD via the `actionable-issues` artifact — SDD discovers issues and creates fix proposals automatically.

---

## Project Structure

```
agent-teams-qa/
├── README.md
├── LICENSE
├── skills/                              ← The 12 sub-agent skill files + shared conventions
│   ├── _shared/qase/                    ← Shared conventions (isolated from SDD)
│   │   ├── persistence-contract.md      ← Mode resolution rules (engram/openspec/none)
│   │   ├── engram-convention.md         ← Deterministic naming & recovery protocol
│   │   ├── openspec-convention.md       ← File paths, directory structure, archive layout
│   │   ├── severity-contract.md         ← BLOCKER/WARNING/INFO levels, veto power
│   │   ├── issue-format.md              ← Standard finding format with metadata
│   │   └── routing-rules.md             ← Category detection, routing matrix, risk calc
│   ├── qa-init/SKILL.md
│   ├── qa-scan/SKILL.md
│   ├── qa-architect/SKILL.md
│   ├── qa-advocate/SKILL.md
│   ├── qa-security/SKILL.md
│   ├── qa-inclusion/SKILL.md
│   ├── qa-performance/SKILL.md
│   ├── qa-test-strategy/SKILL.md
│   ├── qa-report/SKILL.md
│   ├── qa-feedback/SKILL.md
│   ├── qa-browser/SKILL.md                ← Runtime: functional testing (Chrome DevTools MCP)
│   └── qa-visual/SKILL.md                 ← Runtime: visual regression (Chrome DevTools MCP)
├── examples/                            ← Config examples per tool + qase.json metadata
│   ├── claude-code/
│   │   ├── CLAUDE.md                    ← Orchestrator instructions
│   │   └── qase.json                    ← Tool metadata for installer
│   ├── opencode/
│   │   ├── opencode.json                ← Orchestrator agent config
│   │   ├── qase.json
│   │   └── commands/qa-*.md             ← 10 slash commands for OpenCode
│   ├── gemini-cli/
│   │   ├── GEMINI.md
│   │   └── qase.json
│   ├── codex/
│   │   ├── agents.md
│   │   └── qase.json
│   ├── antigravity/
│   │   ├── qase-orchestrator.md
│   │   └── qase.json
│   ├── vscode/
│   │   ├── copilot-instructions.md
│   │   └── qase.json
│   └── cursor/
│       ├── .cursorrules
│       └── qase.json
└── scripts/
    ├── install.sh                       ← Discovery-based interactive installer
    ├── install_test.sh                  ← Unit & integration tests for installer
    ├── lint_skills.sh                   ← SKILL.md structure linter
    └── lib/                             ← Modular installer libraries
        ├── os_detect.sh                 ← OS detection + terminal colors
        ├── json_parser.sh               ← Native JSON parser (no jq dependency)
        └── installer_core.sh            ← File operations + skill copy logic
```

---

## Contributing

PRs welcome. The skills are Markdown — easy to improve.

**To add a new specialist:**
1. Create `skills/qa-{name}/SKILL.md` following the existing format
2. Add routing rules for it in `skills/_shared/qase/routing-rules.md`
3. Update the orchestrator examples to include the new specialist
4. Run `bash scripts/lint_skills.sh` to validate

**To improve an existing specialist:**
1. Edit the `SKILL.md` directly
2. Run `bash scripts/lint_skills.sh` to validate
3. Submit PR with before/after examples

**To add a new tool:**
1. Create `examples/<your-tool>/` with orchestrator file + `qase.json`
2. The installer discovers it automatically

---

## License

MIT — see [LICENSE](LICENSE).

---

<p align="center">
  <strong>Created by <a href="https://github.com/dev-gios">dev-gios</a></strong>
  <br />
  <em>Inspired by <a href="https://github.com/Gentleman-Programming/agent-teams-lite">agent-teams-lite</a> by Gentleman Programming.</em>
  <br />
  <em>Because shipping without review is just vibe coding with extra steps.</em>
</p>
