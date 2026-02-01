#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <signal.h>
#include <stdbool.h>
#include <limits.h>

#define MAX_MONITORS 16
#define MAX_LINE_LEN 1024
#define MAX_PATH_LEN 512
#define MAX_MONITOR_NAME 64

typedef struct {
    char name[MAX_MONITOR_NAME];
    int previous_workspace_id;
    char current_wallpaper[MAX_PATH_LEN];
    bool initialized;
} MonitorState;

static MonitorState monitors[MAX_MONITORS];
static int monitor_count = 0;
static char hypr_dir[MAX_PATH_LEN];
static char config_dir[MAX_PATH_LEN];

// Get or create monitor state
MonitorState* get_monitor_state(const char* monitor_name) {
    // Check if monitor already exists
    for (int i = 0; i < monitor_count; i++) {
        if (strcmp(monitors[i].name, monitor_name) == 0) {
            return &monitors[i];
        }
    }
    
    // Add new monitor
    if (monitor_count < MAX_MONITORS) {
        strncpy(monitors[monitor_count].name, monitor_name, MAX_MONITOR_NAME - 1);
        monitors[monitor_count].previous_workspace_id = -1;
        monitors[monitor_count].current_wallpaper[0] = '\0';
        monitors[monitor_count].initialized = false;
        return &monitors[monitor_count++];
    }
    
    return NULL;
}

// Execute command and return output
char* exec_command(const char* cmd) {
    FILE* fp = popen(cmd, "r");
    if (!fp) return NULL;
    
    static char buffer[4096];
    size_t total = 0;
    size_t n;
    
    while ((n = fread(buffer + total, 1, sizeof(buffer) - total - 1, fp)) > 0) {
        total += n;
    }
    buffer[total] = '\0';
    
    pclose(fp);
    return buffer;
}

// Expand environment variables in path
void expand_path(const char* input, char* output, size_t output_size) {
    if (input[0] == '~') {
        const char* home = getenv("HOME");
        snprintf(output, output_size, "%s%s", home ? home : "", input + 1);
    } else if (strstr(input, "$HOME") == input) {
        const char* home = getenv("HOME");
        snprintf(output, output_size, "%s%s", home ? home : "", input + 5);
    } else {
        strncpy(output, input, output_size - 1);
        output[output_size - 1] = '\0';
    }
}

// Get wallpaper for workspace from config file
bool get_wallpaper_for_workspace(const char* monitor, int workspace_id, char* wallpaper, size_t size) {
    char config_path[MAX_PATH_LEN];
    snprintf(config_path, sizeof(config_path), "%s/hyprpaper/config/%s/defaults.conf", hypr_dir, monitor);
    
    FILE* fp = fopen(config_path, "r");
    if (!fp) return false;
    
    char line[MAX_LINE_LEN];
    char ws_key[32];
    snprintf(ws_key, sizeof(ws_key), "w-%d=", workspace_id);
    
    bool found = false;
    while (fgets(line, sizeof(line), fp)) {
        // Remove trailing newline
        line[strcspn(line, "\n")] = 0;
        
        if (strncmp(line, ws_key, strlen(ws_key)) == 0) {
            strncpy(wallpaper, line + strlen(ws_key), size - 1);
            wallpaper[size - 1] = '\0';
            found = true;
            break;
        }
    }
    
    fclose(fp);
    return found;
}

// Get active workspace for monitor
int get_active_workspace(const char* monitor_name) {
    char* output = exec_command("hyprctl monitors -j");
    if (!output) {
        printf("DEBUG: hyprctl monitors -j failed in get_active_workspace\n");
        return -1;
    }
    
    // Simple JSON parsing for workspace ID
    // Look for monitor name, then find activeWorkspace object
    char search[128];
    snprintf(search, sizeof(search), "\"name\": \"%s\"", monitor_name);
    char* monitor_pos = strstr(output, search);
    if (!monitor_pos) {
        // Try without space
        snprintf(search, sizeof(search), "\"name\":\"%s\"", monitor_name);
        monitor_pos = strstr(output, search);
    }
    
    if (!monitor_pos) {
        printf("DEBUG: Monitor %s not found in JSON\n", monitor_name);
        return -1;
    }
    
    char* workspace_pos = strstr(monitor_pos, "\"activeWorkspace\"");
    if (!workspace_pos) {
        printf("DEBUG: activeWorkspace not found for monitor %s\n", monitor_name);
        return -1;
    }
    
    char* id_pos = strstr(workspace_pos, "\"id\"");
    if (!id_pos) {
        printf("DEBUG: id not found in activeWorkspace\n");
        return -1;
    }
    
    // Skip to the value after "id":
    id_pos += 4; // Skip "id"
    while (*id_pos && (*id_pos == ' ' || *id_pos == ':')) id_pos++;
    
    int workspace_id;
    if (sscanf(id_pos, "%d", &workspace_id) == 1) {
        printf("DEBUG: Parsed workspace ID: %d for monitor %s\n", workspace_id, monitor_name);
        return workspace_id;
    }
    
    printf("DEBUG: Failed to parse workspace ID\n");
    return -1;
}

// Get all monitor names
int get_monitors(char monitors_list[][MAX_MONITOR_NAME]) {
    char* output = exec_command("hyprctl monitors -j");
    if (!output) {
        printf("DEBUG: hyprctl monitors -j returned NULL\n");
        return 0;
    }
    
    printf("DEBUG: hyprctl output length: %zu\n", strlen(output));
    
    int count = 0;
    char* pos = output;
    
    // Look for "name": "..." pattern (with space after colon)
    while (count < MAX_MONITORS) {
        pos = strstr(pos, "\"name\"");
        if (!pos) break;
        
        pos += 6; // Skip "name"
        // Skip whitespace and colon
        while (*pos && (*pos == ' ' || *pos == ':')) pos++;
        
        // Should be at opening quote now
        if (*pos != '"') {
            pos++;
            continue;
        }
        pos++; // Skip opening quote
        
        char* end = strchr(pos, '"');
        if (!end) break;
        
        size_t len = end - pos;
        if (len >= MAX_MONITOR_NAME) len = MAX_MONITOR_NAME - 1;
        
        strncpy(monitors_list[count], pos, len);
        monitors_list[count][len] = '\0';
        printf("DEBUG: Found monitor: %s\n", monitors_list[count]);
        count++;
        
        pos = end + 1;
    }
    
    return count;
}

// Check if hyprpaper is running
bool is_hyprpaper_running() {
    int result = system("pgrep -x hyprpaper >/dev/null 2>&1");
    return result == 0;
}

// Kill running wallpaper script
void kill_wallpaper_script() {
    char cmd[MAX_PATH_LEN];
    snprintf(cmd, sizeof(cmd), "pgrep -f '%s/hyprpaper/w.sh' >/dev/null 2>&1", hypr_dir);
    
    if (system(cmd) == 0) {
        system("killall w.sh 2>/dev/null");
    }
}

// Change wallpaper for monitors
void change_wallpaper() {
    char monitors_list[MAX_MONITORS][MAX_MONITOR_NAME];
    int num_monitors = get_monitors(monitors_list);
    
    printf("DEBUG: Found %d monitors\n", num_monitors);
    
    for (int i = 0; i < num_monitors; i++) {
        const char* monitor = monitors_list[i];
        printf("DEBUG: Processing monitor: %s\n", monitor);
        
        MonitorState* state = get_monitor_state(monitor);
        if (!state) {
            printf("DEBUG: Failed to get monitor state\n");
            continue;
        }
        
        int workspace_id = get_active_workspace(monitor);
        printf("DEBUG: Active workspace for %s: %d\n", monitor, workspace_id);
        if (workspace_id == -1) {
            printf("DEBUG: Failed to get workspace ID\n");
            continue;
        }
        
        // Skip if workspace hasn't changed
        if (state->initialized && state->previous_workspace_id == workspace_id) {
            printf("DEBUG: Workspace unchanged (%d), skipping\n", workspace_id);
            continue;
        }
        
        char wallpaper[MAX_PATH_LEN];
        if (!get_wallpaper_for_workspace(monitor, workspace_id, wallpaper, sizeof(wallpaper))) {
            printf("DEBUG: No wallpaper config found for workspace %d\n", workspace_id);
            continue;
        }
        
        printf("DEBUG: Wallpaper config: %s\n", wallpaper);
        
        // Check if wallpaper has changed
        if (state->initialized && strcmp(wallpaper, state->current_wallpaper) == 0) {
            printf("DEBUG: Wallpaper unchanged, updating workspace ID only\n");
            state->previous_workspace_id = workspace_id;
            continue;
        }
        
        // Expand path variables
        char expanded_wallpaper[MAX_PATH_LEN];
        expand_path(wallpaper, expanded_wallpaper, sizeof(expanded_wallpaper));
        
        printf("DEBUG: Expanded wallpaper: %s\n", expanded_wallpaper);
        
        // Write current wallpaper to file
        char current_conf[MAX_PATH_LEN];
        snprintf(current_conf, sizeof(current_conf), "%s/hyprpaper/config/current.conf", hypr_dir);
        FILE* fp = fopen(current_conf, "w");
        if (fp) {
            fprintf(fp, "%s\n", expanded_wallpaper);
            fclose(fp);
            printf("DEBUG: Wrote to current.conf\n");
        } else {
            printf("DEBUG: Failed to write current.conf\n");
        }
        
        // Kill existing wallpaper script
        kill_wallpaper_script();
        
        // Run new wallpaper script in background
        char cmd[MAX_PATH_LEN * 2];
        snprintf(cmd, sizeof(cmd), "%s/hyprpaper/w.sh '%s' '%s' &", 
                 hypr_dir, monitor, expanded_wallpaper);
        printf("DEBUG: Running command: %s\n", cmd);
        system(cmd);
        
        // Update state
        strncpy(state->current_wallpaper, wallpaper, MAX_PATH_LEN - 1);
        state->previous_workspace_id = workspace_id;
        state->initialized = true;
        printf("DEBUG: State updated for monitor %s\n", monitor);
    }
}

// Connect to Hyprland socket
int connect_to_hyprland_socket() {
    const char* runtime_dir = getenv("XDG_RUNTIME_DIR");
    const char* hypr_instance = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    
    if (!runtime_dir || !hypr_instance) {
        fprintf(stderr, "Error: XDG_RUNTIME_DIR or HYPRLAND_INSTANCE_SIGNATURE not set\n");
        return -1;
    }
    
    char socket_path[MAX_PATH_LEN];
    snprintf(socket_path, sizeof(socket_path), "%s/hypr/%s/.socket2.sock", 
             runtime_dir, hypr_instance);
    
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("socket");
        return -1;
    }
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);
    
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("connect");
        close(sock);
        return -1;
    }
    
    return sock;
}

int main() {
    // Set up paths
    const char* home = getenv("HOME");
    if (!home) {
        fprintf(stderr, "Error: HOME environment variable not set\n");
        return 1;
    }
    
    snprintf(hypr_dir, sizeof(hypr_dir), "%s/.config/hypr", home);
    snprintf(config_dir, sizeof(config_dir), "%s/hyprpaper/config", hypr_dir);
    
    // Wait for hyprpaper to start
    printf("Waiting for hyprpaper to start...\n");
    while (!is_hyprpaper_running()) {
        sleep(1);
    }
    printf("hyprpaper detected, proceeding...\n");
    
    sleep(1); // Give it a moment to stabilize

    // Initial wallpaper setup
    printf("Setting initial wallpapers...\n");
    change_wallpaper();
    
    // Connect to Hyprland socket
    printf("Connecting to Hyprland socket...\n");
    int sock = connect_to_hyprland_socket();
    if (sock < 0) {
        return 1;
    }
    
    printf("Listening for workspace changes...\n");
    
    // Listen for events - read line by line
    FILE* sock_file = fdopen(sock, "r");
    if (!sock_file) {
        perror("fdopen");
        close(sock);
        return 1;
    }
    
    char buffer[MAX_LINE_LEN];
    while (fgets(buffer, sizeof(buffer), sock_file) != NULL) {
        // Remove trailing newline
        buffer[strcspn(buffer, "\n")] = 0;
        
        printf("Event received: %s\n", buffer);
        
        // Check if it's a workspace-related event
        if (strstr(buffer, "workspace>>") != NULL || 
            strstr(buffer, "focusedmon>>") != NULL) {
            printf("Workspace/Monitor change detected, updating wallpaper...\n");
            change_wallpaper();
        }
    }
    
    fclose(sock_file);
    return 0;
}
