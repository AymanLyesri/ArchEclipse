#!/bin/bash

# Monitor Setup Script - Simplified interface for common monitor operations
# Part of the ArchEclipse Multi-Monitor Support

SCRIPT_DIR="$(dirname "$0")"
MULTI_MONITOR_SCRIPT="$SCRIPT_DIR/multi-monitor-manager.sh"

# Quick setup for common scenarios
case "${1:-}" in
    "laptop-only")
        echo "Setting up laptop-only configuration..."
        hyprctl keyword monitor "eDP-1,preferred,0x0,1"
        hyprctl keyword monitor "HDMI-A-1,disable"
        ;;
    "external-only")
        echo "Setting up external monitor only..."
        hyprctl keyword monitor "HDMI-A-1,preferred,0x0,1"
        hyprctl keyword monitor "eDP-1,disable"
        ;;
    "dual-extend")
        echo "Setting up dual monitor extended..."
        hyprctl keyword monitor "eDP-1,1920x1200@60,0x0,1"
        hyprctl keyword monitor "HDMI-A-1,3840x2160@60,1920x0,1"
        ;;
    "dual-mirror")
        echo "Setting up dual monitor mirrored..."
        hyprctl keyword monitor "HDMI-A-1,1920x1200@60,0x0,1,mirror,eDP-1"
        ;;
    "auto")
        echo "Auto-configuring monitors..."
        "$MULTI_MONITOR_SCRIPT" auto
        ;;
    *)
        echo "Monitor Setup Options:"
        echo "  laptop-only  - Use only laptop screen"
        echo "  external-only - Use only external monitor"
        echo "  dual-extend  - Extend desktop across both monitors"
        echo "  dual-mirror  - Mirror laptop screen to external"
        echo "  auto         - Auto-detect and configure"
        ;;
esac
