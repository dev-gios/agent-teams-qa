# Design Document: QASE Modular Installer Refactor

**Date**: 2026-03-03
**Status**: Finalized (Approved)
**Topic**: Refactoring `install.sh` and `lint_skills.sh` for SRP/OCP compliance.

## 1. Problem Statement
The current `install.sh` and `lint_skills.sh` scripts are "God Scripts" that contain hardcoded logic for every supported AI tool (Claude Code, Gemini CLI, etc.). This violates:
- **Single Responsibility Principle (SRP)**: The scripts handle OS detection, UI, logic, and installation for all tools.
- **Open/Closed Principle (OCP)**: Adding a new tool requires modifying the core scripts.
- **Resilience**: Lacks atomic validations and robust error handling.

## 2. Proposed Architecture
A modular approach separating the installation engine from the tool-specific metadata.

### 2.1 Component Overview
- **The Engine (`scripts/install.sh`)**: Orchestrates the process. Agnostic to specific tools.
- **Discovery Module**: Scans `examples/*/qase.json` to build the interactive menu dynamically.
- **OS/UI Lib (`scripts/lib/os_detect.sh`)**: Pure OS detection and terminal formatting.
- **Parser Lib (`scripts/lib/json_parser.sh`)**: Native Bash functions (`sed`/`grep`) to extract metadata from `qase.json`.
- **Installer Core (`scripts/lib/installer_core.sh`)**: Generic file copy and permission handling.

### 2.2 Metadata Contract (`qase.json`)
Each tool folder in `examples/` must contain a `qase.json` with:
- `id`: Unique identifier.
- `name`: Display name for the menu.
- `install`: Object mapping OS (linux, macos, windows) to target paths.
- `orchestrator`: Source file and target instructions.

## 3. Data Flow
1. **Init**: Load libraries (`os_detect`, `json_parser`).
2. **Discovery**: Loop through `examples/` and build a tool registry from `qase.json` files.
3. **Selection**: User picks a tool from the dynamically generated menu.
4. **Resolution**: Engine resolves the target path using `$OS` and the tool's `qase.json`.
5. **Execution**: Engine copies `skills/` to the resolved path and provides orchestrator instructions.

## 4. Error Handling & Resilience
- **Validation**: Check write permissions (`[ -w "$TARGET" ]`) before any operation.
- **Fallback**: Clear error messages if `qase.json` is missing fields for the current OS.
- **No Dependencies**: All logic must remain native Bash (no `jq` requirement).

## 5. Success Criteria
- `install.sh` logic reduced to orchestration only.
- Adding a tool requires zero changes to `scripts/`.
- All QASE architect warnings (SRP/OCP) resolved in the next review.
