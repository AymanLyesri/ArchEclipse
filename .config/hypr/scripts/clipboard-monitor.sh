#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config
# =========================
TMP_DIR="/tmp"
PREVIEW_CMD="swayimg --class preview-image"
EDIT_CMD="gimp"
HISTORY_FILE="$HOME/.config/ags/cache/launcher/clipboard-history.json"
HISTORY_LOCK="/tmp/clipboard-history.lock"

# =========================
# Validation
# =========================
if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed" >> /tmp/clipboard-monitor.log
    exit 1
fi

# =========================
# Initialize JSON history file
# =========================
init_history_file() {
    local history_dir="$(dirname "$HISTORY_FILE")"
    mkdir -p "$history_dir"
    
    if [[ ! -f "$HISTORY_FILE" ]]; then
        echo '[]' > "$HISTORY_FILE"
        return
    fi
    
    # Migrate legacy format {"version":...,"maxEntries":...,"entries":[...]} -> [...]
    if jq -e 'type == "object" and has("entries") and (.entries | type == "array")' "$HISTORY_FILE" >/dev/null 2>&1; then
        jq '.entries' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" && mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
        return
    fi
    
    # If file is invalid or not an array, reset to empty array
    if ! jq -e 'type == "array"' "$HISTORY_FILE" >/dev/null 2>&1; then
        echo '[]' > "$HISTORY_FILE"
    fi
}

# =========================
# Add entry to clipboard history
# =========================
add_to_history() {
    local type="$1"
    local content="$2"
    local mime_type="$3"
    
    # Generate timestamp
    local ts=$(date +%s)
    
    # Escape content for JSON
    local content_escaped=$(jq -n --arg c "$content" '$c')
    
    # Add entry with file locking to prevent race conditions
    (
        flock -x 200
        
        # Prepend new entry to root JSON array (newest first)
        jq --argjson entry "{
            \"id\": $ts,
            \"timestamp\": $ts,
            \"type\": \"$type\",
            \"content\": $content_escaped,
            \"mimeType\": \"$mime_type\"
        }" '[$entry] + .' "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>> /tmp/clipboard-monitor.log
        
        # Atomic move
        mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
        
    ) 200>"$HISTORY_LOCK"
}

# Initialize history file on script start
init_history_file

# =========================
# Timestamped image path
# =========================
timestamp=$(date +%Y%m%d_%H%M%S)

# =========================
# Try image from clipboard
# =========================
image_saved=false
detected_mime=""

# Try different image formats
for mime in "image/png" "image/jpeg" "image/webp"; do
    ext="${mime#image/}"
    image_path="$TMP_DIR/clipboard_image_${timestamp}.${ext}"
    
    if wl-paste --type "$mime" >"$image_path" 2>/dev/null; then
        detected_mime="$mime"
        image_saved=true
        break
    fi
done

if [[ "$image_saved" == "true" ]]; then
    # Add to clipboard history
    add_to_history "image" "$image_path" "$detected_mime"
    exit 0
fi

# =========================
# Try uri-list from clipboard
# =========================
if clipboard_uri=$(wl-paste --no-newline --type text/uri-list 2>/dev/null) && [[ -n "$clipboard_uri" ]]; then
    # Extract file full path from uri-list (e.g., file:///home/user/Videos/clip.webm) to /home/user/Videos/clip.webm
    file_path="${clipboard_uri#file://}"
    # Extract extension (mp4, webm, mkv, etc.)
    extension="${file_path##*.}"
    
    # Add to clipboard history
    add_to_history "uri-list" "$file_path" "text/uri-list"
    exit 0
fi


# =========================
# Try HTML text from clipboard
# =========================
# if clipboard_html=$(wl-paste --no-newline --type text/html 2>/dev/null) && [[ -n "$clipboard_html" ]]; then
#     add_to_history "text" "$clipboard_html" "text/html"
#     exit 0
# fi

# =========================
# Fallback: plain text clipboard
# =========================
if clipboard_text=$(wl-paste --no-newline --type text/plain 2>/dev/null) && [[ -n "$clipboard_text" ]]; then
    add_to_history "text" "$clipboard_text" "text/plain"
    exit 0
fi
