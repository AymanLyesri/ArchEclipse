# Fork Modifications Registry

Este archivo documenta TODOS los archivos modificados en el fork que difieren de upstream.
**IMPORTANTE**: Revisar este archivo antes de cherry-pick de upstream para evitar conflictos.

## Archivos Modificados

### AGS - Configuración

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `.config/ags/constants/app.constants.ts` | File manager: Nautilus | Upstream usa Dolphin |
| `.config/ags/scripts/search-booru.py` | Null safety en r.json() | Fix crashes cuando API falla |

### AGS - Widgets

| Archivo | Cambio | Razón |
|---------|--------|-------|
| `.config/ags/app.ts` | Monitor hotplug + error handling | Fix multi-monitor bars |
| `.config/ags/utils/monitor.ts` | get_connector() como primario | Fix nombre de monitores |
| `.config/ags/widgets/rightPanel/components/Notification.tsx` | Null check antes de .endsWith() | Fix crash con notificaciones sin icono |

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

## Commits de Upstream a IGNORAR

Lista de commits de upstream que NO queremos porque:
- Cambian el file manager a Dolphin
- Revierten fixes que ya aplicamos
- etc.

| Commit | Razón para ignorar |
|--------|-------------------|
| (agregar según aparezcan) | |

## Última actualización

- Fecha: 2026-01-05
- Último commit de upstream revisado: (actualizar después de cada sync)
