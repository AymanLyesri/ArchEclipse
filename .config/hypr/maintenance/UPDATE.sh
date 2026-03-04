#!/bin/bash
set -euo pipefail

################################################################
# User Confirmation
################################################################

echo ""
read -p "$(echo -e '\033[1;33m⚠️  You will begin the update process. Do you want to proceed? \033[0m(y/n) ')" -n 1 -r
echo    # Move to a new line

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\033[0;33m✗ Action cancelled.\033[0m"
    exit 0
fi

sudo -v

################################################################
# Counter for Updates
################################################################

curl -s -o /dev/null "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=update" || true

################################################################
# Hyprland ArchEclipse Update Script
################################################################

MAINTENANCE_DIR="$HOME/.config/hypr/maintenance"

# Source display functions
source "${MAINTENANCE_DIR}/PRESENTATION.sh"

# Error handler
trap 'error_exit "Error occurred at line $LINENO"' ERR

# Display main header
print_main_header "UPDATE"

# Source essentials from absolute path
run_step "⬇️" "Loading essential functions" "source ${MAINTENANCE_DIR}/ESSENTIALS.sh"
run_step "⚙️" "Installing core tools" "install_core_tools"

# Specify the repo branch
BRANCH="${1:-master}"

print_section_header "📦 REPOSITORY UPDATE"

run_step "[1/3]" "Updating repository to '${BRANCH}' branch (latest commit only)" "git checkout ${BRANCH} && git fetch --depth 1 origin ${BRANCH} && git reset --hard FETCH_HEAD"

print_section_header "🧹 PACKAGE MANAGER CLEANUP"

print_step "[2/3]" "Cleaning up hanging package manager processes..."

# List of possible package managers
procs=("pacman" "yay" "paru")

cleaned=0
for proc in "${procs[@]}"; do
    if pgrep -x "$proc" >/dev/null; then
        echo -e "  ${YELLOW}Killing${NC} $proc..."
        sudo killall -9 "$proc" 2>/dev/null || true
        ((cleaned++))
    fi
done

if [ $cleaned -eq 0 ]; then
    print_warning "No running package manager processes found"
else
    print_success "Killed $cleaned process(es)"
fi

# Remove pacman lock file if it exists
if [ -f /var/lib/pacman/db.lck ]; then
    echo -e "  ${YELLOW}Removing${NC} pacman lock file..."
    sudo rm -f /var/lib/pacman/db.lck
    print_success "Pacman lock file removed"
fi

echo ""
print_step "[3/3]" "Detecting AUR helper..."

aur_helpers=("yay" "paru")

for helper in "${aur_helpers[@]}"; do
    if command -v "$helper" &>/dev/null; then
        aur_helper="$helper"
        break
    fi
done

if [[ -z "$aur_helper" ]]; then
    print_warning "No AUR helper (yay or paru) is installed."
else
    print_success "AUR helper found: ${BOLD}${MAGENTA}${aur_helper}${NC}\n"
fi

print_section_header "📥 PACKAGE UPDATES"

if [[ ! -z "$aur_helper" ]]; then
    run_interactive_step "📦" "Updating necessary packages (using ${BOLD}${aur_helper}${NC})" "$HOME/.config/hypr/pacman/install-pkgs.sh $aur_helper"
fi

print_section_header "🔌 PLUGINS & TWEAKS"

run_section_step "🔌" "Installing plugins" "${MAINTENANCE_DIR}/PLUGINS.sh"

print_section_header "✅ UPDATE COMPLETE"

print_update_completion_message
