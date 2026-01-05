# Home Directory Reorganization

**Status:** COMPLETADO
**Fecha completado:** 2026-01-04
**Fecha diagnóstico original:** 2026-01-03

## Resumen de Resultados

| Métrica | Antes | Después |
|---------|-------|---------|
| Disco usado | 348GB | 321GB |
| Disco libre | 582GB | 609GB |
| Cache `~/.cache/` | 54GB | 12GB |
| **Espacio recuperado** | - | **+27GB** |

## Acciones Completadas

### Fase 1: Limpieza de Caches
- `~/.cache/davinci-resolve-install/` (24GB) - **BORRADO**
- `~/.cache/JetBrains/` versiones antiguas (~17GB) - **BORRADO**
- `pip cache purge` (673MB) - **BORRADO**
- `npm cache clean` (3.7GB) - **BORRADO**

### Fase 2: Mover Archivos Personales
- `COMO_USAR_*.md` → `~/Documents/guides/`
- `paquetes_instalados.txt` → `~/Documents/backups/`
- `fix-vlc-mime.sh`, `setup-teams-profiles.sh` → `~/.local/bin/`
- `postman.log`, `Untitled.blend` - **BORRADOS**

### Fase 3: Consolidar Configs
- **Hallazgo:** Las carpetas `~/wofi/`, `~/mako/`, `~/swaylock/` están trackeadas por git (upstream)
- **Decisión:** Mantener para compatibilidad con upstream (no están en uso activo)

### Fase 4: Limpiar Carpetas Obsoletas
- `~/dotfiles_backup_20250320/` (619MB) - **BORRADO**
- Carpetas legacy (waybar, wofi, etc.) - **MANTENIDAS** (trackeadas por git)

### Fase 5: Actualizar .gitignore
- Agregada documentación explicando la estrategia de ignore

## Diagnóstico Original

### Problema Principal

El HOME completo (`~`) es el repositorio de ArchEclipse. Esto causa:
- Mezcla de archivos personales con la rice
- Archivos de config duplicados (en `~/` y `~/.config/`)
- Dificultad para sincronizar con upstream
- Confusión sobre qué archivos son de la rice vs personales

### Diagnóstico de Espacio

| Carpeta | Tamaño | Notas |
|---------|--------|-------|
| `~/.local` | 116GB | Steam 91GB, JetBrains 18GB |
| `~/.cache` | 54GB | DaVinci installer 24GB, JetBrains 20GB |
| `~/Downloads` | 42GB | Limpieza pendiente |
| `~/.config` | 16GB | Normal |
| `~/.npm` | 3.7GB | Cache de npm |
| `~/.gradle` | 2.7GB | Cache de Android |

### Carpetas Trackeadas por Git (NO BORRAR)

| Carpeta | En Uso | Notas |
|---------|--------|-------|
| `~/wofi/` | No (usa AGS) | Config wofi - mantener por upstream |
| `~/wofifull/` | No | Variante wofi - mantener por upstream |
| `~/mako/` | No | Config notificaciones - mantener por upstream |
| `~/swaylock/` | No (usa hyprlock) | Config lock - mantener por upstream |
| `~/waybar/` | No (usa AGS) | Config waybar - mantener por upstream |
| `~/themes/` | Sí | Temas Catppuccin - mantener |
| `~/scripts/` | Sí | Scripts del rice - mantener |
| `~/configs/` | Sí | Configs base - mantener |

### Herramientas Actuales vs Configs del Repo

| Función | Config en Repo | Herramienta Actual |
|---------|----------------|-------------------|
| Lanzador | `~/wofi/` | **AGS** app-launcher |
| Notificaciones | `~/mako/` | **AGS** |
| Bloqueo pantalla | `~/swaylock/` | **hyprlock** |
| Barra de estado | `~/waybar/` | **AGS** |

## Comandos de Limpieza (Referencia)

```bash
# Borrar instalador de DaVinci (ya instalado)
rm -rf ~/.cache/davinci-resolve-install/

# Limpiar cache de pip
pip cache purge

# Limpiar cache de npm
npm cache clean --force

# Ver tamaño de carpetas
du -sh ~/*/ ~/.*/  2>/dev/null | sort -hr | head -20

# Ver qué archivos están siendo trackeados por git
git -C ~ ls-files | head -50
```
