# AGS Widgets Migration Status (Upstream)

This document tracks widgets and elements from upstream (AymanLyesri) that are commented out, disabled, or pending migration to GTK4/AGS 3.0.

Last updated: 2026-01-05

## Recent Sync with Upstream (2026-01-05)

Cherry-picked 3 commits from Ayman:
- `7bcbdb00` - feat: add animation keyframes
- `1c8f1fb7` - refactor: simplify monitor name retrieval (includes our get_connector fix!)
- `d304fd97` - refactor: streamline notification handling (fixed null check bug)

## Widgets Completely Commented (in `app.tsx`)

| Widget | File | Status | Notes |
|--------|------|--------|-------|
| **Progress** | `widgets/Progress.tsx` | Comentado | Loading indicator widget |
| **MediaPopups** | N/A | Eliminado | File deleted, import commented |
| **OSD** | `widgets/OSD.tsx` | Comentado | On-Screen Display (volume, brightness) |
| **ScreenShot** | `widgets/ScreenShot.tsx` | 100% Comentado | Screenshot preview widget |

## Widgets Status

| Widget | File | Status |
|--------|------|--------|
| ~~**Brightness**~~ | `Utilities.tsx` | ✅ Funciona correctamente |
| ~~**Keyboard Brightness**~~ | `Utilities.tsx` | ✅ Funciona correctamente |
| ~~**WallpaperSwitcher**~~ | `WallpaperSwitcher.tsx` | ✅ Funciona (Gtk.FileDialog) |
| ~~**File Manager Selector**~~ | `SettingsWidget.tsx` | ✅ **Implementado 2026-01-05** (PR #195) |
| **ImageDialog** | `ImageDialog.tsx` | `openProgress()` comentado - Baja prioridad |
| **UserPanel** | `UserPanel.tsx` | Sección WIP - Baja prioridad |

## ~~File Manager Selector~~ ✅ COMPLETADO

Implementado el 2026-01-05 (PR #195 pendiente de merge):

**Features implementadas:**
- ✅ Auto-detecta file managers instalados (nautilus, thunar, dolphin, nemo, pcmanfm, ranger)
- ✅ Selector con togglebuttons en Settings > Custom
- ✅ Persiste selección en settings.json
- ✅ Actualiza Files quick app dinámicamente

**Archivos modificados:**
- `settings.interface.ts` - Added `fileManager: string`
- `settings.constants.ts` - Default: `"nautilus"`
- `SettingsWidget.tsx` - `FileManagerSelector` component
- `app.constants.ts` - `getFileManagerCommand()` helper

## MangaViewer TODO

**Current Issues:**
- Downloads all pages locally (consumes disk space and memory)
- No cache size limit or automatic cleanup
- Can cause system freeze due to memory consumption

**Proposed Improvements:**
1. Stream images directly instead of downloading to disk
2. Implement LRU cache with configurable size limit
3. Add automatic cleanup of old cached pages
4. Lazy load with virtualized list (only render visible pages)

## Migration Priority

**High Priority:**
- ~~FileChooser import~~ - Verificar si aún aplica después del refactor de Ayman

**Medium Priority (disabled widgets):**
- ScreenShot - completely commented
- OSD - commented

**Low Priority:**
- Progress - loading bars commented
- UserPanel WIP section
- MangaViewer improvements

## Notes

- Ayman incorporó nuestro fix de `get_connector()` en `utils/monitor.ts` (commit 1c8f1fb7)
- El refactor de Notification.tsx tenía un bug de null check que corregimos
- All widgets now use simplified `getMonitorName(monitor)` function
