#!/usr/bin/env bash

# ============================================================================
# QASE Native JSON Parser Library
# Extracts values from JSON files using grep/sed (no jq dependency).
# ============================================================================

# Extracts a top-level string value from a JSON file.
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
    grep "\"$key\":" "$file" | \
        sed -E 's/.*: *"?([^",]+)"?,?/\1/' | \
        xargs | \
        sed 's/,$//'
}

# Extracts a value from a nested 'install' object based on OS.
# Usage: get_install_path "path/to/file.json" "linux"
get_install_path() {
    local file="$1"
    local os_key="$2"

    if [ ! -f "$file" ]; then
        return 1
    fi

    # Find the install block and then the specific OS key
    sed -n '/"install":/,/}/p' "$file" | \
        grep "\"$os_key\":" | \
        sed -E 's/.*: *"?([^",]+)"?,?/\1/' | \
        xargs | \
        sed 's/,$//'
}

# Extracts a value from the 'orchestrator' block.
# Usage: get_orchestrator_val "path/to/file.json" "source"
get_orchestrator_val() {
    local file="$1"
    local key="$2"

    if [ ! -f "$file" ]; then
        return 1
    fi

    sed -n '/"orchestrator":/,/}/p' "$file" | \
        grep "\"$key\":" | \
        sed -E 's/.*: *"?([^",]+)"?,?/\1/' | \
        xargs | \
        sed 's/,$//'
}
