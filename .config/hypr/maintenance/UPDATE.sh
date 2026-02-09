#!/bin/bash

################################################################
# User confirmation
################################################################

read -p "You will begin the update process. Do you want to proceed? (y/n) " -n 1 -r
echo    # Move to a new line
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Action cancelled."
    exit 0
fi

################################################################
# Counter for Updates
################################################################

curl -s -o /dev/null "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=update"

################################################################
# Hyprland ArchEclipse Update Script
################################################################

MAINTENANCE_DIR="$HOME/.config/hypr/maintenance"

figlet "Updating Config"

source $HOME/.config/hypr/maintenance/ESSENTIALS.sh # source the essentials file INSIDE the repository

# specify the repo branch
if [ -z "$1" ]; then
    BRANCH="master"
else
    BRANCH=$1
fi

git checkout $BRANCH
git fetch origin $BRANCH
git reset --hard origin/$BRANCH

# Kill any hanging pacman/AUR helper processes and clean lock file
echo "Cleaning up any hanging package manager processes..."

# List of possible package managers
procs=("pacman" "yay" "paru")

for proc in "${procs[@]}"; do
    if pgrep -x "$proc" >/dev/null; then
        echo "Killing $proc..."
        sudo killall -9 "$proc" 2>/dev/null || true
    fi
done

figlet "Updating Packages"

# Remove pacman lock file if it exists
if [ -f /var/lib/pacman/db.lck ]; then
    echo "Removing pacman lock file..."
    sudo rm -f /var/lib/pacman/db.lck
fi
aur_helpers=("yay" "paru")

for helper in "${aur_helpers[@]}"; do
    if command -v "$helper" &>/dev/null; then
        aur_helper="$helper"
        break
    fi
done

if [[ -z "$aur_helper" ]]; then
    echo "No AUR helper (yay or paru) is installed."
else
    continue_prompt "Do you want to update necessary packages? (using $aur_helper)" "$HOME/.config/hypr/pacman/install-pkgs.sh $aur_helper"
fi

# $MAINTENANCE_DIR/AGSV1.sh
# if pacman -Q agsv1 &>/dev/null; then
#     yay -Rns agsv1 --noconfirm
# fi

# $MAINTENANCE_DIR/WAL.sh

figlet "Updating Plugins"

$MAINTENANCE_DIR/PLUGINS.sh

# $MAINTENANCE_DIR/TWEAKS.sh
