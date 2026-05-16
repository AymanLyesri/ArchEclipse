#!/bin/bash

echo -e "\e[3m ArchEclipse \e[0m" | lolcat
figlet "PLUGINS" -f slant | lolcat

PLUGINS=(
    "hyprland-plugins|https://github.com/hyprwm/hyprland-plugins"
    "dynamic-cursors|https://github.com/virtcode/hypr-dynamic-cursors"
    # "Hyprspace|https://github.com/KZDKM/Hyprspace"
)

for plugin_data in "${PLUGINS[@]}"; do
    IFS='|' read -r plugin repo <<< "$plugin_data"

    if hyprpm list | grep -q "$plugin"; then
        echo "$plugin already installed"
        continue
    fi

    hyprpm add "$repo"
    hyprpm enable "$plugin"
done

hyprpm update

hyprctl reload