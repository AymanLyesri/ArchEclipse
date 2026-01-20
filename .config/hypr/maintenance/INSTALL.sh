#!/bin/bash

################################################################
# Counter for Installations
################################################################

curl -s -o /dev/null "https://personal-counter-two.vercel.app/api/increment?workspace=archeclipse&counter=install"

################################################################
# Hyprland ArchEclipse Installation Script
################################################################

export FZF_HEIGHT="40%"
MAINTENANCE_DIR=".config/hypr/maintenance"
CONF_DIR="ArchEclipse"

# specify the repo branch
if [ -z "$1" ]; then
    BRANCH="master"
else
    BRANCH=$1
fi

if [ -d "$CONF_DIR" ]; then
    echo "$CONF_DIR directory exists."
else
    echo "$CONF_DIR directory does not exist. Cloning the repository..."
    git clone https://github.com/AymanLyesri/ArchEclipse.git --depth 1
fi

# Change branch to the specified branch
cd $CONF_DIR
git checkout $BRANCH
git fetch origin $BRANCH
git reset --hard origin/$BRANCH

source $MAINTENANCE_DIR/ESSENTIALS.sh # source the essentials file INSIDE the repository

install_git

install_fzf

install_figlet

# choose Pacman Wrapper
echo "Choose an AUR helper to install packages:"
aur_helpers=("yay" "paru")
aur_helper=$(echo "${aur_helpers[@]}" | tr ' ' '\n' | fzf --height $FZF_HEIGHT)
echo "AUR helper selected: $aur_helper"
case $aur_helper in
    yay)
        install_yay
    ;;
    paru)
        install_paru
    ;;
esac

continue_prompt "Backing up dotfiles from .config ..." "$MAINTENANCE_DIR/BACKUP.sh"

continue_prompt "Copying configuration files to $HOME..." "sudo cp -a . $HOME"

continue_prompt "keyboard configuration" "$MAINTENANCE_DIR/CONFIGURE.sh"

continue_prompt "Do you want to remove unwanted packages?" remove_packages

continue_prompt "Do you want to install necessary packages? (using $aur_helper)" "$HOME/.config/hypr/pacman/install-pkgs.sh $aur_helper"

install_browser

install_discord_client

continue_prompt "Sddm theme setup" "$MAINTENANCE_DIR/SDDM.sh"

continue_prompt "Do you want to add the en_US locale?" "$MAINTENANCE_DIR/LOCALES.sh"

$MAINTENANCE_DIR/DEFAULTS.sh

$MAINTENANCE_DIR/WALLPAPERS.sh

$MAINTENANCE_DIR/WAL.sh

$MAINTENANCE_DIR/PLUGINS.sh

$MAINTENANCE_DIR/TWEAKS.sh

echo "Installation complete. Please Reboot the system."
