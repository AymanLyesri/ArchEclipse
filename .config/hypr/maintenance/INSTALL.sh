#!/bin/bash
set -euo pipefail

################################################################
# Counter for Installations
################################################################

curl -s -o /dev/null "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=install" || true

################################################################
# Hyprland ArchEclipse Installation Script
################################################################

CONF_DIR="${HOME}/ArchEclipse"

# Minimal inline functions (before any sourcing)
error_exit() {
    echo -e "\033[0;31m✗ $1\033[0m"
    exit 1
}

sync_configuration_files() {
    local scanned_paths=0
    local resolved_conflicts=0
    
    [ -d "${HOME}" ] || error_exit "HOME directory not found: ${HOME}"
    
    echo "Preparing copy operation from ${CONF_DIR} to ${HOME}..."
    echo "Step 1/3: Scanning for file/directory type conflicts..."
    
    # Remove type conflicts first, then copy everything.
    while IFS= read -r -d '' rel_path; do
        local src_path="./${rel_path}"
        local dst_path="${HOME}/${rel_path}"
        
        scanned_paths=$((scanned_paths + 1))
        
        [ -e "${dst_path}" ] || continue
        
        if [ -d "${src_path}" ] && [ ! -d "${dst_path}" ]; then
            echo "  - Replacing file with directory target: ${dst_path}"
            sudo rm -f "${dst_path}"
            resolved_conflicts=$((resolved_conflicts + 1))
            elif [ ! -d "${src_path}" ] && [ -d "${dst_path}" ]; then
            echo "  - Replacing directory with file target: ${dst_path}"
            sudo rm -rf "${dst_path}"
            resolved_conflicts=$((resolved_conflicts + 1))
        fi
    done < <(find . -mindepth 1 -printf '%P\0')
    
    echo "Step 2/3: Scan complete (${scanned_paths} paths checked, ${resolved_conflicts} conflicts resolved)."
    echo "Step 3/3: Copying ArchEclipse content into ${HOME}..."
    
    sudo cp -a --remove-destination . "${HOME}"
    
    echo "Copy completed successfully."
}

# Prompt for sudo password once at the start
echo -e "\033[1;33m🔐 Requesting sudo password...\033[0m"
sudo -v
echo -e "\033[0;32m✓ Sudo access granted\033[0m\n"

# Clone repository (overwrite existing directory)
if [ -d "${CONF_DIR}" ]; then
    echo -e "\033[1;33m🔄 Repository already exists at ${CONF_DIR}; overwriting\033[0m"
    rm -rf "${CONF_DIR}"
fi

echo "Cloning ArchEclipse repository (latest commit only)..."
BRANCH="${1:-master}"
git clone --depth 1 --single-branch --branch "${BRANCH}" https://github.com/AymanLyesri/ArchEclipse.git "${CONF_DIR}" || error_exit "Failed to clone repository"

cd "${CONF_DIR}" || error_exit "Failed to change directory to ${CONF_DIR}"

echo "Updating repository to '${BRANCH}' branch..."
git fetch --depth 1 origin "${BRANCH}" && git checkout "${BRANCH}" && git reset --hard FETCH_HEAD || error_exit "Failed to update repository"
echo ""

# Now set paths and source from the cloned repo
MAINTENANCE_DIR="${CONF_DIR}/.config/hypr/maintenance"

# Source essentials FIRST (before presentation, to install core tools early)
source "${MAINTENANCE_DIR}/ESSENTIALS.sh" || error_exit "Failed to source ESSENTIALS.sh"

# Install core tools early (includes lolcat and figlet needed for presentation)
echo "Installing core tools..."
install_core_tools || error_exit "Failed to install core tools"
echo ""

# NOW source presentation (after lolcat is installed)
source "${MAINTENANCE_DIR}/PRESENTATION.sh" || error_exit "Failed to source PRESENTATION.sh"

# Error handler
trap 'error_exit "Error occurred at line $LINENO"' ERR

# Display main header (now lolcat and figlet are available)
print_main_header "INSTALL"

print_section_header "📦 REPOSITORY SETUP"

print_success "Repository cloned and ready\n"

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

run_interactive_step "📋" "Copying configuration files to ${HOME}" "sync_configuration_files"

print_section_header "⌨️ KEYBOARD CONFIGURATION (optional)"

run_interactive_step "🔨" "Setting up keyboard configuration (optional)" "${MAINTENANCE_DIR}/CONFIGURE.sh"

print_section_header "📦 PACKAGE MANAGEMENT"

run_interactive_step "🧹" "Removing unwanted packages" "remove_packages"

run_interactive_step "📥" "Installing necessary packages (using ${BOLD}${aur_helper}${NC})" "${CONF_DIR}/.config/hypr/pacman/install-pkgs.sh ${aur_helper}"

print_section_header "🎨 SYSTEM THEME & APPEARANCE"

run_interactive_step "🖨️" "Setting up SDDM theme" "${MAINTENANCE_DIR}/SDDM.sh"

run_section_step "⚙️" "Applying default configurations" "${MAINTENANCE_DIR}/DEFAULTS.sh"

run_section_step "🖼️" "Setting up wallpapers" "${MAINTENANCE_DIR}/WALLPAPERS.sh"

print_section_header "🔌 PLUGINS & TWEAKS"

run_section_step "🔌" "Installing plugins" "${MAINTENANCE_DIR}/PLUGINS.sh"

run_section_step "✨" "Applying system tweaks" "${MAINTENANCE_DIR}/TWEAKS.sh"

print_section_header "✅ INSTALLATION COMPLETE"

print_install_completion_message
