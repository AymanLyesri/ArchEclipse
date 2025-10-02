#!/bin/bash

hyprDir=$HOME/.config/hypr
current_theme=$(bash $hyprDir/theme/scripts/system-theme.sh get)

hyprctl setcursor theme_phinger-cursors-$current_theme 24
gsettings set org.gnome.desktop.interface cursor-theme phinger-cursors-$current_theme

echo -e "env = HYPRCURSOR_THEME,theme_phinger-cursors-$current_theme \nenv = XCURSOR_THEME,phinger-cursors-$current_theme" >$HOME/.config/hypr/configs/cursor.conf
