#!/usr/bin/env bash
# ============================================================================
# Coherence fixture test harness.
# Runs each fixture corpus through the coherence checks and asserts BOTH the
# exit code AND that the output contains the expected check id.
# A fixture that fails for the wrong reason is a false green and is caught.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/coherence"
LIB_DIR="$SCRIPT_DIR/lib"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

assert_pass() {
    local label="$1"
    local output="$2"
    local exit_code="$3"
    if [ "$exit_code" -eq 0 ]; then
        printf "  ${GREEN}PASS${NC} %s\n" "$label"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        printf "  ${RED}FAIL${NC} %s (expected exit 0, got %d)\n" "$label" "$exit_code"
        printf "       Output: %s\n" "$output"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_fail_with_check() {
    local label="$1"
    local output="$2"
    local exit_code="$3"
    local expected_check="$4"
    if [ "$exit_code" -ne 0 ] && echo "$output" | grep -qF "$expected_check"; then
        printf "  ${GREEN}PASS${NC} %s (exit %d, found '%s' in output)\n" "$label" "$exit_code" "$expected_check"
        PASS_COUNT=$((PASS_COUNT + 1))
    elif [ "$exit_code" -eq 0 ]; then
        printf "  ${RED}FAIL${NC} %s (expected exit non-zero, got 0 — linter did not detect the defect)\n" "$label"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        printf "  ${RED}FAIL${NC} %s (exit %d but output did not contain '%s')\n" "$label" "$exit_code" "$expected_check"
        printf "       Output: %s\n" "$output"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ============================================================
# Inline runner — calls each check function and captures output
# ============================================================

run_check() {
    local check_fn="$1"
    local corpus_root="$2"
    local reg="$corpus_root/skills/_shared/qase/rule-ownership.md"

    # Source the library in a subshell so we can capture output and exit code.
    # Capture exit_code before || true so set -e cannot swallow a non-zero result.
    local output
    output=$(bash --norc --noprofile -c "
        set -euo pipefail
        PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
        pass() { echo \"PASS \$1\"; }
        fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
        warn() { echo \"WARN \$1\"; WARN_COUNT=\$((WARN_COUNT + 1)); }
        source '$LIB_DIR/coherence.sh'
        $check_fn '$reg' '$corpus_root'
        exit \$FAIL_COUNT
    " 2>&1)
    local exit_code=$?
    echo "$output"
    return "$exit_code"
}

run_all_checks() {
    local corpus_root="$1"
    local reg="$corpus_root/skills/_shared/qase/rule-ownership.md"

    local output
    # Capture exit code BEFORE || true — the subshell exits with FAIL_COUNT.
    # `|| true` only prevents set -e from aborting the outer script; we read
    # the real exit via the explicit assignment.
    output=$(bash --norc --noprofile -c "
        PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
        pass() { echo \"PASS \$1\"; }
        fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
        warn() { echo \"WARN \$1\"; WARN_COUNT=\$((WARN_COUNT + 1)); }
        source '$LIB_DIR/coherence.sh'
        run_coherence_checks '$corpus_root'
        printf '---- FAIL_COUNT=%d\n' \"\$FAIL_COUNT\"
        exit \$FAIL_COUNT
    " 2>&1)
    local exit_code=$?
    echo "$output"
    return "$exit_code"
}

# ============================================================
# Fixture 1: positive — expect exit 0
# ============================================================
printf "\n${BOLD}Fixture: positive${NC}\n"
output=$(run_all_checks "$FIXTURES_DIR/positive" 2>&1) ; ec=$?
assert_pass "positive corpus: all coherence checks pass (exit 0)" "$output" "$ec"

# ============================================================
# Fixture 2: neg-forbidden-token — expect exit 1, output must contain "C1"
# ============================================================
printf "\n${BOLD}Fixture: neg-forbidden-token${NC}\n"
output=$(bash --norc --noprofile -c "
    PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
    pass() { echo \"PASS \$1\"; }
    fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
    warn() { echo \"WARN \$1\"; }
    source '$LIB_DIR/coherence.sh'
    reg='$FIXTURES_DIR/neg-forbidden-token/skills/_shared/qase/rule-ownership.md'
    check_c1_forbidden_token \"\$reg\" '$FIXTURES_DIR/neg-forbidden-token'
    exit \$FAIL_COUNT
" 2>&1) ; ec=$?
assert_fail_with_check "neg-forbidden-token: C1 fires on unguarded HAS_BLOCKERS" "$output" "$ec" "C1"

# ============================================================
# Fixture 3: neg-undefined-placeholder — expect exit 1, output must contain "C2"
# ============================================================
printf "\n${BOLD}Fixture: neg-undefined-placeholder${NC}\n"
output=$(bash --norc --noprofile -c "
    PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
    pass() { echo \"PASS \$1\"; }
    fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
    warn() { echo \"WARN \$1\"; }
    source '$LIB_DIR/coherence.sh'
    reg='$FIXTURES_DIR/neg-undefined-placeholder/skills/_shared/qase/rule-ownership.md'
    check_c2_undefined_placeholder \"\$reg\" '$FIXTURES_DIR/neg-undefined-placeholder'
    exit \$FAIL_COUNT
" 2>&1) ; ec=$?
assert_fail_with_check "neg-undefined-placeholder: C2 fires on undeclared <evid>" "$output" "$ec" "C2"

# ============================================================
# Fixture 4: neg-missing-derivation — expect exit 1, output must contain "C3"
# ============================================================
printf "\n${BOLD}Fixture: neg-missing-derivation${NC}\n"
output=$(bash --norc --noprofile -c "
    PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
    pass() { echo \"PASS \$1\"; }
    fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
    warn() { echo \"WARN \$1\"; }
    source '$LIB_DIR/coherence.sh'
    reg='$FIXTURES_DIR/neg-missing-derivation/skills/_shared/qase/rule-ownership.md'
    check_c3_derivation_anchor \"\$reg\" '$FIXTURES_DIR/neg-missing-derivation'
    exit \$FAIL_COUNT
" 2>&1) ; ec=$?
assert_fail_with_check "neg-missing-derivation: C3 fires on missing anchor" "$output" "$ec" "C3"

# ============================================================
# Fixture 5: neg-missing-required-literal — expect exit 1, output must contain "C9"
# ============================================================
printf "\n${BOLD}Fixture: neg-missing-required-literal${NC}\n"
output=$(bash --norc --noprofile -c "
    PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
    pass() { echo \"PASS \$1\"; }
    fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
    warn() { echo \"WARN \$1\"; }
    source '$LIB_DIR/coherence.sh'
    reg='$FIXTURES_DIR/neg-missing-required-literal/skills/_shared/qase/rule-ownership.md'
    check_c9_required_literal \"\$reg\" '$FIXTURES_DIR/neg-missing-required-literal'
    exit \$FAIL_COUNT
" 2>&1) ; ec=$?
assert_fail_with_check "neg-missing-required-literal: C9 fires when required literal missing from orchestrator doc" "$output" "$ec" "C9"

# ============================================================
# Fixture 6: neg-empty-required-table — expect exit 1, output must contain "C9"
# ============================================================
printf "\n${BOLD}Fixture: neg-empty-required-table${NC}\n"
output=$(bash --norc --noprofile -c "
    PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
    pass() { echo \"PASS \$1\"; }
    fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
    warn() { echo \"WARN \$1\"; }
    source '$LIB_DIR/coherence.sh'
    reg='$FIXTURES_DIR/neg-empty-required-table/skills/_shared/qase/rule-ownership.md'
    check_c9_required_literal \"\$reg\" '$FIXTURES_DIR/neg-empty-required-table'
    exit \$FAIL_COUNT
" 2>&1) ; ec=$?
assert_fail_with_check "neg-empty-required-table: C9 fires on vacuous empty required table" "$output" "$ec" "C9"

# ============================================================
# Fixture 7: neg-unverified-as-clean — expect exit 1, output must contain "C10"
# ============================================================
printf "\n${BOLD}Fixture: neg-unverified-as-clean${NC}\n"
output=$(bash --norc --noprofile -c "
    PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
    pass() { echo \"PASS \$1\"; }
    fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
    warn() { echo \"WARN \$1\"; }
    source '$LIB_DIR/coherence.sh'
    check_c10_unverified_not_clean '$FIXTURES_DIR/neg-unverified-as-clean'
    exit \$FAIL_COUNT
" 2>&1) ; ec=$?
assert_fail_with_check "neg-unverified-as-clean: C10 fires on bare CLEAN refusal and one-token verdict template" "$output" "$ec" "C10"

# ============================================================
# Fixture 8: neg-step3b-else-verified — expect exit 1, output must contain "C11"
# Proves: flipping Step 3b ELSE from "→ unverified" to "→ verified" is caught.
# ============================================================
printf "\n${BOLD}Fixture: neg-step3b-else-verified${NC}\n"
output=$(bash --norc --noprofile -c "
    PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
    pass() { echo \"PASS \$1\"; }
    fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
    warn() { echo \"WARN \$1\"; }
    source '$LIB_DIR/coherence.sh'
    check_c11_coverage_resolution_mapping '$FIXTURES_DIR/neg-step3b-else-verified'
    exit \$FAIL_COUNT
" 2>&1) ; ec=$?
assert_fail_with_check "neg-step3b-else-verified: C11 fires when Step 3b ELSE resolves to verified" "$output" "$ec" "C11"

# ============================================================
# Fixture 9: neg-unpinned-orchestrator — expect exit 1, output must contain "C12"
# Proves: an orchestrator added to qase.json but not to the required table is caught.
# ============================================================
printf "\n${BOLD}Fixture: neg-unpinned-orchestrator${NC}\n"
output=$(bash --norc --noprofile -c "
    PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0
    pass() { echo \"PASS \$1\"; }
    fail() { echo \"FAIL \$1\"; FAIL_COUNT=\$((FAIL_COUNT + 1)); }
    warn() { echo \"WARN \$1\"; }
    source '$LIB_DIR/coherence.sh'
    reg='$FIXTURES_DIR/neg-unpinned-orchestrator/skills/_shared/qase/rule-ownership.md'
    check_c12_orchestrator_set_parity \"\$reg\" '$FIXTURES_DIR/neg-unpinned-orchestrator'
    exit \$FAIL_COUNT
" 2>&1) ; ec=$?
assert_fail_with_check "neg-unpinned-orchestrator: C12 fires when new orchestrator not in required table" "$output" "$ec" "C12"

# ============================================================
# Summary
# ============================================================
printf "\n${BOLD}=== Coherence Test Summary ===${NC}\n"
printf "  PASS: %d, FAIL: %d\n" "$PASS_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
    printf "${RED}${BOLD}RESULT: FAILED${NC}\n"
    exit 1
else
    printf "${GREEN}${BOLD}RESULT: ALL PASSED${NC}\n"
    exit 0
fi
