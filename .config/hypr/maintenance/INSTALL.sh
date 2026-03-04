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

export FZF_HEIGHT="40%"

# Error handler
trap 'echo "Error occurred at line $LINENO"; exit 1' ERR

# Prompt for sudo password once at the start
sudo -v

# Specify the repo branch
BRANCH="${1:-master}"

# Clone or update repository
if [ -d "${CONF_DIR}" ]; then
    echo "${CONF_DIR} directory exists."
else
    echo "${CONF_DIR} directory does not exist. Cloning the repository..."
    git clone https://github.com/AymanLyesri/ArchEclipse.git "${CONF_DIR}"
fi

# Change branch to the specified branch
cd "${CONF_DIR}" || exit 1
git checkout "${BRANCH}"
git fetch origin "${BRANCH}"
git reset --hard "origin/${BRANCH}"

# Source essentials from absolute path
source "${MAINTENANCE_DIR}/ESSENTIALS.sh"

install_core_tools

figlet "INSTALL" -f slant | lolcat

# Choose Pacman Wrapper
echo "Choose an AUR helper to install packages:"
aur_helpers=("yay" "paru")
aur_helper=$(printf '%s\n' "${aur_helpers[@]}" | fzf --height "${FZF_HEIGHT}") || {
    echo "No AUR helper selected. Exiting."
    exit 1
}
echo "AUR helper selected: ${aur_helper}"

case "${aur_helper}" in
    yay)
        install_yay
        ;;
    paru)
        install_paru
        ;;
    *)
        echo "Invalid AUR helper selected"
        exit 1
        ;;
esac

continue_prompt "Backing up dotfiles from .config ..." "${MAINTENANCE_DIR}/BACKUP.sh"

continue_prompt "Copying configuration files to ${HOME}..." "sudo cp -a . ${HOME}"

continue_prompt "keyboard configuration" "${MAINTENANCE_DIR}/CONFIGURE.sh"

continue_prompt "Do you want to remove unwanted packages?" remove_packages

continue_prompt "Do you want to install necessary packages? (using ${aur_helper})" "${HOME}/.config/hypr/pacman/install-pkgs.sh ${aur_helper}"

continue_prompt "Sddm theme setup" "${MAINTENANCE_DIR}/SDDM.sh"

"${MAINTENANCE_DIR}/DEFAULTS.sh"

"${MAINTENANCE_DIR}/WALLPAPERS.sh"

"${MAINTENANCE_DIR}/PLUGINS.sh"

"${MAINTENANCE_DIR}/TWEAKS.sh"

echo "Installation complete. Please Reboot the system."
