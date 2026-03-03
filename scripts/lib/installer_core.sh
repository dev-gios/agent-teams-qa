#!/usr/bin/env bash

# ============================================================================
# QASE Installer Core Library
# Handles file operations, permissions, and skill installation logic.
# ============================================================================

# Makes a file or directory writable if it exists.
# Respects current user permissions.
make_writable() {
    local target="$1"
    if [[ -e "$target" ]]; then
        if [[ "$OS" != "windows" ]]; then
            chmod u+w "$target" 2>/dev/null || true
        fi
    fi
}

# Generic skill installer to a target path.
# Usage: install_skills_to_path "target_dir" "tool_name" "skills_src_dir"
install_skills_to_path() {
    local target_dir="$1"
    local tool_name="$2"
    local skills_src="$3"

    # Atomic write permission check
    mkdir -p "$target_dir" 2>/dev/null
    if [ ! -w "$target_dir" ]; then
        echo -e "  ${RED}✗${NC} Error: No write permission to ${BOLD}$target_dir${NC}"
        return 1
    fi

    # 1. Install Shared Conventions
    local shared_src="$skills_src/_shared/qase"
    local shared_target="$target_dir/_shared/qase"

    if [ -d "$shared_src" ]; then
        mkdir -p "$shared_target"
        cp "$shared_src"/*.md "$shared_target/"
    fi

    # 2. Install Individual Skills
    local count=0
    for skill_dir in "$skills_src"/qa-*/; do
        local skill_name
        skill_name=$(basename "$skill_dir")

        if [ ! -f "$skill_dir/SKILL.md" ]; then
            continue
        fi

        local skill_target="$target_dir/$skill_name"
        mkdir -p "$skill_target"
        make_writable "$skill_target/SKILL.md"
        cp "$skill_dir/SKILL.md" "$skill_target/SKILL.md"
        count=$((count + 1))
    done

    echo -e "  ${GREEN}✓${NC} ${BOLD}$count${NC} skills installed → $target_dir"
}

# Resolve system paths (expand $HOME, $USERPROFILE)
resolve_path() {
    local raw_path="$1"
    # Expand $HOME and $USERPROFILE (handle potentially unbound variables)
    local resolved
    resolved="${raw_path/\$HOME/${HOME:-}}"
    resolved="${resolved/\$USERPROFILE/${USERPROFILE:-}}"
    echo "$resolved"
}
