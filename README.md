# QASE — QA-Squad-Excellence

An open-source agent-team orchestration framework for **code quality review**. QASE deploys a squad of specialized AI sub-agents that review your code in parallel for architecture, security, performance, accessibility, resilience, and test coverage — then produce a consensus verdict.

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

## The Squad (7 Specialists)

| Specialist | Role | Veto Power |
|-----------|------|:----------:|
| **qa-architect** | SOLID guardian, clean architecture | Yes |
| **qa-security** | OWASP Top 10, prompt injection | Yes |
| **qa-advocate** | "What if X fails?", resilience | No |
| **qa-inclusion** | WCAG 2.1 AA, accessibility | No |
| **qa-performance** | N+1 queries, O(n^2), memory leaks | No |
| **qa-test-strategy** | Coverage gaps, test quality | No |
| **qa-report** | Consensus engine, dedup, verdict | — |

Plus: **qa-init** (stack detection), **qa-scan** (triage/routing), **qa-feedback** (institutional memory).

## Install

```bash
# Clone the repo
git clone https://github.com/dev-gios/agent-teams-qa.git

# Run the installer
cd agent-teams-qa
bash scripts/install.sh
```

The installer copies skills to `~/.claude/skills/`, appends the orchestrator to your `CLAUDE.md`, and sets everything up automatically.

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

For non-Claude systems, manually copy the orchestrator from `examples/{system}/` and skills to the appropriate directory.

### Manual Install (Claude Code)

```bash
# Copy skills
cp -r skills/qa-* ~/.claude/skills/
mkdir -p ~/.claude/skills/_shared/qase
cp skills/_shared/qase/*.md ~/.claude/skills/_shared/qase/

# Add the orchestrator
cat examples/claude-code/CLAUDE.md >> ~/.claude/CLAUDE.md
```

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

## Persistence

QASE supports three persistence modes:

| Mode | Where | Best for |
|------|-------|----------|
| `engram` | [Engram](https://github.com/gentleman-programming/engram) memory | Recommended — persists across sessions |
| `openspec` | `qaspec/` in project | When you want file artifacts in git |
| `none` | Nowhere | Quick one-off reviews |

Default: Engram if available, otherwise none.

## Architecture

QASE uses a **fan-out/fan-in** pattern (unlike SDD's sequential DAG):

- **qa-scan** classifies changes and decides which specialists to activate
- **Specialists** run in parallel — no data dependencies between them
- **qa-report** aggregates, deduplicates, applies veto logic, produces verdict

This means reviews are fast — specialists don't wait for each other.

### Modular Installer Architecture

The installation system is built on a **discovery-based engine** that follows SOLID principles:

- **Engine (`scripts/install.sh`)**: Agnostic orchestrator that discovers tools dynamically.
- **Libraries (`scripts/lib/`)**: Modular components for OS detection, JSON parsing, and file operations.
- **Metadata (`qase.json`)**: Each tool in `examples/` defines its own installation paths and orchestrator source.

#### How to add a new tool

1. Create a new directory in `examples/<your-tool>/`.
2. Add your orchestrator file (e.g., `INSTRUCTIONS.md`).
3. Create a `qase.json` file with the following schema:

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

## Coexistence with SDD

QASE uses the `qa-` prefix. SDD uses the `sdd-` prefix. Both share `skills/_shared/` conventions. They can coexist in the same `~/.claude/skills/` directory without conflict.

## Project Structure

```
agent-teams-qa/
├── skills/
│   ├── _shared/qase/               # QASE shared contracts (isolated from SDD)
│   │   ├── persistence-contract.md
│   │   ├── engram-convention.md
│   │   ├── openspec-convention.md
│   │   ├── severity-contract.md
│   │   ├── issue-format.md
│   │   └── routing-rules.md
│   ├── qa-init/SKILL.md
│   ├── qa-scan/SKILL.md
│   ├── qa-architect/SKILL.md
│   ├── qa-advocate/SKILL.md
│   ├── qa-security/SKILL.md
│   ├── qa-inclusion/SKILL.md
│   ├── qa-performance/SKILL.md
│   ├── qa-test-strategy/SKILL.md
│   ├── qa-report/SKILL.md
│   └── qa-feedback/SKILL.md
├── examples/
│   ├── claude-code/CLAUDE.md
│   ├── cursor/.cursorrules
│   ├── gemini-cli/GEMINI.md
│   ├── codex/agents.md
│   ├── antigravity/qase-orchestrator.md
│   ├── vscode/copilot-instructions.md
│   └── opencode/
│       ├── opencode.json
│       └── commands/qa-*.md
├── scripts/
│   ├── install.sh
│   ├── install_test.sh
│   └── lint_skills.sh
├── README.md
└── LICENSE
```

## License

MIT — see [LICENSE](LICENSE).

## Credits

Created by [dev-gios](https://github.com/dev-gios).

Inspired by [agent-teams-lite](https://github.com/Gentleman-Programming/agent-teams-lite) by Gentleman Programming (used as reference for the skill/orchestrator pattern).
