#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# QASE SKILL.md Linter
# Validates all skills/qa-*/SKILL.md files.
# Refactored for dynamic tool discovery.
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$PROJECT_DIR/skills"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# --- Counters ---
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { printf "  ${GREEN}PASS${NC} %s\n" "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { printf "  ${RED}FAIL${NC} %s\n" "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { printf "  ${YELLOW}WARN${NC} %s\n" "$1"; WARN_COUNT=$((WARN_COUNT + 1)); }

# --- Collect SKILL.md files ---
SKILL_FILES=()
for skill_dir in "$SKILLS_DIR"/qa-*/; do
    if [ -f "$skill_dir/SKILL.md" ]; then
        SKILL_FILES+=("$skill_dir/SKILL.md")
    fi
done

if [ ${#SKILL_FILES[@]} -eq 0 ]; then
    printf "${RED}ERROR${NC}: No SKILL.md files found in %s/qa-*/\n" "$SKILLS_DIR"
    exit 1
fi

printf "${BOLD}=== QASE SKILL.md Linter ===${NC}\n"
printf "Found %d skill files to validate\n\n" "${#SKILL_FILES[@]}"

# ============================================================
# Validation Checks
# ============================================================

for skill_file in "${SKILL_FILES[@]}"; do
    skill_name=$(basename "$(dirname "$skill_file")")
    printf "\n ${BOLD}%s${NC}\n" "$skill_name"

    # 1. Frontmatter Delimiters
    if [ "$(head -n 1 "$skill_file")" != "---" ]; then
        fail "Missing frontmatter opening '---'"
        continue
    fi

    second_marker=$(awk 'NR > 1 && /^---$/ { print NR; exit }' "$skill_file")
    if [ -z "$second_marker" ]; then
        fail "Missing frontmatter closing '---'"
        continue
    fi
    pass "Frontmatter delimiters present"

    # 2. Required Fields
    frontmatter=$(awk "NR > 1 && NR < $second_marker" "$skill_file")
    for field in name description license; do
        if echo "$frontmatter" | grep -qE "^${field}:"; then
            pass "Field '${field}' present"
        else
            fail "Missing required field '${field}'"
        fi
    done

    # 3. Required Markdown Sections
    for section in "## Purpose" "## Execution and Persistence Contract" "## What to Do" "## Rules"; do
        if grep -qF "$section" "$skill_file"; then
            pass "Section '${section}' present"
        else
            fail "Missing section '${section}'"
        fi
    done

    # 4. Persistence Convention References
    if grep -q 'persistence-contract\.md' "$skill_file"; then
        pass "References persistence-contract.md"
    else
        fail "Missing reference to persistence-contract.md"
    fi
done

# ============================================================
# Summary
# ============================================================
printf "\n${BOLD}=== Summary ===${NC}\n"
printf "  PASS: %d, FAIL: %d, WARN: %d\n" "$PASS_COUNT" "$FAIL_COUNT" "$WARN_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    printf "${RED}${BOLD}RESULT: FAILED${NC}\n"
    exit 1
else
    printf "${GREEN}${BOLD}RESULT: ALL PASSED${NC}\n"
    exit 0
fi
