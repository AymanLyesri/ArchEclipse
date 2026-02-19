#!/bin/bash

# Authenticate once and keep sudo session alive
sudo -v

# Keep sudo session alive in background
while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null &

hyprpm update

hyprpm add https://github.com/hyprwm/hyprland-plugins
hyprpm add https://github.com/virtcode/hypr-dynamic-cursors

hyprpm enable dynamic-cursors
hyprpm enable hyprexpo

hyprctl reload
