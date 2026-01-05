# AGS Widgets Migration Status (Upstream)

This document tracks widgets and elements from upstream (AymanLyesri) that are commented out, disabled, or pending migration to GTK4/AGS 3.0.

Last updated: 2026-01-04

## Widgets Completely Commented (in `app.ts`)

| Widget | File | Status | Notes |
|--------|------|--------|-------|
| **Progress** | `widgets/Progress.tsx` | Comentado | Loading indicator widget |
| **MediaPopups** | N/A | Eliminado | File deleted, import commented |
| **SettingsWidget** | `widgets/SettingsWidget.tsx` | Comentado | Settings panel |
| **OSD** | `widgets/OSD.tsx` | Comentado | On-Screen Display (volume, brightness) |
| **ScreenShot** | `widgets/ScreenShot.tsx` | 100% Comentado | Screenshot preview widget - entire file is commented |

## Widgets with Internal Issues

| Widget | File | Issue | Priority |
|--------|------|-------|----------|
| **Brightness** | `widgets/bar/components/Utilities.tsx` | Screen flickers when adjusting, brightness not applied correctly | Alta |
| **Keyboard Brightness** | `widgets/bar/components/Utilities.tsx` | Keyboard brightness keys not working | Alta |
| **FileChooser** | `widgets/FileChooser.tsx` | File deleted but still imported in UserPanel.tsx | Alta |
| **WallpaperSwitcher** | `widgets/WallpaperSwitcher.tsx` | FileChooserDialog section commented (~30 lines) | Media |
| **ImageDialog** | `widgets/leftPanel/components/ImageDialog.tsx` | `openProgress()` commented | Baja |
| **UserPanel** | `widgets/UserPanel.tsx` | Section marked as "WIP" | Baja |

## Settings Disabled by Default

```typescript
// In constants/settings.constants.ts
rightPanel: {
  visibility: false,  // Right panel hidden by default
},
chatBot: {
  visibility: false,  // ChatBot hidden by default
}
```

## Broken Imports/References

| Missing File | Referenced In | Impact |
|--------------|---------------|--------|
| `FileChooser.tsx` | `UserPanel.tsx` line 16 | Import will fail |
| `MediaPopups.tsx` | `app.ts` line 56 | Commented, no impact |

## Migration Priority

**High Priority (broken functionality):**
1. Brightness widget - flickering and keys not working
2. FileChooser - broken import in UserPanel

**Medium Priority (disabled widgets):**
3. ScreenShot - completely commented
4. OSD - commented
5. SettingsWidget - commented

**Low Priority (minor issues):**
6. WallpaperSwitcher - FileChooser section
7. Progress - loading bars commented
8. UserPanel WIP section
9. MangaViewer - needs architectural improvements (see below)

## File Manager Selector TODO

Add a self-service file manager selector in Settings panel:

**Requirements:**
1. Add dropdown in Settings to choose file manager (Nautilus, Dolphin, Thunar, Nemo, PCManFM)
2. Auto-detect installed file managers
3. Option to install missing file manager (via pacman/yay)
4. Update `app.constants.ts` and `CustomScripts.tsx` dynamically
5. Store preference in settings.json

**Files to modify:**
- `constants/app.constants.ts` - make file manager configurable
- `widgets/leftPanel/components/SettingsWidget.tsx` - add selector UI
- `widgets/leftPanel/components/CustomScripts.tsx` - use configured file manager

## MangaViewer TODO

The MangaViewer widget needs significant improvements:

**Current Issues:**
- Downloads all pages locally (consumes disk space and memory)
- No cache size limit or automatic cleanup
- Can cause system freeze due to memory consumption
- Multiple concurrent downloads without proper throttling

**Proposed Improvements:**
1. Stream images directly instead of downloading to disk
2. Implement LRU cache with configurable size limit
3. Add automatic cleanup of old cached pages
4. Lazy load with virtualized list (only render visible pages)
5. Add download progress indicator
6. Consider using a dedicated manga reader app integration instead

## Notes

- All widgets need GTK4 compatibility review
- Some widgets may depend on deprecated AGS 2.x APIs
