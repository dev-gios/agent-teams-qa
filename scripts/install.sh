#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# QASE (QA-Squad-Excellence) — Modular Installer
# Discovery-based engine using tool metadata (qase.json).
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SKILLS_SRC="$REPO_DIR/skills"
LIB_DIR="$SCRIPT_DIR/lib"

# Load Libraries
source "$LIB_DIR/os_detect.sh"
source "$LIB_DIR/json_parser.sh"
source "$LIB_DIR/installer_core.sh"

# ============================================================================
# Discovery & Setup
# ============================================================================

detect_os
setup_colors

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║    QASE — QA-Squad-Excellence Installer  ║${NC}"
    echo -e "${CYAN}${BOLD}║   Code Quality Review for AI Agents      ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${BOLD}Detected:${NC} $(os_label)"
}

# Validate that a qase.json has required fields: id, name, install.$OS
# Usage: validate_qase_json "path/to/qase.json"
# Returns 1 if any required field is missing or empty.
validate_qase_json() {
    local json_file="$1"
    local valid=0

    require_json_val "$json_file" "id" "tool identifier" > /dev/null 2>&1 || valid=1
    require_json_val "$json_file" "name" "tool name" > /dev/null 2>&1 || valid=1

    # Check install path for the current OS
    local install_path
    install_path=$(get_install_path "$json_file" "$OS") || true
    if [[ -z "$install_path" ]]; then
        echo "ERROR: Missing required field 'install.$OS' in $json_file (install path for $OS)" >&2
        valid=1
    fi

    return "$valid"
}

# Scan for available tools in examples/
discover_tools() {
    TOOLS_IDS=()
    TOOLS_NAMES=()
    TOOLS_DIRS=()
    
    local count=0
    for tool_json in "$REPO_DIR"/examples/*/qase.json; do
        if [ -f "$tool_json" ]; then
            # Validate required fields before adding to discovery
            if ! validate_qase_json "$tool_json"; then
                echo -e "${YELLOW}Warning: Skipping invalid tool: $tool_json${NC}" >&2
                continue
            fi

            local tool_dir
            tool_dir=$(dirname "$tool_json")
            local tool_id
            tool_id=$(get_json_val "$tool_json" "id")
            local tool_name
            tool_name=$(get_json_val "$tool_json" "name")

            TOOLS_IDS+=("$tool_id")
            TOOLS_NAMES+=("$tool_name")
            TOOLS_DIRS+=("$tool_dir")
            count=$((count + 1))
        fi
    done
    
    if [ "$count" -eq 0 ]; then
        echo -e "${RED}Error: No tools discovered in examples/ (missing qase.json files)${NC}"
        exit 1
    fi
}

# ============================================================================
# UI & Interaction
# ============================================================================

interactive_menu() {
    echo -e "${BOLD}Select your AI coding assistant:${NC}\n"
    for i in "${!TOOLS_NAMES[@]}"; do
        local json_path="${TOOLS_DIRS[$i]}/qase.json"
        local install_path
        install_path=$(get_install_path "$json_path" "$OS")
        echo "  $((i+1))) ${TOOLS_NAMES[$i]} ($(resolve_path "$install_path"))"
    done
    echo "  $(( ${#TOOLS_NAMES[@]} + 1 ))) Custom path"
    echo ""
    
    local choice
    read -rp "Choice [1-$(( ${#TOOLS_NAMES[@]} + 1 ))]: " choice
    
    if [[ "$choice" -le "${#TOOLS_NAMES[@]}" ]]; then
        local idx=$((choice - 1))
        install_tool "${TOOLS_IDS[$idx]}" "${TOOLS_DIRS[$idx]}"
    else
        install_custom
    fi
}

# ============================================================================
# Execution
# ============================================================================

install_tool() {
    local tool_id="$1"
    local tool_dir="$2"
    local json_path="$tool_dir/qase.json"
    
    local tool_name
    tool_name=$(get_json_val "$json_path" "name")
    local raw_target
    raw_target=$(get_install_path "$json_path" "$OS")
    local target_path
    target_path=$(resolve_path "$raw_target")
    
    echo -e "\n${BLUE}Installing QASE skills for ${BOLD}$tool_name${NC}${BLUE}...${NC}"
    
    install_skills_to_path "$target_path" "$tool_name" "$SKILLS_SRC"
    
    # Handle Orchestrator instructions (optional — some tools may not have one)
    local orch_source
    orch_source=$(get_orchestrator_val "$json_path" "source") || true
    local orch_label
    orch_label=$(get_orchestrator_val "$json_path" "target_label") || true
    
    if [[ -n "$orch_source" ]]; then
        echo -e "\n${YELLOW}Next step:${NC} Add the orchestrator to your ${BOLD}$orch_label${NC}"
        echo -e "  Source: ${CYAN}examples/$(basename "$tool_dir")/$orch_source${NC}"
    fi
}

install_custom() {
    local custom_path
    read -rp "Enter target path: " custom_path
    install_skills_to_path "$(resolve_path "$custom_path")" "Custom" "$SKILLS_SRC"
}

# ============================================================================
# Main
# ============================================================================

print_header
discover_tools

# Simple non-interactive support via --agent
AGENT_FLAG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --agent)
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: --agent requires a value (e.g., --agent claude-code)${NC}" >&2
                exit 1
            fi
            AGENT_FLAG="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ -n "$AGENT_FLAG" ]]; then
    FOUND=0
    for i in "${!TOOLS_IDS[@]}"; do
        if [[ "${TOOLS_IDS[$i]}" == "$AGENT_FLAG" ]]; then
            install_tool "${TOOLS_IDS[$i]}" "${TOOLS_DIRS[$i]}"
            FOUND=1
            break
        fi
    done
    if [[ "$FOUND" -eq 0 ]]; then
        echo -e "${RED}Error: Tool '$AGENT_FLAG' not found in discovery.${NC}"
        exit 1
    fi
else
    interactive_menu
fi

echo -e "\n${GREEN}${BOLD}Done!${NC} Start using QASE with: ${CYAN}/qa-init${NC}\n"
