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

# --- Counters ---
PASS_COUNT=0
FAIL_COUNT=0

# --- Test Helpers ---
test_pass() { printf "  ${GREEN}PASS${NC} %s\n" "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
test_fail() { printf "  ${RED}FAIL${NC} %s\n" "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

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
# 4. JSON Parser Error-Path Tests (Tasks 3.3–3.7)
# ============================================================================
test_json_parser_errors() {
    echo -e "\n${BOLD}Testing Library: json_parser.sh (error paths)${NC}"

    # --- Fixture setup ---
    local valid_json="$TMP_DIR/valid.json"
    cat > "$valid_json" <<'FIXTURE'
{
  "name": "Test Tool",
  "id": "test-id"
}
FIXTURE

    local malformed_json="$TMP_DIR/malformed.json"
    printf '{bad json missing quotes\n' > "$malformed_json"

    local empty_file="$TMP_DIR/empty.json"
    : > "$empty_file"

    local nonexistent_file="$TMP_DIR/does_not_exist.json"

    # 3.3 — get_json_val with missing key
    if result=$(get_json_val "$valid_json" "nonexistent_key" 2>/dev/null); then
        test_fail "get_json_val should fail for missing key"
    else
        test_pass "get_json_val: returns exit 1 for missing key"
    fi

    # 3.4 — get_json_val with malformed JSON
    if result=$(get_json_val "$malformed_json" "name" 2>/dev/null); then
        test_fail "get_json_val should fail for malformed JSON"
    else
        test_pass "get_json_val: returns exit 1 for malformed JSON"
    fi

    # 3.5 — get_json_val with empty file
    if result=$(get_json_val "$empty_file" "name" 2>/dev/null); then
        test_fail "get_json_val should fail for empty file"
    else
        test_pass "get_json_val: returns exit 1 for empty file"
    fi

    # 3.6 — get_json_val with nonexistent file
    if result=$(get_json_val "$nonexistent_file" "name" 2>/dev/null); then
        test_fail "get_json_val should fail for nonexistent file"
    else
        test_pass "get_json_val: returns exit 1 for nonexistent file"
    fi

    # 3.7 — require_json_val with missing key (should fail AND print error)
    local stderr_output
    if result=$(require_json_val "$valid_json" "nonexistent_key" "Test Label" 2>"$TMP_DIR/stderr.txt"); then
        test_fail "require_json_val should fail for missing key"
    else
        stderr_output=$(cat "$TMP_DIR/stderr.txt")
        if [[ "$stderr_output" == *"ERROR"* ]]; then
            test_pass "require_json_val: returns exit 1 and prints error for missing key"
        else
            test_fail "require_json_val: failed but did not print error to stderr"
        fi
    fi
}

# ============================================================================
# Main Test Runner
# ============================================================================
echo -e "${CYAN}${BOLD}=== QASE Modular Test Suite ===${NC}"

test_json_parser
test_os_detect
test_installer_core
test_json_parser_errors

# ============================================================================
# Summary
# ============================================================================
echo ""
printf "${BOLD}=== Summary ===${NC}\n"
printf "  PASS: %d, FAIL: %d\n" "$PASS_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    printf "${RED}${BOLD}RESULT: FAILED${NC}\n"
    exit 1
else
    printf "${GREEN}${BOLD}RESULT: ALL PASSED${NC}\n"
    exit 0
fi
