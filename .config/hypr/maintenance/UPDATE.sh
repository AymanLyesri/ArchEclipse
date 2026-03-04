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

REPO_URL="https://github.com/AymanLyesri/ArchEclipse.git"
BRANCH="${1:-master}"

# Temporary clone directory (always fresh)
TEMP_DIR="$(mktemp -d)"

################################################################
# Clone Latest Commit Only
################################################################

echo ""
echo "📦 Cloning latest repository state..."

git clone \
    --depth 1 \
    --single-branch \
    --branch "${BRANCH}" \
    "${REPO_URL}" \
    "${TEMP_DIR}"

################################################################
# Enter Cloned Repo
################################################################

cd "${TEMP_DIR}"

MAINTENANCE_DIR="${TEMP_DIR}/.config/hypr/maintenance"

source "${MAINTENANCE_DIR}/PRESENTATION.sh"

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
# Overwrite Home Config (Like Forced Git Pull)
################################################################

print_section_header "📂 DEPLOYING CONFIG FILES"

print_step "[1/1]" "Overwriting home configuration..."

# Remove .git to avoid copying it
rm -rf "${TEMP_DIR}/.git"

# Force copy everything to $HOME
cp -af "${TEMP_DIR}/." "$HOME/"

print_success "Configuration successfully updated."

################################################################
# Package Manager Cleanup
################################################################

print_section_header "🧹 PACKAGE MANAGER CLEANUP"

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
    sudo rm -f /var/lib/pacman/db.lck
    print_success "Pacman lock file removed"
fi

################################################################
# Detect AUR Helper
################################################################

print_section_header "📥 PACKAGE UPDATES"

aur_helper=""
for helper in yay paru; do
    if command -v "$helper" &>/dev/null; then
        aur_helper="$helper"
        break
    fi
done

if [[ -n "$aur_helper" ]]; then
    run_interactive_step "📦" \
    "Updating necessary packages (using $aur_helper)" \
    "$HOME/.config/hypr/pacman/install-pkgs.sh $aur_helper"
else
    print_warning "No AUR helper installed."
fi

################################################################
# Plugins
################################################################

print_section_header "🔌 PLUGINS & TWEAKS"

run_section_step "🔌" \
"Installing plugins" \
"$HOME/.config/hypr/maintenance/PLUGINS.sh"

################################################################
# Cleanup Temporary Clone
################################################################

rm -rf "${TEMP_DIR}"

print_section_header "✅ UPDATE COMPLETE"
print_update_completion_message
