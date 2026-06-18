#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <dirent.h>
#include <sys/stat.h>
#include <errno.h>
#include <ctype.h>
#include <stdbool.h>

#define MAX_PATH_LEN 512
#define MAX_LINE_LEN 1024
#define MAX_KEY_LEN 64

// Try to find keyboard device
char* find_keyboard_device() {
    static char device_path[MAX_PATH_LEN];
    const char* search_paths[] = {
        "/dev/input/by-id/*-event-kbd",
        "/dev/input/by-id/*-kbd",
        "/dev/input/by-path/*-event-kbd",
        "/dev/input/by-path/*-kbd",
        NULL
    };
    
    // Try direct path patterns first
    for (int i = 0; search_paths[i] != NULL; i++) {
        char cmd[MAX_PATH_LEN];
        snprintf(cmd, sizeof(cmd), "ls -1 %s 2>/dev/null | head -n1", search_paths[i]);
        
        FILE* fp = popen(cmd, "r");
        if (!fp) continue;
        
        if (fgets(device_path, sizeof(device_path), fp)) {
            device_path[strcspn(device_path, "\n")] = 0;
            pclose(fp);
            if (strlen(device_path) > 0) {
                return device_path;
            }
        }
        pclose(fp);
    }
    
    // Fallback: parse /proc/bus/input/devices
    FILE* fp = fopen("/proc/bus/input/devices", "r");
    if (!fp) return NULL;
    
    char line[MAX_LINE_LEN];
    bool has_kbd = false;
    char event_num[16] = {0};
    
    while (fgets(line, sizeof(line), fp)) {
        // Check for keyboard event bits
        if (strncmp(line, "B: EV=", 6) == 0) {
            if (strstr(line, "120013") || strstr(line, "120003") || 
                strstr(line, "12001")) {
                has_kbd = true;
            }
        }
        
        // Extract event number from handlers
        if (strncmp(line, "H: Handlers=", 12) == 0) {
            if (strstr(line, "kbd") || strstr(line, "event")) {
                char* event_str = strstr(line, "event");
                if (event_str) {
                    sscanf(event_str, "event%s", event_num);
                    // Remove any trailing non-digits
                    for (int i = 0; event_num[i]; i++) {
                        if (!isdigit(event_num[i])) {
                            event_num[i] = '\0';
                            break;
                        }
                    }
                }
            }
        }
        
        // If we found both, construct the path
        if (has_kbd && strlen(event_num) > 0 && line[0] == '\n') {
            snprintf(device_path, sizeof(device_path), "/dev/input/event%s", event_num);
            fclose(fp);
            return device_path;
        }
        
        // Reset on new device entry
        if (line[0] == '\n') {
            has_kbd = false;
            event_num[0] = '\0';
        }
    }
    
    fclose(fp);
    return NULL;
}

// Get keyboard layout from Hyprland
void get_xkb_layout(char* layout, char* variant, size_t size) {
    char* output = NULL;
    FILE* fp = popen("hyprctl devices -j 2>/dev/null", "r");
    if (!fp) goto fallback;
    
    char buffer[4096];
    size_t total = 0;
    size_t n;
    
    output = malloc(8192);
    if (!output) {
        pclose(fp);
        goto fallback;
    }
    
    while ((n = fread(buffer, 1, sizeof(buffer), fp)) > 0 && total < 8192) {
        memcpy(output + total, buffer, n);
        total += n;
    }
    output[total] = '\0';
    pclose(fp);
    
    // Simple parsing for active_keymap
    char* keymap_pos = strstr(output, "\"active_keymap\"");
    if (!keymap_pos) {
        free(output);
        goto fallback;
    }
    
    // Find the value after the colon
    char* value_start = strchr(keymap_pos, ':');
    if (!value_start) {
        free(output);
        goto fallback;
    }
    value_start++;
    
    // Skip whitespace and quote
    while (*value_start && (*value_start == ' ' || *value_start == '\t')) value_start++;
    if (*value_start == '"') value_start++;
    
    char* value_end = strchr(value_start, '"');
    if (!value_end) {
        free(output);
        goto fallback;
    }
    
    char hypr_layout[128];
    size_t len = value_end - value_start;
    if (len >= sizeof(hypr_layout)) len = sizeof(hypr_layout) - 1;
    strncpy(hypr_layout, value_start, len);
    hypr_layout[len] = '\0';
    
    free(output);
    
    // Map Hyprland layout to XKB
    if (strcmp(hypr_layout, "English (Dvorak)") == 0) {
        strncpy(layout, "us", size - 1);
        strncpy(variant, "dvorak", size - 1);
    } else if (strcmp(hypr_layout, "English (US)") == 0) {
        strncpy(layout, "us", size - 1);
        variant[0] = '\0';
    } else if (strcmp(hypr_layout, "English (UK)") == 0) {
        strncpy(layout, "gb", size - 1);
        variant[0] = '\0';
    } else if (strcmp(hypr_layout, "French") == 0) {
        strncpy(layout, "fr", size - 1);
        variant[0] = '\0';
    } else {
        goto fallback;
    }
    return;
    
fallback:
    strncpy(layout, "us", size - 1);
    variant[0] = '\0';
}

// Map keysym to display string
const char* map_key(const char* keysym) {
    if (strcmp(keysym, "Return") == 0) return "ENTER";
    if (strcmp(keysym, "Escape") == 0) return "󱊷";
    if (strcmp(keysym, "BackSpace") == 0) return "󰌍";
    if (strcmp(keysym, "Tab") == 0) return "󰌒";
    if (strcmp(keysym, "Shift_L") == 0 || strcmp(keysym, "Shift_R") == 0) return "󰘶";
    if (strcmp(keysym, "Control_L") == 0 || strcmp(keysym, "Control_R") == 0) return "CTRL";
    if (strcmp(keysym, "Alt_L") == 0 || strcmp(keysym, "Alt_R") == 0) return "ALT";
    if (strcmp(keysym, "Super_L") == 0 || strcmp(keysym, "Super_R") == 0) return "SUPER";
    if (strcmp(keysym, "Up") == 0) return "UP";
    if (strcmp(keysym, "Down") == 0) return "DOWN";
    if (strcmp(keysym, "Left") == 0) return "LEFT";
    if (strcmp(keysym, "Right") == 0) return "RIGHT";
    if (strcmp(keysym, "space") == 0) return "󱁐";
    if (strcmp(keysym, "XF86AudioRaiseVolume") == 0) return "󰝝";
    if (strcmp(keysym, "XF86AudioLowerVolume") == 0) return "󰝞";
    if (strcmp(keysym, "XF86AudioMute") == 0) return "󰝟";
    
    return keysym;
}

// Trim whitespace from string
void trim(char* str) {
    char* start = str;
    char* end;
    
    // Trim leading space
    while(isspace((unsigned char)*start)) start++;
    
    if(*start == 0) {
        str[0] = '\0';
        return;
    }
    
    // Trim trailing space
    end = start + strlen(start) - 1;
    while(end > start && isspace((unsigned char)*end)) end--;
    
    // Write new null terminator
    end[1] = '\0';
    
    // Move trimmed string to beginning
    if (start != str) {
        memmove(str, start, strlen(start) + 1);
    }
}

int main() {
    // Find keyboard device
    char* device = find_keyboard_device();
    if (!device) {
        fprintf(stderr, "No keyboard device found\n");
        return 1;
    }
    
    // Check if device is readable
    if (access(device, R_OK) != 0) {
        fprintf(stderr, "No permission to read keyboard device: %s\n", device);
        fprintf(stderr, "Try running with sudo or add yourself to input group\n");
        return 1;
    }
    
    // Get keyboard layout
    char layout[64];
    char variant[64];
    get_xkb_layout(layout, variant, sizeof(layout));
    
    // Build xkbcli command with stdbuf to disable output buffering
    char xkb_cmd[MAX_PATH_LEN];
    if (strlen(variant) > 0) {
        snprintf(xkb_cmd, sizeof(xkb_cmd), 
                 "stdbuf -oL -eL xkbcli interactive-evdev --short --enable-compose --rules evdev --model pc105 --layout %s --variant %s < %s 2>/dev/null",
                 layout, variant, device);
    } else {
        snprintf(xkb_cmd, sizeof(xkb_cmd), 
                 "stdbuf -oL -eL xkbcli interactive-evdev --short --enable-compose --rules evdev --model pc105 --layout %s < %s 2>/dev/null",
                 layout, device);
    }
    
    // Open xkbcli process
    FILE* fp = popen(xkb_cmd, "r");
    if (!fp) {
        perror("popen");
        return 1;
    }
    
    // Disable buffering on the pipe
    setvbuf(fp, NULL, _IONBF, 0);
    
    // Read and process output character by character to avoid buffering issues
    char line[MAX_LINE_LEN];
    int line_pos = 0;
    int c;
    
    while ((c = fgetc(fp)) != EOF) {
        if (c == '\n') {
            line[line_pos] = '\0';
            
            // Look for "key down" events with keysyms
            if (strstr(line, "key down") && strstr(line, "keysyms [")) {
                // Extract keysym between "keysyms [ " and " ]"
                char* start = strstr(line, "keysyms [");
                if (start) {
                    start += 9; // Skip "keysyms ["
                    
                    char* end = strchr(start, ']');
                    if (end) {
                        char keysym[MAX_KEY_LEN];
                        size_t len = end - start;
                        if (len >= MAX_KEY_LEN) len = MAX_KEY_LEN - 1;
                        
                        strncpy(keysym, start, len);
                        keysym[len] = '\0';
                        
                        // Trim whitespace
                        trim(keysym);
                        
                        if (strlen(keysym) > 0) {
                            const char* mapped = map_key(keysym);
                            printf("%s\n", mapped);
                            fflush(stdout);
                        }
                    }
                }
            }
            
            line_pos = 0;
        } else if (line_pos < MAX_LINE_LEN - 1) {
            line[line_pos++] = c;
        }
    }
    
    pclose(fp);
    return 0;
}
