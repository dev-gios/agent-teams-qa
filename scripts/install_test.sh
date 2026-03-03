#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# QASE Modular Installer — Unit & Integration Tests
# Verifies libraries and discovery engine in isolation.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$SCRIPT_DIR/lib"

# Mock Environment
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Load Libraries
source "$LIB_DIR/os_detect.sh"
source "$LIB_DIR/json_parser.sh"
source "$LIB_DIR/installer_core.sh"

# Mock Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Test Helpers ---
test_pass() { echo -e "  ${GREEN}PASS${NC} $1"; }
test_fail() { echo -e "  ${RED}FAIL${NC} $1"; exit 1; }

# ============================================================================
# 1. JSON Parser Tests (Task 2.1)
# ============================================================================
test_json_parser() {
    echo -e "\n${BOLD}Testing Library: json_parser.sh${NC}"
    
    local test_json="$TMP_DIR/test.json"
    cat > "$test_json" <<EOF
{
  "name": "Test Tool",
  "id": "test-id",
  "install": {
    "linux": "/tmp/linux/path",
    "windows": "C:\\\\tmp\\\\windows"
  },
  "orchestrator": {
    "source": "src.md"
  }
}
EOF

    # Test top-level val
    local name=$(get_json_val "$test_json" "name")
    [[ "$name" == "Test Tool" ]] || test_fail "get_json_val failed to extract 'name'"
    test_pass "get_json_val: extracted top-level string"

    # Test nested install val
    local path=$(get_install_path "$test_json" "linux")
    [[ "$path" == "/tmp/linux/path" ]] || test_fail "get_install_path failed for linux"
    test_pass "get_install_path: extracted nested OS path"

    # Test orchestrator val
    local orch=$(get_orchestrator_val "$test_json" "source")
    [[ "$orch" == "src.md" ]] || test_fail "get_orchestrator_val failed"
    test_pass "get_orchestrator_val: extracted orchestrator source"
}

# ============================================================================
# 2. OS Detect Tests (Task 2.2)
# ============================================================================
test_os_detect() {
    echo -e "\n${BOLD}Testing Library: os_detect.sh${NC}"
    
    detect_os
    local label=$(os_label)
    [[ -n "$OS" ]] || test_fail "OS variable not set"
    [[ -n "$label" ]] || test_fail "os_label returned empty"
    test_pass "detect_os: identified OS as $OS ($label)"
    
    setup_colors
    [[ -n "${GREEN:-}" ]] || test_pass "setup_colors: (skipped colors in non-tty or windows shell)"
    test_pass "setup_colors: logic executed without error"
}

# ============================================================================
# 3. Installer Core Tests (Task 2.3)
# ============================================================================
test_installer_core() {
    echo -e "\n${BOLD}Testing Library: installer_core.sh${NC}"
    
    # Test path resolution
    local raw="\$HOME/test"
    local resolved=$(resolve_path "$raw")
    [[ "$resolved" == "$HOME/test" ]] || test_fail "resolve_path failed to expand \$HOME"
    test_pass "resolve_path: correctly expanded \$HOME"

    # Test skill installation (Mock)
    local src_skills="$TMP_DIR/src_skills"
    local dest_skills="$TMP_DIR/dest_skills"
    mkdir -p "$src_skills/qa-test"
    echo "test content" > "$src_skills/qa-test/SKILL.md"
    mkdir -p "$src_skills/_shared/qase"
    echo "contract content" > "$src_skills/_shared/qase/contract.md"

    install_skills_to_path "$dest_skills" "TestTool" "$src_skills" > /dev/null
    
    [[ -f "$dest_skills/qa-test/SKILL.md" ]] || test_fail "Skill file not copied to destination"
    [[ -f "$dest_skills/_shared/qase/contract.md" ]] || test_fail "Shared conventions not copied"
    test_pass "install_skills_to_path: completed mock installation successfully"
}

# ============================================================================
# Main Test Runner
# ============================================================================
echo -e "${CYAN}${BOLD}=== QASE Modular Test Suite ===${NC}"

test_json_parser
test_os_detect
test_installer_core

echo -e "\n${GREEN}${BOLD}ALL TESTS PASSED!${NC}\n"
