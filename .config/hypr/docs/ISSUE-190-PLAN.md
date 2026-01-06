# Issue #190 - Home Directory Reorganization Plan

## Respuesta de Ayman (2026-01-05)

Ayman respondió positivamente y sugirió dos scripts separados:

### 1. Script para remover archivos LEGACY
**Propósito**: Backup del HOME antes de instalar nuevos ArchEclipse dotfiles

**Approach**:
- Backup completo del `$HOME`
- Opción para revertir cambios
- Ejecutar ANTES de instalar dotfiles nuevos

### 2. Script para remover ArchEclipse DotFiles
**Propósito**: Remover SOLO los archivos de ArchEclipse sin tocar archivos personales

**Código ejemplo de Ayman**:
```bash
#!/bin/bash
set -euo pipefail

BACKUP_DIR="$HOME/archEclipse-backup-$(date +%Y%m%d-%H%M%S)"

echo "Backup directory: $BACKUP_DIR"
echo "The following files will be MOVED:"
echo

git ls-files

echo
read -rp "Proceed? (y/N): " confirm
[[ "$confirm" == "y" ]] || exit 0

mkdir -p "$BACKUP_DIR"

git ls-files -z | while IFS= read -r -d '' file; do
  mkdir -p "$BACKUP_DIR/$(dirname "$file")"
  mv "$file" "$BACKUP_DIR/$file"
done

echo "✔ All tracked files moved to $BACKUP_DIR"
```

---

## Plan de Implementación

### Fase 1: Script de Uninstall (Prioridad Alta)
**Archivo**: `maintenance/UNINSTALL.sh`

**Features**:
1. Lista todos los archivos tracked por git
2. Pregunta confirmación
3. Crea backup con timestamp
4. Mueve archivos a backup
5. Opción de restaurar desde backup

**Mejoras sobre el código de Ayman**:
- Agregar colores/formato
- Verificar que estamos en el repo correcto
- Mostrar tamaño total de archivos
- Opción `--dry-run`
- Log de operaciones

### Fase 2: Script de Cleanup Legacy (Prioridad Media)
**Archivo**: `maintenance/CLEANUP-LEGACY.sh`

**Features**:
1. Detectar carpetas legacy (waybar, wofi, mako, swaylock)
2. Verificar que AGS está funcionando como reemplazo
3. Ofrecer backup antes de eliminar
4. Eliminar solo si el usuario confirma

**Carpetas legacy identificadas**:
```
~/wofi/          → AGS app-launcher
~/wofifull/      → AGS app-launcher
~/mako/          → AGS notifications
~/swaylock/      → hyprlock
~/waybar/        → AGS bar
~/waybarBackUp/  → AGS bar
```

### Fase 3: Script de Reorganización (Prioridad Baja)
**Archivo**: `maintenance/REORGANIZE.sh`

**Features**:
1. Crear directorios XDG estándar
2. Mover archivos personales comunes
3. Limpiar caches (interactivo)
4. Verificar instalación funcionando

---

## Archivos a Crear

| Archivo | Descripción | Prioridad |
|---------|-------------|-----------|
| `maintenance/UNINSTALL.sh` | Remover dotfiles de ArchEclipse | Alta |
| `maintenance/CLEANUP-LEGACY.sh` | Remover configs legacy | Media |
| `maintenance/REORGANIZE.sh` | Organizar home directory | Baja |
| `maintenance/BACKUP.sh` | Backup completo de configs | Media |

---

## Respuesta Propuesta al Issue

```markdown
Thanks for the detailed response @AymanLyesri!

I'll work on implementing both scripts. Here's my plan:

## Phase 1: UNINSTALL.sh (Based on your code)
I'll enhance your script with:
- Colors and better formatting
- `--dry-run` option to preview changes
- Size summary before proceeding
- Restore option from backup

## Phase 2: CLEANUP-LEGACY.sh
A separate script to remove legacy folders (waybar, wofi, mako, swaylock) with:
- Verification that AGS/hyprlock is working as replacement
- Interactive confirmation for each folder
- Backup before deletion

## Phase 3: Documentation
I'll add a section to README explaining:
- Which folders are essential vs legacy
- How to use the cleanup scripts
- What each folder contains

I'll start with Phase 1 and submit a PR when ready. Does this approach work for you?
```

---

## Notas Técnicas

### git ls-files
- Lista todos los archivos tracked
- Con `-z` usa null separators (safe para filenames con espacios)
- Solo funciona dentro del repo

### Consideraciones
- El repo usa `$HOME` como root, lo cual complica las cosas
- Muchos usuarios pueden tener archivos personales mezclados
- El script debe ser MUY cuidadoso de no borrar archivos no-tracked

### Testing
- Probar en VM primero
- Crear snapshot antes de ejecutar
- Verificar que el backup es completo

---

## Timeline Propuesto

1. **Semana 1**: Implementar UNINSTALL.sh
2. **Semana 2**: Probar y refinar, crear PR
3. **Semana 3**: Implementar CLEANUP-LEGACY.sh si se aprueba fase 1
4. **Futuro**: REORGANIZE.sh si hay interés

---

Última actualización: 2026-01-05
