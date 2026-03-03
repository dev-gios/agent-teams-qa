# Design: Finalize Modular Refactor

## Technical Approach

Finalize the transition to a metadata-driven discovery engine by creating `qase.json` files for all remaining tools and refactoring the test suite to validate modular components in isolation. This aligns with the "Discovery-based Engine" approach approved in the design phase.

## Architecture Decisions

### Decision: Metadata-Driven Discovery

**Choice**: Use `qase.json` in each tool's subdirectory within `examples/`.
**Alternatives considered**: Hardcoded routes in `install.sh` (rejected due to SRP/OCP violations).
**Rationale**: Decentralizing tool metadata allows the core engine to remain agnostic and extensible. Adding a new tool requires zero changes to the core scripts.

### Decision: Isolated Library Testing

**Choice**: Refactor `scripts/install_test.sh` to load and test `scripts/lib/*.sh` independently.
**Alternatives considered**: Testing only the main `install.sh` script (rejected as it masks library-level bugs).
**Rationale**: Unit testing the JSON parser and OS detection logic ensures robustness and easier debugging.

## Data Flow

The flow remains consistent with the modular engine:

1. `install.sh` (Entry) ──→ Load `lib/*.sh`
2. `discover_tools` ──→ Scan `examples/*/qase.json`
3. `interactive_menu` ──→ Present discovered tools to user
4. `install_tool` ──→ Resolve paths via `json_parser.sh` ──→ `install_skills_to_path` (Installer Core)

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `examples/cursor/qase.json` | Create | Metadata for Cursor editor. |
| `examples/vscode/qase.json` | Create | Metadata for VS Code (Copilot). |
| `examples/opencode/qase.json` | Create | Metadata for OpenCode. |
| `examples/codex/qase.json` | Create | Metadata for Codex. |
| `examples/antigravity/qase.json` | Create | Metadata for Antigravity. |
| `README.md` | Modify | Document modularity and extensibility guide. |
| `scripts/install_test.sh` | Modify | Implement modular test cases for libraries. |

## Interfaces / Contracts

### `qase.json` Schema

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
    "source": "ORCHESTRATOR.md",
    "target_label": "~/.path/to/config",
    "auto_append": false
  }
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `json_parser.sh` | Test `get_json_val` with various JSON inputs (nested, spaces, etc). |
| Unit | `os_detect.sh` | Verify OS detection variables are correctly set. |
| Integration | `install.sh` | Run discovery loop and verify tool registry is built correctly. |
| E2E | Installation | Perform a mock installation using a temporary directory. |

## Migration / Rollout

No migration required. The new engine is already in place and discovery is backward compatible with the current partial metadata.

## Open Questions

- [ ] Should `opencode` use a custom `requires_commands: true` flag in the schema for its extra files? (Recommendation: Keep it simple for now, generic copy handles it if structured correctly).
- [ ] Should we provide a `windows` path for all tools even if not fully tested? (Recommendation: Yes, as placeholders).
