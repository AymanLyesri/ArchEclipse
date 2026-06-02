#!/bin/bash

# Read boolean flags from theme.conf.
# Supported format:
#   autocolor=true
#   autovariant=false
# Backward-compatible format:
#   true|false
#
# Assumes THEME_CONF_FILE is already defined by the calling script.
get_theme_bool() {
    local key="$1"
    local default_value="$2"
    local line
    local value
    
    if [[ ! -f "$THEME_CONF_FILE" ]]; then
        echo "$default_value"
        return
    fi
    
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line%%;*}"
        line="${line//[[:space:]]/}"
        [[ -z "$line" ]] && continue
        
        # Backward compatibility: whole-file true/false.
        if [[ "$line" == "true" || "$line" == "false" ]]; then
            echo "$line"
            return
        fi
        
        if [[ "$line" == "$key="* ]]; then
            value="${line#*=}"
            value="${value,,}"
            if [[ "$value" == "true" || "$value" == "false" ]]; then
                echo "$value"
                return
            fi
            break
        fi
    done < "$THEME_CONF_FILE"
    
    echo "$default_value"
}

# Detect if a hex color is light or dark based on luminance
# Returns "light" or "dark"
detect_color_variant() {
    local hex="$1"
    
    # Remove # if present
    hex="${hex#\#}"
    
    # Convert hex to RGB
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    
    # Calculate perceived brightness using standard formula
    # Formula: (R*299 + G*587 + B*114)/1000
    local brightness=$(( (r * 299 + g * 587 + b * 114) / 1000 ))
    
    # If brightness > 128, it's light; otherwise dark
    if [[ $brightness -gt 128 ]]; then
        echo "light"
    else
        echo "dark"
    fi
}

# Detect variant directly from wallpaper average RGB value.
# Uses ImageMagick to sample a 1x1 average color and classify it.
detect_variant_from_wallpaper() {
    local wallpaper="$1"
    local rgb
    local r
    local g
    local b
    local brightness

    if [[ ! -f "$wallpaper" ]]; then
        echo "dark"
        return
    fi

    if ! command -v magick >/dev/null 2>&1; then
        echo "dark"
        return
    fi

    rgb=$(magick "$wallpaper" -resize 1x1\! -format "%[fx:int(255*r)],%[fx:int(255*g)],%[fx:int(255*b)]" info: 2>/dev/null || true)
    if [[ -z "$rgb" || "$rgb" != *,*,* ]]; then
        echo "dark"
        return
    fi

    IFS=',' read -r r g b <<< "$rgb"
    brightness=$(( (r * 299 + g * 587 + b * 114) / 1000 ))

    if [[ $brightness -gt 128 ]]; then
        echo "light"
    else
        echo "dark"
    fi
}
