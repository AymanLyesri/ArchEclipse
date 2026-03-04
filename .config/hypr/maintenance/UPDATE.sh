#!/bin/bash
set -euo pipefail

################################################################
# User Confirmation
################################################################

echo ""
read -p "$(echo -e '\033[1;33m⚠️  You will begin the update process. Do you want to proceed? \033[0m(y/n) ')" -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\033[0;33m✗ Action cancelled.\033[0m"
    exit 0
fi

sudo -v

################################################################
# Counter (Non-blocking)
################################################################

curl -s -o /dev/null \
"https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=update" \
|| true

################################################################
# Repository Configuration
################################################################

REPO_DIR="$HOME/ArchEclipse"
REPO_URL="https://github.com/AymanLyesri/ArchEclipse.git"
BRANCH="${1:-master}"

################################################################
# Clone or Update Repository (Latest Commit Only)
################################################################

echo ""
echo "📦 Updating repository..."

if [[ ! -d "${REPO_DIR}/.git" ]]; then
    echo "Cloning latest commit..."
    git clone \
        --depth 1 \
        --single-branch \
        --branch "${BRANCH}" \
        "${REPO_URL}" \
        "${REPO_DIR}"
else
    echo "Fetching latest commit..."
    git -C "${REPO_DIR}" fetch --depth 1 origin "${BRANCH}"

    echo "Fast-forwarding..."
    git -C "${REPO_DIR}" merge --ff-only "origin/${BRANCH}" || {
        echo "Non fast-forward state detected. Resetting to remote..."
        git -C "${REPO_DIR}" reset --hard "origin/${BRANCH}"
    }
fi

echo "Repository ready."

################################################################
# Enter Repository & Load Presentation
################################################################

cd "${REPO_DIR}"

MAINTENANCE_DIR="$REPO_DIR/.config/hypr/maintenance"

source "${MAINTENANCE_DIR}/PRESENTATION.sh"

################################################################
# Error Handling
################################################################

trap 'error_exit "Error occurred at line $LINENO"' ERR

print_main_header "UPDATE"

################################################################
# Load Essentials
################################################################

run_step "⬇️" "Loading essential functions" \
"source ${MAINTENANCE_DIR}/ESSENTIALS.sh"

run_step "⚙️" "Installing core tools" \
"install_core_tools"

################################################################
# Package Manager Cleanup
################################################################

print_section_header "🧹 PACKAGE MANAGER CLEANUP"

print_step "[1/3]" "Cleaning hanging package manager processes..."

procs=("pacman" "yay" "paru")
cleaned=0

for proc in "${procs[@]}"; do
    if pgrep -x "$proc" >/dev/null; then
        echo "Killing $proc..."
        sudo killall -9 "$proc" 2>/dev/null || true
        ((cleaned++))
    fi
done

if [[ $cleaned -eq 0 ]]; then
    print_warning "No running package manager processes found"
else
    print_success "Killed $cleaned process(es)"
fi

if [[ -f /var/lib/pacman/db.lck ]]; then
    print_step "[2/3]" "Removing pacman lock file..."
    sudo rm -f /var/lib/pacman/db.lck
    print_success "Pacman lock file removed"
fi

################################################################
# Detect AUR Helper
################################################################

print_step "[3/3]" "Detecting AUR helper..."

aur_helper=""
for helper in yay paru; do
    if command -v "$helper" &>/dev/null; then
        aur_helper="$helper"
        break
    fi
done

if [[ -z "$aur_helper" ]]; then
    print_warning "No AUR helper (yay or paru) installed."
else
    print_success "AUR helper detected: $aur_helper"
fi

################################################################
# Package Updates
################################################################

print_section_header "📥 PACKAGE UPDATES"

if [[ -n "$aur_helper" ]]; then
    run_interactive_step "📦" \
    "Updating necessary packages (using $aur_helper)" \
    "$REPO_DIR/.config/hypr/pacman/install-pkgs.sh $aur_helper"
fi

################################################################
# Plugins & Tweaks
################################################################

print_section_header "🔌 PLUGINS & TWEAKS"

run_section_step "🔌" \
"Installing plugins" \
"${MAINTENANCE_DIR}/PLUGINS.sh"

################################################################
# Done
################################################################

print_section_header "✅ UPDATE COMPLETE"
print_update_completion_message
