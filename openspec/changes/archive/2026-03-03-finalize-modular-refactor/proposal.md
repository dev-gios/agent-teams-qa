# Proposal: Finalize Modular Refactor

## Intent

Complete the transition to the modular QASE architecture by providing metadata for all supported tools, updating the project documentation to reflect the new extensible design, and improving automated testing for the new library-based structure.

## Scope

### In Scope
- Create `qase.json` for remaining tools: `cursor`, `vscode`, `opencode`, `codex`, `antigravity`.
- Update `README.md` to explain the modular architecture and how to add new tools.
- Refactor and improve `scripts/install_test.sh` to test modular libraries (`scripts/lib/`) in isolation.
- Ensure `scripts/lint_skills.sh` remains functional with the new changes.

### Out of Scope
- Adding new specialists or changing core skill logic.
- Supporting Windows native CMD (Git Bash/WSL only).

## Approach

Use the established dynamic discovery engine in `scripts/install.sh`. Each tool in `examples/` will get a `qase.json` file defining its installation paths and orchestrator source. The documentation will be updated to act as a guide for extensibility (OCP). Tests will be modularized to match the new `scripts/lib/` structure.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `examples/*/qase.json` | New | Metadata for all supported tools. |
| `README.md` | Modified | Updated instructions for the modular system. |
| `scripts/install_test.sh` | Modified | Improved test coverage for modular components. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Incorrect default paths for some editors | Medium | Verify paths against official documentation for each tool. |
| Breaking changes in `install_test.sh` | Low | Run tests incrementally after each change. |

## Rollback Plan

Delete the newly created `qase.json` files and revert `README.md` and `scripts/install_test.sh` using git checkout.

## Dependencies

- Existing modular engine in `scripts/install.sh`.
- Metadata contract defined in `docs/plans/2026-03-03-install-refactor-design.md`.

## Success Criteria

- [ ] All 7 supported tools are discoverable and installable via `scripts/install.sh`.
- [ ] `README.md` clearly explains how to add a new tool via `qase.json`.
- [ ] `scripts/install_test.sh` passes and covers `scripts/lib/` logic.
- [ ] Final QASE review returns an `APPROVE` verdict.
