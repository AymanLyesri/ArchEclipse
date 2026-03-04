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
REPO_DIR="$HOME"
REMOTE_MAINTENANCE_BASE="https://raw.githubusercontent.com/AymanLyesri/hyprland-conf/refs/heads/master/.config/hypr/maintenance"

TEMP_DIR=""
REMOTE_PRESENTATION_FILE="$(mktemp)"
REMOTE_ESSENTIALS_FILE="$(mktemp)"

cleanup_temp_files() {
    [[ -n "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}"
    [[ -f "${REMOTE_PRESENTATION_FILE}" ]] && rm -f "${REMOTE_PRESENTATION_FILE}"
    [[ -f "${REMOTE_ESSENTIALS_FILE}" ]] && rm -f "${REMOTE_ESSENTIALS_FILE}"
}

trap cleanup_temp_files EXIT

is_repo_intact() {
    [[ -d "${REPO_DIR}/.git" ]] || return 1
    git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1

    local origin_url
    origin_url="$(git -C "${REPO_DIR}" remote get-url origin 2>/dev/null || true)"
    [[ "${origin_url}" == "${REPO_URL}" ]] || return 1

    git -C "${REPO_DIR}" rev-parse --verify HEAD >/dev/null 2>&1 || return 1

    return 0
}

################################################################
# Load UI Helpers
################################################################

curl -fsSL "${REMOTE_MAINTENANCE_BASE}/PRESENTATION.sh" -o "${REMOTE_PRESENTATION_FILE}"
source "${REMOTE_PRESENTATION_FILE}"

trap 'error_exit "Error occurred at line $LINENO"' ERR

print_main_header "UPDATE"

################################################################
# Load Essentials
################################################################

run_step "⬇️" "Fetching remote essential functions" \
"curl -fsSL ${REMOTE_MAINTENANCE_BASE}/ESSENTIALS.sh -o ${REMOTE_ESSENTIALS_FILE}"

source "${REMOTE_ESSENTIALS_FILE}"

run_step "⚙️" "Installing core tools" \
"install_core_tools"

################################################################
# Overwrite Home Config (Like Forced Git Pull)
################################################################

print_section_header "📂 DEPLOYING CONFIG FILES"

if is_repo_intact; then
    run_step "🌿" "Repository history intact, syncing with remote" \
    "cd ${REPO_DIR} && git checkout ${BRANCH} && git fetch origin ${BRANCH} && git reset --hard origin/${BRANCH}"
    print_success "Repository successfully updated from origin/${BRANCH}."
else
    print_warning "Local git history is missing/corrupt. Falling back to fresh clone deployment."

    TEMP_DIR="$(mktemp -d)"

    run_step "📦" "Cloning latest repository state" \
    "git clone --depth 1 --single-branch --branch ${BRANCH} ${REPO_URL} ${TEMP_DIR}"

    print_step "[1/1]" "Overwriting home configuration..."

    rm -rf "${REPO_DIR}/.git"

    # Force copy everything to $HOME
    # --remove-destination avoids failures on dangling symlinks (e.g. ~/.zshrc)
    cp -a --remove-destination "${TEMP_DIR}/." "$HOME/"

    print_success "Configuration successfully updated from fresh clone."
fi

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
# Completion
################################################################

print_section_header "✅ UPDATE COMPLETE"
print_update_completion_message
