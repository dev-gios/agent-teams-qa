# Tasks: Finalize Modular Refactor

## Phase 1: Tool Metadata (Implementation)

- [x] 1.1 Create `examples/cursor/qase.json` with Cursor-specific paths and orchestrator.
- [x] 1.2 Create `examples/vscode/qase.json` with VS Code-specific paths and orchestrator.
- [x] 1.3 Create `examples/opencode/qase.json` with OpenCode-specific paths and orchestrator.
- [x] 1.4 Create `examples/codex/qase.json` with Codex-specific paths and orchestrator.
- [x] 1.5 Create `examples/antigravity/qase.json` with Antigravity-specific paths and orchestrator.

## Phase 2: Testing Refactor (Infrastructure)

- [x] 2.1 Refactor `scripts/install_test.sh` to source and test `scripts/lib/json_parser.sh` in isolation.
- [x] 2.2 Add unit tests to `scripts/install_test.sh` for `scripts/lib/os_detect.sh` logic.
- [x] 2.3 Implement mock installation test in `scripts/install_test.sh` to verify `scripts/lib/installer_core.sh`.

## Phase 3: Documentation & Integration (Polish)

- [x] 3.1 Update `README.md` with Modular Architecture Overview (Scenario: Architecture Explanation).
- [x] 3.2 Add "How to add a new tool" guide to `README.md` (Scenario: Guide for Adding New Tools).
- [x] 3.3 Verify discovery loop in `scripts/install.sh` by adding a temporary mock tool in `examples/`.

## Phase 4: Final Validation

- [x] 4.1 Run `bash scripts/lint_skills.sh` and ensure all skills are valid.
- [x] 4.2 Run `bash scripts/install_test.sh` and ensure all modular tests pass.
- [x] 4.3 Execute a full QASE review to confirm SRP/OCP compliance and CLEAN verdict.
