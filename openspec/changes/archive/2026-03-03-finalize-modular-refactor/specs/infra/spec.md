# Infrastructure Specification

## Purpose

Define the behavior of the modular QASE installation engine and its supporting libraries.

## Requirements

### Requirement: Dynamic Tool Discovery

The system MUST discover all AI tools located in `examples/` that contain a valid `qase.json` file.

#### Scenario: Tool Discovery in Interactive Menu

- GIVEN a tool directory exists in `examples/custom-tool/`
- AND a valid `qase.json` exists in that directory
- WHEN `scripts/install.sh` is executed without arguments
- THEN the interactive menu MUST include "custom-tool" as an option
- AND the menu MUST show the correct installation path for the current OS

### Requirement: Modular Skill Installation

The system MUST install skills to the path defined in the tool's `qase.json` for the detected OS.

#### Scenario: Successful Installation to Detected OS Path

- GIVEN the OS is detected as "linux"
- AND `examples/gemini-cli/qase.json` defines a linux path as `$HOME/.gemini/skills`
- WHEN `scripts/install.sh --agent gemini-cli` is executed
- THEN the skills MUST be copied to `/home/user/.gemini/skills`
- AND the shared conventions MUST be included in the destination

### Requirement: Isolated Library Testing

The test suite MUST validate modular libraries (`scripts/lib/*.sh`) independently of the main installer.

#### Scenario: JSON Parser Validation

- GIVEN a temporary test JSON file
- WHEN `get_json_val` is called from `scripts/lib/json_parser.sh`
- THEN it MUST return the correct value for a given key
- AND it MUST handle keys with special characters or spaces
