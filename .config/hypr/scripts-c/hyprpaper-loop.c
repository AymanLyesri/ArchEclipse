/*
 * Hyprland Wallpaper Daemon
 * Automatically changes wallpapers based on active workspace
 * Monitors Hyprland events and switches wallpapers per monitor configuration
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <stdbool.h>
#include <errno.h>
#include <time.h>

#define MAX_MONITORS 16
#define MAX_LINE_LEN 1024
#define MAX_PATH_LEN 512
#define MAX_MONITOR_NAME 64
#define LOG_FILE "/tmp/wallpaper-daemon.log"

/* Monitor state tracking structure */
typedef struct {
    char name[MAX_MONITOR_NAME];
    int previous_workspace_id;
    char current_wallpaper[MAX_PATH_LEN];
    bool initialized;
} MonitorState;

/* Global state */
static MonitorState monitors[MAX_MONITORS];
static int monitor_count = 0;
static char hypr_dir[MAX_PATH_LEN];

/* Forward declarations */
void notify_error(const char* where, const char* message);
char* exec_command(const char* cmd);

/*
 * Recursively create directories (mkdir -p behavior)
 */
static bool ensure_dir(const char* path) {
    char tmp[MAX_PATH_LEN];
    size_t len = strnlen(path, sizeof(tmp));

    if (len == 0 || len >= sizeof(tmp)) {
        return false;
    }

    strncpy(tmp, path, sizeof(tmp) - 1);
    tmp[sizeof(tmp) - 1] = '\0';

    if (tmp[len - 1] == '/') {
        tmp[len - 1] = '\0';
    }

    for (char* p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
                return false;
            }
            *p = '/';
        }
    }

    if (mkdir(tmp, 0755) != 0 && errno != EEXIST) {
        return false;
    }

    return true;
}

/*
 * Copy file contents from src to dst
 */
static bool copy_file(const char* src, const char* dst) {
    FILE* in = fopen(src, "r");
    if (!in) {
        return false;
    }

    FILE* out = fopen(dst, "w");
    if (!out) {
        fclose(in);
        return false;
    }

    char buf[4096];
    size_t n;
    while ((n = fread(buf, 1, sizeof(buf), in)) > 0) {
        if (fwrite(buf, 1, n, out) != n) {
            fclose(in);
            fclose(out);
            return false;
        }
    }

    fclose(in);
    fclose(out);
    return true;
}

/*
 * Create monitor config structure and defaults.conf if missing or empty
 */
static void create_config_structure() {
    char* output = exec_command("hyprctl monitors | awk '/Monitor/ {print $2}'");
    if (!output) {
        notify_error("create_config_structure", "Failed to list monitors");
        return;
    }

    char base_dir[MAX_PATH_LEN];
    char backup_conf[MAX_PATH_LEN];
    snprintf(base_dir, sizeof(base_dir), "%s/hyprpaper/config", hypr_dir);
    snprintf(backup_conf, sizeof(backup_conf), "%s/hyprpaper/config/defaults.conf", hypr_dir);

    if (!ensure_dir(base_dir)) {
        notify_error("create_config_structure", "Failed to ensure base config directory");
        return;
    }

    char* line = strtok(output, "\n");
    while (line) {
        char monitor_dir[MAX_PATH_LEN];
        char monitor_conf[MAX_PATH_LEN];

        snprintf(monitor_dir, sizeof(monitor_dir), "%s/%s", base_dir, line);
        snprintf(monitor_conf, sizeof(monitor_conf), "%s/defaults.conf", monitor_dir);

        if (!ensure_dir(monitor_dir)) {
            char error_msg[512];
            snprintf(error_msg, sizeof(error_msg), "Failed to create dir for %s", line);
            notify_error("create_config_structure", error_msg);
            line = strtok(NULL, "\n");
            continue;
        }

        struct stat st;
        bool needs_init = (stat(monitor_conf, &st) != 0) || (st.st_size == 0);
        if (needs_init) {
            if (!copy_file(backup_conf, monitor_conf)) {
                char error_msg[512];
                snprintf(error_msg, sizeof(error_msg), "Failed to init %s", monitor_conf);
                notify_error("create_config_structure", error_msg);
            }
        }

        line = strtok(NULL, "\n");
    }
}

/*
 * Error notification system
 * Sends desktop notifications, logs to file, and prints to stderr
 */
void notify_error(const char* where, const char* message) {
    char cmd[1024];
    time_t now = time(NULL);
    struct tm* tm_info = localtime(&now);
    char timestamp[64];
    strftime(timestamp, sizeof(timestamp), "%Y-%m-%d %H:%M:%S", tm_info);

    snprintf(cmd, sizeof(cmd), "notify-send -u critical 'Wallpaper Daemon Error' '%s: %s'", where, message);
    system(cmd);

    FILE* log = fopen(LOG_FILE, "a");
    if (log) {
        fprintf(log, "[%s] %s: %s\n", timestamp, where, message);
        fclose(log);
    }

    fprintf(stderr, "[%s] ERROR in %s: %s\n", timestamp, where, message);
}

/*
 * Get or create monitor state
 * Returns pointer to existing monitor state or creates a new one
 */
MonitorState* get_monitor_state(const char* monitor_name) {
    for (int i = 0; i < monitor_count; i++) {
        if (strcmp(monitors[i].name, monitor_name) == 0) {
            return &monitors[i];
        }
    }
    
    if (monitor_count < MAX_MONITORS) {
        strncpy(monitors[monitor_count].name, monitor_name, MAX_MONITOR_NAME - 1);
        monitors[monitor_count].previous_workspace_id = -1;
        monitors[monitor_count].current_wallpaper[0] = '\0';
        monitors[monitor_count].initialized = false;
        return &monitors[monitor_count++];
    }
    
    return NULL;
}

/*
 * Execute shell command and capture output
 * Uses static buffer - not thread-safe
 */
char* exec_command(const char* cmd) {
    FILE* fp = popen(cmd, "r");
    if (!fp) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "popen failed for '%s': %s", cmd, strerror(errno));
        notify_error("exec_command", error_msg);
        return NULL;
    }
    
    static char buffer[4096];
    size_t total = 0, n;
    
    while ((n = fread(buffer + total, 1, sizeof(buffer) - total - 1, fp)) > 0) {
        total += n;
    }
    buffer[total] = '\0';
    pclose(fp);
    return buffer;
}

/*
 * Expand environment variables in file paths
 * Supports ~ and $HOME prefixes
 */
void expand_path(const char* input, char* output, size_t output_size) {
    const char* home = getenv("HOME");
    if (!home) home = "";
    
    if (input[0] == '~') {
        snprintf(output, output_size, "%s%s", home, input + 1);
    } else if (strncmp(input, "$HOME", 5) == 0) {
        snprintf(output, output_size, "%s%s", home, input + 5);
    } else {
        strncpy(output, input, output_size - 1);
        output[output_size - 1] = '\0';
    }
}

/*
 * Get wallpaper path for specific workspace
 * Reads from monitor-specific config file
 * Format: w-{workspace_id}={wallpaper_path}
 */
bool get_wallpaper_for_workspace(const char* monitor, int workspace_id, char* wallpaper, size_t size) {
    char config_path[MAX_PATH_LEN];
    snprintf(config_path, sizeof(config_path), "%s/hyprpaper/config/%s/defaults.conf", hypr_dir, monitor);
    
    FILE* fp = fopen(config_path, "r");
    if (!fp) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "Cannot open config at %s: %s", config_path, strerror(errno));
        notify_error("get_wallpaper_for_workspace", error_msg);
        return false;
    }
    
    char line[MAX_LINE_LEN];
    char ws_key[32];
    snprintf(ws_key, sizeof(ws_key), "w-%d=", workspace_id);
    
    bool found = false;
    while (fgets(line, sizeof(line), fp)) {
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

/*
 * Get active workspace ID for a monitor
 * Parses JSON output from hyprctl monitors
 * Searches for monitor by name, then extracts activeWorkspace.id
 */
int get_active_workspace(const char* monitor_name) {
    char* output = exec_command("hyprctl monitors -j");
    if (!output) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "hyprctl command failed for monitor '%s'", monitor_name);
        notify_error("get_active_workspace", error_msg);
        return -1;
    }
    
    char search[128];
    snprintf(search, sizeof(search), "\"name\": \"%s\"", monitor_name);
    char* monitor_pos = strstr(output, search);
    if (!monitor_pos) {
        snprintf(search, sizeof(search), "\"name\":\"%s\"", monitor_name);
        monitor_pos = strstr(output, search);
    }
    
    if (!monitor_pos) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "Monitor '%s' not found in JSON", monitor_name);
        notify_error("get_active_workspace", error_msg);
        return -1;
    }
    
    char* workspace_pos = strstr(monitor_pos, "\"activeWorkspace\"");
    if (!workspace_pos) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "activeWorkspace not found for '%s'", monitor_name);
        notify_error("get_active_workspace", error_msg);
        return -1;
    }
    
    char* id_pos = strstr(workspace_pos, "\"id\"");
    if (!id_pos) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "Workspace ID not found for '%s'", monitor_name);
        notify_error("get_active_workspace", error_msg);
        return -1;
    }
    
    id_pos += 4;
    while (*id_pos && (*id_pos == ' ' || *id_pos == ':')) id_pos++;
    
    int workspace_id;
    if (sscanf(id_pos, "%d", &workspace_id) == 1) {
        return workspace_id;
    }
    
    char error_msg[512];
    snprintf(error_msg, sizeof(error_msg), "Failed to parse workspace ID for '%s'", monitor_name);
    notify_error("get_active_workspace", error_msg);
    return -1;
}

/*
 * Get list of all physical monitors
 * Parses hyprctl monitors JSON and extracts monitor names
 * Filters out special workspaces and numeric IDs (workspace names)
 */
int get_monitors(char monitors_list[][MAX_MONITOR_NAME]) {
    char* output = exec_command("hyprctl monitors -j");
    if (!output) {
        notify_error("get_monitors", "hyprctl command failed");
        return 0;
    }
    
    int count = 0;
    char* pos = output;
    
    /* Parse JSON structure looking for monitor objects
     * Pattern: { "id": <num>, "name": "<monitor_name>", ...
     * Avoids workspace names by checking context */
    while (count < MAX_MONITORS) {
        pos = strstr(pos, "\"id\"");
        if (!pos) break;
        
        char* after_id = pos + 4;
        while (*after_id && (*after_id == ' ' || *after_id == ':')) after_id++;
        
        char* comma_pos = strchr(after_id, ',');
        if (!comma_pos) {
            pos++;
            continue;
        }
        
        char* name_pos = strstr(comma_pos, "\"name\"");
        if (!name_pos || name_pos - comma_pos > 200) {
            pos++;
            continue;
        }
        
        /* Skip if inside a workspace object (activeWorkspace/specialWorkspace) */
        char* workspace_check = strstr(comma_pos, "Workspace\"");
        if (workspace_check && workspace_check < name_pos) {
            pos = name_pos + 6;
            continue;
        }
        
        name_pos += 6;
        while (*name_pos && (*name_pos == ' ' || *name_pos == ':')) name_pos++;
        
        if (*name_pos != '"') {
            pos++;
            continue;
        }
        name_pos++;
        
        char* end = strchr(name_pos, '"');
        if (!end) break;
        
        size_t len = end - name_pos;
        if (len == 0 || len >= MAX_MONITOR_NAME) {
            pos = end + 1;
            continue;
        }
        
        char temp_name[MAX_MONITOR_NAME];
        strncpy(temp_name, name_pos, len);
        temp_name[len] = '\0';
        
        /* Filter out special workspaces and pure numeric names */
        bool is_numeric = true;
        for (size_t i = 0; i < len; i++) {
            if (temp_name[i] < '0' || temp_name[i] > '9') {
                is_numeric = false;
                break;
            }
        }
        
        if (strstr(temp_name, "special") || is_numeric) {
            pos = end + 1;
            continue;
        }
        
        strcpy(monitors_list[count++], temp_name);
        pos = end + 1;
    }
    
    return count;
}

/* Check if hyprpaper process is running */
bool is_hyprpaper_running() {
    return system("pgrep -x hyprpaper >/dev/null 2>&1") == 0;
}

/* Kill any running wallpaper script instances */
void kill_wallpaper_script() {
    char cmd[MAX_PATH_LEN];
    snprintf(cmd, sizeof(cmd), "pgrep -f '%s/hyprpaper/w.sh' >/dev/null 2>&1", hypr_dir);
    if (system(cmd) == 0) {
        system("killall w.sh 2>/dev/null");
    }
}

/*
 * Main wallpaper change handler
 * Iterates through all monitors, checks workspace changes, and updates wallpapers
 * Only changes wallpaper when workspace or wallpaper path differs from previous state
 */
void change_wallpaper() {
    char monitors_list[MAX_MONITORS][MAX_MONITOR_NAME];
    int num_monitors = get_monitors(monitors_list);
    
    for (int i = 0; i < num_monitors; i++) {
        const char* monitor = monitors_list[i];
        
        MonitorState* state = get_monitor_state(monitor);
        if (!state) {
            char error_msg[512];
            snprintf(error_msg, sizeof(error_msg), "Max monitors (%d) reached for '%s'", MAX_MONITORS, monitor);
            notify_error("change_wallpaper", error_msg);
            continue;
        }
        
        int workspace_id = get_active_workspace(monitor);
        if (workspace_id == -1) {
            char error_msg[512];
            snprintf(error_msg, sizeof(error_msg), "Failed to get workspace ID for '%s'", monitor);
            notify_error("change_wallpaper", error_msg);
            continue;
        }
        
        /* Skip if workspace unchanged since last check */
        if (state->initialized && state->previous_workspace_id == workspace_id) {
            continue;
        }
        
        char wallpaper[MAX_PATH_LEN];
        if (!get_wallpaper_for_workspace(monitor, workspace_id, wallpaper, sizeof(wallpaper))) {
            char error_msg[512];
            snprintf(error_msg, sizeof(error_msg), "No wallpaper config for '%s' workspace %d", monitor, workspace_id);
            notify_error("change_wallpaper", error_msg);
            continue;
        }
        
        /* Skip if wallpaper path unchanged (workspace switch but same wallpaper) */
        if (state->initialized && strcmp(wallpaper, state->current_wallpaper) == 0) {
            state->previous_workspace_id = workspace_id;
            continue;
        }
        
        char expanded_wallpaper[MAX_PATH_LEN];
        expand_path(wallpaper, expanded_wallpaper, sizeof(expanded_wallpaper));
        
        /* Write current wallpaper to tracking file */
        char current_conf[MAX_PATH_LEN];
        snprintf(current_conf, sizeof(current_conf), "%s/hyprpaper/config/current.conf", hypr_dir);
        FILE* fp = fopen(current_conf, "w");
        if (fp) {
            fprintf(fp, "%s\n", expanded_wallpaper);
            fclose(fp);
        } else {
            char error_msg[512];
            snprintf(error_msg, sizeof(error_msg), "Failed to write %s: %s", current_conf, strerror(errno));
            notify_error("change_wallpaper", error_msg);
        }
        
        kill_wallpaper_script();
        
        /* Execute wallpaper change script */
        char cmd[MAX_PATH_LEN * 2];
        snprintf(cmd, sizeof(cmd), "%s/hyprpaper/w.sh '%s' '%s' &", hypr_dir, monitor, expanded_wallpaper);
        system(cmd);
        
        /* Update monitor state */
        strncpy(state->current_wallpaper, wallpaper, MAX_PATH_LEN - 1);
        state->previous_workspace_id = workspace_id;
        state->initialized = true;
    }
}

/*
 * Connect to Hyprland event socket
 * Returns socket file descriptor or -1 on error
 */
int connect_to_hyprland_socket() {
    const char* runtime_dir = getenv("XDG_RUNTIME_DIR");
    const char* hypr_instance = getenv("HYPRLAND_INSTANCE_SIGNATURE");
    
    if (!runtime_dir || !hypr_instance) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "%s not set - ensure Hyprland is running",
                 !runtime_dir ? "XDG_RUNTIME_DIR" : "HYPRLAND_INSTANCE_SIGNATURE");
        notify_error("connect_to_hyprland_socket", error_msg);
        return -1;
    }
    
    char socket_path[MAX_PATH_LEN];
    snprintf(socket_path, sizeof(socket_path), "%s/hypr/%s/.socket2.sock", runtime_dir, hypr_instance);
    
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "Socket creation failed: %s", strerror(errno));
        notify_error("connect_to_hyprland_socket", error_msg);
        return -1;
    }
    
    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, socket_path, sizeof(addr.sun_path) - 1);
    
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "Connection to %s failed: %s", socket_path, strerror(errno));
        notify_error("connect_to_hyprland_socket", error_msg);
        close(sock);
        return -1;
    }
    
    return sock;
}

/*
 * Main daemon loop
 * 1. Waits for hyprpaper to start
 * 2. Sets initial wallpapers
 * 3. Connects to Hyprland event socket
 * 4. Listens for workspace/monitor changes and updates wallpapers accordingly
 */
int main() {
    const char* home = getenv("HOME");
    if (!home) {
        notify_error("main", "HOME environment variable not set");
        return 1;
    }
    
    snprintf(hypr_dir, sizeof(hypr_dir), "%s/.config/hypr", home);
    
    printf("Waiting for hyprpaper to start...\n");
    while (!is_hyprpaper_running()) {
        sleep(1);
    }
    printf("hyprpaper detected, proceeding...\n");
    
    sleep(1);

    create_config_structure();

    printf("Setting initial wallpapers...\n");
    change_wallpaper();
    
    printf("Connecting to Hyprland socket...\n");
    int sock = connect_to_hyprland_socket();
    if (sock < 0) {
        notify_error("main", "Failed to connect to Hyprland event socket");
        return 1;
    }
    
    printf("Listening for workspace changes...\n");
    
    FILE* sock_file = fdopen(sock, "r");
    if (!sock_file) {
        char error_msg[512];
        snprintf(error_msg, sizeof(error_msg), "fdopen failed: %s", strerror(errno));
        notify_error("main", error_msg);
        close(sock);
        return 1;
    }
    
    char buffer[MAX_LINE_LEN];
    while (fgets(buffer, sizeof(buffer), sock_file)) {
        buffer[strcspn(buffer, "\n")] = 0;
        
        if (strstr(buffer, "workspace>>") || strstr(buffer, "focusedmon>>")) {
            printf("Workspace/Monitor change detected, updating wallpaper...\n");
            change_wallpaper();
        }
    }
    
    fclose(sock_file);
    return 0;
}
