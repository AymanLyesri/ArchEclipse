#!/bin/bash

echo -e "\e[3m ArchEclipse \e[0m" | lolcat
figlet "PLUGINS" -f slant | lolcat

sudo -v

hyprpm update

hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm add https://github.com/virtcode/hypr-dynamic-cursors

hyprpm enable dynamic-cursors
hyprpm enable hyprexpo

hyprctl reload
