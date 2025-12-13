# Hyprland 0.51.0 Gestures Compatibility Fix

## Overview

This branch (`hyprland-0.51.0-gestures-fix`) addresses compatibility issues with Hyprland version 0.51.0 where the traditional `workspace_swipe` configuration options were removed in favor of a new gesture bind system.

## Problem

In Hyprland 0.51.0+, the following configuration options were deprecated and removed:
- `workspace_swipe`
- `workspace_swipe_fingers`
- `workspace_swipe_distance`
- `workspace_swipe_invert`
- `workspace_swipe_min_speed_to_force`
- `workspace_swipe_cancel_ratio`
- `workspace_swipe_create_new`
- `workspace_swipe_forever`

Using these options in `general.conf` causes configuration errors.

## Solution

### 1. Updated `configs/general.conf`
- Commented out the deprecated `gestures` section
- Added comprehensive documentation explaining the change
- Preserved original configuration as comments for reference
- Included links to relevant Hyprland documentation

### 2. Updated `configs/keybinds.conf`
- Added new gesture binds using the updated syntax:
  ```
  gesture = 3, horizontal, workspace
  gesture = 3, down, dispatcher, exec, kitty
  gesture = 4, up, dispatcher, fullscreen
  ```

## Benefits

1. **Eliminates Configuration Errors**: No more `config option does not exist` errors
2. **Maintains Functionality**: Gestures continue to work with the new system
3. **Future-Proof**: Uses the official Hyprland 0.51.0+ gesture system
4. **Backward Compatibility**: Clear documentation for users on older versions
5. **Enhanced Flexibility**: New gesture system allows more customization

## Testing

- ✅ Configuration loads without errors (`hyprctl configerrors` returns clean)
- ✅ Hyprland reloads successfully (`hyprctl reload`)
- ✅ Gesture binds are properly registered
- ✅ Maintains existing rice functionality

## References

- [Hyprland PR #11490](https://github.com/hyprwm/Hyprland/pull/11490) - Gesture system rework
- [Hyprland Wiki - Binds](https://wiki.hyprland.org/Configuring/Binds/#gestures)

## Migration Guide

For users upgrading to Hyprland 0.51.0+:

1. Comment out or remove the `gestures` section in `general.conf`
2. Add gesture binds to `keybinds.conf` using the new syntax
3. Test configuration with `hyprctl configerrors`
4. Reload Hyprland with `hyprctl reload`

This fix ensures seamless compatibility with Hyprland 0.51.0 while preserving the gesture functionality users expect.
