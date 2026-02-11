#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/stat.h>
#include <limits.h>
#include <errno.h>

#define MAX_IFACE_NAME 16
#define LOG_DIR "/.config/ags/logs/"
#define LOG_FILE "bandwidth.log"
#define DATE_FORMAT "%04d-%02d-%02d"
#define DATE_LEN 11

typedef struct {
    unsigned long long rx;
    unsigned long long tx;
} BandwidthData;

typedef struct {
    char iface[MAX_IFACE_NAME];
    char log_path[PATH_MAX];
} AppContext;

/* ---------- Utility ---------- */

static void handle_error(const char *msg, int exit_code) {
    fprintf(stderr, "Error: %s\n", msg);
    exit(exit_code);
}

static double seconds_delta(struct timespec *a, struct timespec *b) {
    return (b->tv_sec - a->tv_sec) +
           (b->tv_nsec - a->tv_nsec) / 1e9;
}

static void get_current_date(char *date_str) {
    time_t t = time(NULL);
    struct tm tm = *localtime(&t);
    snprintf(date_str, DATE_LEN, DATE_FORMAT,
             tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
}

/* ---------- Interface detection ---------- */

static char *get_default_interface() {
    FILE *file = fopen("/proc/net/route", "r");
    if (!file)
        handle_error("Unable to open /proc/net/route", 1);

    char buffer[256];
    char iface[MAX_IFACE_NAME] = {0};
    unsigned long destination;

    fgets(buffer, sizeof(buffer), file); // skip header

    while (fgets(buffer, sizeof(buffer), file)) {
        if (sscanf(buffer, "%15s %lx", iface, &destination) == 2 &&
            destination == 0) {
            fclose(file);
            return strdup(iface);
        }
    }

    fclose(file);
    return NULL;
}

/* ---------- Path helpers ---------- */

static char *get_log_file_path() {
    const char *home = getenv("HOME");
    if (!home)
        handle_error("HOME environment variable not set", 1);

    size_t len = strlen(home) + strlen(LOG_DIR) + strlen(LOG_FILE) + 1;
    char *path = malloc(len);
    if (!path)
        handle_error("Memory allocation failed", 1);

    snprintf(path, len, "%s%s%s", home, LOG_DIR, LOG_FILE);
    return path;
}

static void ensure_log_directory_exists(const char *path) {
    char dir[PATH_MAX];
    strncpy(dir, path, PATH_MAX);

    char *last = strrchr(dir, '/');
    if (last) {
        *last = '\0';
        if (mkdir(dir, 0755) == -1 && errno != EEXIST)
            handle_error("Failed to create log directory", 1);
    }
}

static void init_context(AppContext *ctx) {
    char *i = get_default_interface();
    if (!i)
        handle_error("No default route found", 1);

    strncpy(ctx->iface, i, MAX_IFACE_NAME);
    free(i);

    char *p = get_log_file_path();
    strncpy(ctx->log_path, p, PATH_MAX);
    free(p);

    ensure_log_directory_exists(ctx->log_path);
}

/* ---------- Fast /proc/net/dev parser ---------- */

static inline int fast_parse_dev(const char *line,
                                const char *iface,
                                BandwidthData *out) {
    const char *p = strchr(line, ':');
    if (!p) return 0;

    size_t len = p - line;
    while (len && line[0] == ' ') { line++; len--; }

    if (strncmp(line, iface, len) != 0 || iface[len] != '\0')
        return 0;

    p++; // after ':'

    unsigned long long rx, tx;
    if (sscanf(p, "%llu %*u %*u %*u %*u %*u %*u %*u %llu",
               &rx, &tx) == 2) {
        out->rx = rx;
        out->tx = tx;
        return 1;
    }
    return 0;
}

static BandwidthData get_interface_bytes(const char *iface) {
    FILE *file = fopen("/proc/net/dev", "r");
    if (!file)
        handle_error("Unable to open /proc/net/dev", 1);

    char buffer[256];
    BandwidthData data = {0};
    int found = 0;

    fgets(buffer, sizeof(buffer), file); // skip headers
    fgets(buffer, sizeof(buffer), file);

    while (fgets(buffer, sizeof(buffer), file)) {
        if (fast_parse_dev(buffer, iface, &data)) {
            found = 1;
            break;
        }
    }

    fclose(file);

    if (!found)
        handle_error("Interface not found in /proc/net/dev", 1);

    return data;
}

/* ---------- Log handling ---------- */

static void read_today_bandwidth(const char *path,
                                 BandwidthData *today) {
    FILE *file = fopen(path, "r");
    if (!file) {
        today->rx = today->tx = 0;
        return;
    }

    char current_date[DATE_LEN];
    get_current_date(current_date);

    char line[256];
    char date[DATE_LEN];
    BandwidthData data = {0};

    while (fgets(line, sizeof(line), file)) {
        if (sscanf(line, "%10s %llu %llu",
                   date, &data.tx, &data.rx) == 3) {
            if (strcmp(date, current_date) == 0) {
                *today = data;
                break;
            }
        }
    }

    fclose(file);
}

static void update_today_bandwidth(const char *path,
                                   const BandwidthData *data) {
    char current_date[DATE_LEN];
    get_current_date(current_date);

    char temp_path[PATH_MAX];
    snprintf(temp_path, sizeof(temp_path), "%s.tmp", path);

    FILE *temp = fopen(temp_path, "w");
    if (!temp)
        handle_error("Failed to create temp file", 1);

    FILE *file = fopen(path, "r");
    if (file) {
        char line[256];
        char date[DATE_LEN];

        while (fgets(line, sizeof(line), file)) {
            if (sscanf(line, "%10s", date) == 1 &&
                strcmp(date, current_date) != 0) {
                fputs(line, temp);
            }
        }
        fclose(file);
    }

    fprintf(temp, "%s %llu %llu\n",
            current_date, data->tx, data->rx);
    fclose(temp);

    if (rename(temp_path, path)) {
        unlink(temp_path);
        handle_error("Failed to update log file", 1);
    }
}

/* ---------- MAIN ---------- */

int main() {
    AppContext ctx;
    init_context(&ctx);

    BandwidthData old = get_interface_bytes(ctx.iface);

    struct timespec t1, t2;
    clock_gettime(CLOCK_MONOTONIC, &t1);

    BandwidthData today = {0};
    read_today_bandwidth(ctx.log_path, &today);

    while (1) {
        usleep(3000000);   // 3s: low CPU + smooth updates

        clock_gettime(CLOCK_MONOTONIC, &t2);
        double dt = seconds_delta(&t1, &t2);
        t1 = t2;

        BandwidthData now = get_interface_bytes(ctx.iface);

        unsigned long long d_rx = now.rx - old.rx;
        unsigned long long d_tx = now.tx - old.tx;

        BandwidthData speed = {
            (unsigned long long)(d_rx / dt),
            (unsigned long long)(d_tx / dt)
        };

        today.rx += d_rx;
        today.tx += d_tx;

        update_today_bandwidth(ctx.log_path, &today);

        printf("[%llu,%llu,%llu,%llu]\n",
               speed.tx, speed.rx,
               today.tx, today.rx);
        fflush(stdout);

        old = now;
    }

    return 0;
}
