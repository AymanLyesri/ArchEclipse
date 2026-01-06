# Fork Modifications Registry

Este archivo documenta TODOS los archivos modificados en el fork que difieren de upstream.
**IMPORTANTE**: Revisar este archivo antes de cherry-pick de upstream para evitar conflictos.

## Archivos Modificados

### AGS - Configuración

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `constants/app.constants.ts` | `getFileManagerCommand()` helper | File Manager Selector dinámico |
| `constants/settings.constants.ts` | `fileManager: "nautilus"` | Default para selector |
| `interfaces/settings.interface.ts` | `fileManager: string` | Tipo para selector |
| `scripts/search-booru.py` | Null safety en r.json() | Fix crashes cuando API falla |

### AGS - Widgets

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `widgets/leftPanel/components/SettingsWidget.tsx` | `FileManagerSelector` component | Selector de file manager en Settings |
| `widgets/rightPanel/components/Notification.tsx` | Null check antes de .endsWith() | Fix crash con notificaciones sin icono |
| `widgets/Picture.tsx` | `null` en vez de `undefined` | GTK no acepta undefined para file |
| `classes/BooruImage.tsx` | Array.isArray() check | Fix readJson null |
| `widgets/leftPanel/components/BooruViewer.tsx` | Array.isArray() check | Fix readJson null |
| `widgets/Player.tsx` | coverArt fallback | Fix null coverArt |

### Hyprland - Scripts (Únicos del fork)

| Archivo | Descripción |
|---------|-------------|
| `scripts/monitor-hotplug.sh` | Detección automática de monitores |
| `scripts/lid-handler.sh` | Manejo de tapa del laptop |
| `scripts/multi-monitor-manager.sh` | Gestión central de monitores |
| `scripts/workspace-state-manager.sh` | Preservación de estado (KVM) |
| `scripts/start-clipboard-monitor.sh` | Lanzador singleton clipboard |
| `scripts/clipboard-monitor.sh` | Notificaciones de clipboard |
| `scripts/check-clipboard-monitor.sh` | Diagnóstico de clipboard |

### Hyprland - Configs

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `configs/exec.conf` | LD_PRELOAD para AGS | Fix gtk4-layer-shell |
| `configs/multi-monitor-keybinds.conf` | Keybinds para monitores | Único del fork |

### Documentación (Única del fork)

- `CLAUDE.md`
- `docs/*.md`
- `.claude/*`

## Commits de Upstream Incorporados (2026-01-05)

| Commit | Descripción | Notas |
|--------|-------------|-------|
| `7bcbdb00` | Animation keyframes | Sin conflictos |
| `1c8f1fb7` | Monitor name retrieval | **Ayman incorporó nuestro fix de get_connector()!** |
| `d304fd97` | Notification handling | Corregimos bug de null check |

## Procedimiento de Cherry-Pick Seguro

```bash
# 1. Fetch upstream
git fetch upstream

# 2. Ver commits nuevos
git log --oneline HEAD..upstream/master

# 3. Para CADA commit que quieras:
git show <hash> --stat

# 4. Verificar si toca archivos de esta lista
#    Si SÍ toca → revisar manualmente el diff
#    Si NO toca → cherry-pick seguro

# 5. Cherry-pick
git cherry-pick <hash>

# 6. Si hay conflicto en archivo de esta lista:
#    - Resolver manualmente preservando TUS cambios
#    - git add <archivo>
#    - git cherry-pick --continue
```

## PRs Enviados a Upstream

| PR | Título | Estado |
|----|--------|--------|
| #193 | fix(ags): use get_connector() for reliable multi-monitor support | ✅ Merged |
| #195 | feat(settings): add file manager selector with auto-detection | ⏳ Pending |

## Última actualización

- Fecha: 2026-01-05
- Último commit de upstream revisado: `d304fd97`
