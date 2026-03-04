#!/bin/bash
set -euo pipefail

################################################################
# Counter for Installations
################################################################

curl -s -o /dev/null "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=install" || true

################################################################
# Hyprland ArchEclipse Installation Script
################################################################

# Set absolute paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAINTENANCE_DIR="${SCRIPT_DIR}/maintenance"
CONF_DIR="${HOME}/ArchEclipse"

# Source display functions
source "${MAINTENANCE_DIR}/PRESENTATION.sh"

# Error handler
trap 'error_exit "Error occurred at line $LINENO"' ERR

# Display main header
print_main_header

# Prompt for sudo password once at the start
echo -e "${YELLOW}🔐 Requesting sudo password...${NC}"
sudo -v
print_success "Sudo access granted\n"

# Specify the repo branch
BRANCH="${1:-master}"

print_section_header "📦 REPOSITORY SETUP"

# Clone or update repository
if [ -d "${CONF_DIR}" ]; then
    print_step "[1/4]" "Repository already exists at ${CONF_DIR}"
    print_success "Skipping clone\n"
else
    run_step "[1/4]" "Cloning ArchEclipse repository" "git clone https://github.com/AymanLyesri/ArchEclipse.git ${CONF_DIR}"
fi

cd "${CONF_DIR}" || error_exit "Failed to change directory to ${CONF_DIR}"

run_step "[2/4]" "Updating repository to '${BRANCH}' branch" "git checkout ${BRANCH} && git fetch origin ${BRANCH} && git reset --hard origin/${BRANCH}"

# Source essentials from absolute path
print_step "[3/4]" "Loading essential functions..."
source "${MAINTENANCE_DIR}/ESSENTIALS.sh"
print_success "Essentials loaded\n"

run_step "[4/4]" "Installing core tools" "install_core_tools"

print_section_header "🔧 AUR HELPER SELECTION"

echo -e "${BOLD}${YELLOW}📋 Select an AUR helper to install packages:${NC}"
echo ""
echo -e "${CYAN}  [1]${NC} ${BOLD}yay${NC}  - AUR helper (Rust based)"
echo -e "${CYAN}  [2]${NC} ${BOLD}paru${NC} - AUR helper (Rust based)"
echo ""

aur_helpers=("yay" "paru")
aur_helper=$(printf '%s\n' "${aur_helpers[@]}" | fzf --height "25") || {
    error_exit "No AUR helper selected. Exiting."
}

echo ""
print_success "AUR helper selected: ${BOLD}${MAGENTA}${aur_helper}${NC}\n"

case "${aur_helper}" in
    yay)
        run_section_step "⚙️" "Installing ${BOLD}yay${NC}" "install_yay"
        ;;
    paru)
        run_section_step "⚙️" "Installing ${BOLD}paru${NC}" "install_paru"
        ;;
    *)
        error_exit "Invalid AUR helper selected"
        ;;
esac

echo ""

print_section_header "💾 CONFIGURATION FILES"

run_interactive_step "📁" "Backing up dotfiles from ${BOLD}.config${NC}" "${MAINTENANCE_DIR}/BACKUP.sh"

run_interactive_step "📋" "Copying configuration files to ${HOME}" "sudo cp -a . ${HOME}"

print_section_header "⌨️ KEYBOARD CONFIGURATION"

run_interactive_step "🔨" "Setting up keyboard configuration" "${MAINTENANCE_DIR}/CONFIGURE.sh"

print_section_header "📦 PACKAGE MANAGEMENT"

run_interactive_step "🧹" "Removing unwanted packages" "remove_packages"

run_interactive_step "📥" "Installing necessary packages (using ${BOLD}${aur_helper}${NC})" "${HOME}/.config/hypr/pacman/install-pkgs.sh ${aur_helper}"

print_section_header "🎨 SYSTEM THEME & APPEARANCE"

run_interactive_step "🖨️" "Setting up SDDM theme" "${MAINTENANCE_DIR}/SDDM.sh"

run_section_step "⚙️" "Applying default configurations" "${MAINTENANCE_DIR}/DEFAULTS.sh"

run_section_step "🖼️" "Setting up wallpapers" "${MAINTENANCE_DIR}/WALLPAPERS.sh"

print_section_header "🔌 PLUGINS & TWEAKS"

run_section_step "🔌" "Installing plugins" "${MAINTENANCE_DIR}/PLUGINS.sh"

run_section_step "✨" "Applying system tweaks" "${MAINTENANCE_DIR}/TWEAKS.sh"

print_section_header "✅ INSTALLATION COMPLETE"

print_completion_message
