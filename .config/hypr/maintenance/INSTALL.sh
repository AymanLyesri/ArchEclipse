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
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

MAINTENANCE_DIR="${SCRIPT_DIR}/maintenance"
CONF_DIR="${HOME}/ArchEclipse"
RAW_BASE_URL="https://raw.githubusercontent.com/AymanLyesri/ArchEclipse/master/.config/hypr"

bootstrap_error_exit() {
    echo -e "\033[0;31m✗ $1\033[0m"
    exit 1
}

if [ ! -f "${MAINTENANCE_DIR}/PRESENTATION.sh" ] || [ ! -f "${MAINTENANCE_DIR}/ESSENTIALS.sh" ]; then
    BOOTSTRAP_DIR="$(mktemp -d)"
    MAINTENANCE_DIR="${BOOTSTRAP_DIR}/maintenance"
    mkdir -p "${MAINTENANCE_DIR}"

    curl -fsSL "${RAW_BASE_URL}/maintenance/PRESENTATION.sh" -o "${MAINTENANCE_DIR}/PRESENTATION.sh" || bootstrap_error_exit "Failed to download PRESENTATION.sh"
    curl -fsSL "${RAW_BASE_URL}/maintenance/ESSENTIALS.sh" -o "${MAINTENANCE_DIR}/ESSENTIALS.sh" || bootstrap_error_exit "Failed to download ESSENTIALS.sh"
fi

# Source essentials FIRST (before presentation, to install core tools early)
source "${MAINTENANCE_DIR}/ESSENTIALS.sh"

# Prompt for sudo password once at the start
echo -e "\033[1;33m🔐 Requesting sudo password...\033[0m"
sudo -v
echo -e "\033[0;32m✓ Sudo access granted\033[0m\n"

# Install core tools early (includes lolcat and figlet needed for presentation)
echo "Installing core tools..."
install_core_tools
echo ""

# NOW source presentation (after lolcat is installed)
source "${MAINTENANCE_DIR}/PRESENTATION.sh"

# Error handler
trap 'error_exit "Error occurred at line $LINENO"' ERR

# Display main header (now lolcat and figlet are available)
print_main_header "INSTALL"

# Specify the repo branch
BRANCH="${1:-master}"

print_section_header "📦 REPOSITORY SETUP"

# Clone repository (overwrite existing directory)
if [ -d "${CONF_DIR}" ]; then
    run_step "[1/4]" "Repository already exists at ${CONF_DIR}; overwriting" "rm -rf ${CONF_DIR}"
fi

run_step "[1/4]" "Cloning ArchEclipse repository (latest commit only)" "git clone --depth 1 --single-branch --branch ${BRANCH} https://github.com/AymanLyesri/ArchEclipse.git ${CONF_DIR}"

cd "${CONF_DIR}" || error_exit "Failed to change directory to ${CONF_DIR}"

run_step "[2/4]" "Updating repository to '${BRANCH}' branch (latest commit only)" "git fetch --depth 1 origin ${BRANCH} && git checkout ${BRANCH} && git reset --hard FETCH_HEAD"

# Source essentials from absolute path
MAINTENANCE_DIR="${CONF_DIR}/maintenance"
print_step "[3/4]" "Repository setup complete"
print_success "Repository ready\n"

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

print_install_completion_message
