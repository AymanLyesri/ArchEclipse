#!/bin/bash
set -euo pipefail

################################################################
# User Confirmation
################################################################

echo ""
read -p "$(echo -e '\033[1;33m⚠️  You will begin the update process. Do you want to proceed? \033[0m(Y/n) ')" -n 1 -r
echo

if [[ -z "${REPLY}" ]]; then
    REPLY="y"
fi

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
REPO_DIR="$HOME"
MAINTENANCE_DIR="$HOME/.config/hypr/maintenance"

TEMP_DIR=""

cleanup_temp_files() {
    [[ -n "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}"
}

trap cleanup_temp_files EXIT

is_repo_intact() {
    [[ -d "${REPO_DIR}/.git" ]] || return 1
    git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
    
    local origin_url
    origin_url="$(git -C "${REPO_DIR}" remote get-url origin 2>/dev/null || true)"
    [[ "${origin_url}" == "${REPO_URL}" ]] || return 1
    
    git -C "${REPO_DIR}" rev-parse --verify HEAD >/dev/null 2>&1 || return 1
    
    # Check for corrupted objects
    git -C "${REPO_DIR}" fsck --no-progress >/dev/null 2>&1 || return 1
    
    return 0
}

echo ""
echo "============================================================"
echo "🔄 UPDATE"
echo "============================================================"

################################################################
# Overwrite Home Config (Like Forced Git Pull)
################################################################

echo "📂 DEPLOYING CONFIG FILES"

if is_repo_intact; then
    echo "🌿 Repository history intact, syncing with remote..."
    cd "${REPO_DIR}"
    git checkout "${BRANCH}"
    git fetch origin "${BRANCH}"
    git reset --hard "origin/${BRANCH}"
    echo "✓ Repository successfully updated from origin/${BRANCH}."
else
    echo "⚠️ Local git history is missing/corrupt. Falling back to fresh clone deployment."
    
    TEMP_DIR="$(mktemp -d)"
    
    echo "📦 Cloning latest repository state..."
    git clone --depth 1 --single-branch --branch "${BRANCH}" "${REPO_URL}" "${TEMP_DIR}"
    
    echo "[1/1] Overwriting home configuration..."
    
    rm -rf "${REPO_DIR}/.git"
    
    # Force copy everything to $HOME
    # --remove-destination avoids failures on dangling symlinks (e.g. ~/.zshrc)
    cp -a --remove-destination "${TEMP_DIR}/." "$HOME/"
    
    echo "✓ Configuration successfully updated from fresh clone."
fi

################################################################
# Load Local Helpers (After Repo Update Logic)
################################################################

if [[ ! -f "${MAINTENANCE_DIR}/PRESENTATION.sh" || ! -f "${MAINTENANCE_DIR}/ESSENTIALS.sh" ]]; then
    echo "✗ Required local maintenance scripts not found in ${MAINTENANCE_DIR}."
    exit 1
fi

source "${MAINTENANCE_DIR}/PRESENTATION.sh"
source "${MAINTENANCE_DIR}/ESSENTIALS.sh"

print_main_header "UPDATE"

run_step "⚙️" "Installing core tools" \
"install_core_tools"

################################################################
# Reload Bar
################################################################

print_section_header "🔄 RELOADING BAR"

run_step "🔄" "Reloading bar configuration" \
"$HOME/.config/hypr/scripts/bar.sh &"

# countdown to allow bar to reload before showing completion message
# for i in {5..1}; do
#     echo $i...
#     sleep 1
# done

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
    "$HOME/.config/hypr/pacman/install-pkgs.sh $aur_helper" \
    "y"
else
    print_warning "No AUR helper installed."
fi

################################################################
# Plugins
################################################################

print_section_header "🔌 PLUGINS"

run_interactive_step "🔌" \
"Updating plugins" \
"$HOME/.config/hypr/maintenance/PLUGINS.sh" \
"y"

################################################################
# Completion
################################################################

print_section_header "✅ UPDATE COMPLETE"
print_update_completion_message
