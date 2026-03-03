#!/usr/bin/env bash

# ============================================================================
# QASE Native JSON Parser Library
# Extracts values from JSON files using grep/sed (no jq dependency).
# ============================================================================

# Extracts a top-level string value from a JSON file.
# Returns exit code 1 if file missing, key not found, or value empty.
# Usage: get_json_val "path/to/file.json" "key"
get_json_val() {
    local file="$1"
    local key="$2"

    if [ ! -f "$file" ]; then
        return 1
    fi

    # Extract value using grep/sed
    # 1. Look for the key line
    # 2. Extract content between quotes after the colon
    # 3. Clean up leading/trailing spaces and commas
    local result
    result=$(grep "\"$key\":" "$file" 2>/dev/null | \
        sed -E 's/.*: *"?([^",]+)"?,?/\1/' | \
        xargs | \
        sed 's/,$//') || true

    if [[ -z "$result" ]]; then
        return 1
    fi

    echo "$result"
}

# Extracts a value from a nested 'install' object based on OS.
# Returns exit code 1 if file missing, key not found, or value empty.
# Usage: get_install_path "path/to/file.json" "linux"
get_install_path() {
    local file="$1"
    local os_key="$2"

    if [ ! -f "$file" ]; then
        return 1
    fi

    # Find the install block and then the specific OS key
    local result
    result=$(sed -n '/"install":/,/}/p' "$file" 2>/dev/null | \
        grep "\"$os_key\":" | \
        sed -E 's/.*: *"?([^",]+)"?,?/\1/' | \
        xargs | \
        sed 's/,$//') || true

    if [[ -z "$result" ]]; then
        return 1
    fi

    echo "$result"
}

# Extracts a value from the 'orchestrator' block.
# Returns exit code 1 if file missing, key not found, or value empty.
# Usage: get_orchestrator_val "path/to/file.json" "source"
get_orchestrator_val() {
    local file="$1"
    local key="$2"

    if [ ! -f "$file" ]; then
        return 1
    fi

    local result
    result=$(sed -n '/"orchestrator":/,/}/p' "$file" 2>/dev/null | \
        grep "\"$key\":" | \
        sed -E 's/.*: *"?([^",]+)"?,?/\1/' | \
        xargs | \
        sed 's/,$//') || true

    if [[ -z "$result" ]]; then
        return 1
    fi

    echo "$result"
}

# Validates and extracts a required top-level string value from a JSON file.
# Prints error to stderr and returns exit code 1 if value is empty/missing.
# Usage: require_json_val "path/to/file.json" "key" "human-readable label"
require_json_val() {
    local file="$1"
    local key="$2"
    local label="$3"

    local value
    value=$(get_json_val "$file" "$key") || true

    if [[ -z "$value" ]]; then
        echo "ERROR: Missing required field '$key' in $file ($label)" >&2
        return 1
    fi

    echo "$value"
}
