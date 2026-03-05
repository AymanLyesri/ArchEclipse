#!/bin/bash

################################################################
# Color Codes
################################################################

BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################
# Display Functions
################################################################

error_exit() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

print_section_header() {
    local title="$1"
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}${MAGENTA}${title}${NC}  ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    local step=$1
    local description=$2
    echo -e "${YELLOW}${step}${NC} ${description}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_main_header() {
    local mode="${1:-INSTALL & UPDATE}"
    local subtitle="🚀 ArchEclipse Installation & Configuration"

    case "${mode}" in
        INSTALL)
            subtitle="🚀 ArchEclipse Installation & Configuration"
            ;;
        UPDATE)
            subtitle="🔄 ArchEclipse Update & Synchronization"
            ;;
    esac

    figlet "${mode}" -f slant | lolcat

    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${MAGENTA}  ${subtitle}${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_install_completion_message() {
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}                                                               ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}           🎉 Installation completed successfully! 🎉          ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}                                                               ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  ${BOLD}Please reboot your system to apply all changes:${NC}"
    echo ""
    echo -e "${CYAN}   ${BOLD}sudo reboot${NC}"
    echo ""
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_update_completion_message() {
    echo -e "${BOLD}${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║${NC}                                                               ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}            ✨ System updated successfully! ✨                 ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}                                                               ${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}${BOLD} All packages and configurations have been updated.${NC}"
    echo -e "${YELLOW}⚠️  ${BOLD}A reboot is recommended to ensure all changes take effect:${NC}"
    echo ""
    echo -e "${CYAN}   ${BOLD}sudo reboot${NC}"
    echo ""
    echo -e "${BOLD}${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    prompt_for_donation
}

################################################################
# Wrapper Functions
################################################################

run_step() {
    local step_num=$1
    local description=$2
    local command=$3
    
    print_step "$step_num" "$description"
    
    if eval "$command"; then
        print_success "$description"
        echo ""
    else
        error_exit "Failed: $description"
    fi
}

run_interactive_step() {
    local icon=$1
    local description=$2
    local command=$3
    
    continue_prompt "$icon $description" "$command"
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        error_exit "Failed: $description (exit code: $exit_code)"
    fi
}

run_section_step() {
    local icon=$1
    local description=$2
    local command=$3
    
    print_step "$icon" "$description"
    
    if eval "$command"; then
        print_success "$description"
    else
        error_exit "Failed: $description"
    fi
}

prompt_for_donation() {
    local monitor="$(hyprctl monitors | awk '/Monitor/ {monitor=$2} /focused: yes/ {print monitor}')"
    echo ""
    echo -e "${BOLD}${BLUE}💝 Support ArchEclipse${NC}"
    echo ""
    echo -e "${BLUE}ArchEclipse is maintained mainly by one person who spends a lot of time building, fixing, and improving it for the community.${NC}"
    echo -e "${BLUE}If this project has made your system better or saved you time, even a small donation can really help keep it alive and growing.${NC}"
    echo ""
    echo -e "${BLUE}Your support means a lot — thank you for being part of this project. ❤️${NC}"
    echo ""

    continue_prompt "💝 Would you like to support the project?" \ "ags request donations $monitor"
}
