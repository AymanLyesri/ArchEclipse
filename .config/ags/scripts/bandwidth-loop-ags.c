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

// Structure to hold bandwidth data
typedef struct
{
    unsigned long long rx;
    unsigned long long tx;
} BandwidthData;

// Function declarations
char *get_default_interface();
char *get_log_file_path();
void ensure_log_directory_exists(const char *path);
void get_current_date(char *date_str);
void read_today_bandwidth(BandwidthData *today);
void update_today_bandwidth(const BandwidthData *data);
BandwidthData get_interface_bytes(const char *interface);
void handle_error(const char *msg, int exit_code);

int main()
{
    // Get default network interface
    char *default_iface = get_default_interface();
    if (!default_iface)
    {
        handle_error("No default route found", 1);
    }

    // Get initial bandwidth stats
    BandwidthData old = get_interface_bytes(default_iface);

    // Run forever
    while (1)
    {
        // Get today's bandwidth from log file
        BandwidthData today = {0};
        read_today_bandwidth(&today);

        // Wait for 5 seconds
        sleep(2);

        // Get new bandwidth stats
        BandwidthData new = get_interface_bytes(default_iface);

        // Calculate speeds and update totals (in KB)
        BandwidthData speed = {
            (new.rx - old.rx) / 5,  // Average per second over 5 seconds
            (new.tx - old.tx) / 5}; // Average per second over 5 seconds

        today.rx += (new.rx - old.rx);
        today.tx += (new.tx - old.tx);

        update_today_bandwidth(&today);

        // Output format: [tx_speed, rx_speed, today_tx, today_rx]
        printf("[%llu,%llu,%llu,%llu]\n", speed.tx, speed.rx, today.tx, today.rx);
        fflush(stdout); // Ensure output is immediately visible

        // Update old values for next iteration
        old = new;
    }

    free(default_iface);
    return 0;
}

char *get_default_interface()
{
    FILE *file = fopen("/proc/net/route", "r");
    if (!file)
    {
        handle_error("Unable to open /proc/net/route", 1);
    }

    char buffer[256];
    char iface[MAX_IFACE_NAME] = {0};
    unsigned long destination;

    // Skip header line
    if (!fgets(buffer, sizeof(buffer), file))
    {
        fclose(file);
        return NULL;
    }

    while (fgets(buffer, sizeof(buffer), file))
    {
        if (sscanf(buffer, "%15s %lx", iface, &destination) == 2 && destination == 0)
        {
            fclose(file);
            return strdup(iface);
        }
    }

    fclose(file);
    return NULL;
}

char *get_log_file_path()
{
    const char *home = getenv("HOME");
    if (!home)
    {
        handle_error("HOME environment variable not set", 1);
    }

    size_t path_len = strlen(home) + strlen(LOG_DIR) + strlen(LOG_FILE) + 1;
    char *path = malloc(path_len);
    if (!path)
    {
        handle_error("Memory allocation failed", 1);
    }

    snprintf(path, path_len, "%s%s%s", home, LOG_DIR, LOG_FILE);
    return path;
}

void ensure_log_directory_exists(const char *path)
{
    char *dir = strdup(path);
    if (!dir)
    {
        handle_error("Memory allocation failed", 1);
    }

    char *last_slash = strrchr(dir, '/');
    if (last_slash)
    {
        *last_slash = '\0';
        if (mkdir(dir, 0755) == -1 && errno != EEXIST)
        {
            free(dir);
            handle_error("Failed to create log directory", 1);
        }
    }
    free(dir);
}

void get_current_date(char *date_str)
{
    time_t t = time(NULL);
    struct tm tm = *localtime(&t);
    snprintf(date_str, DATE_LEN, DATE_FORMAT,
             tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday);
}

void read_today_bandwidth(BandwidthData *today)
{
    char *log_file = get_log_file_path();
    FILE *file = fopen(log_file, "r");
    free(log_file);

    if (!file)
    {
        today->rx = 0;
        today->tx = 0;
        return;
    }

    char current_date[DATE_LEN];
    get_current_date(current_date);

    char line[256];
    char date[DATE_LEN];
    BandwidthData data = {0};

    while (fgets(line, sizeof(line), file))
    {
        if (sscanf(line, "%10s %llu %llu", date, &data.tx, &data.rx) == 3)
        {
            if (strcmp(date, current_date) == 0)
            {
                *today = data;
                break;
            }
        }
    }

    fclose(file);
}

void update_today_bandwidth(const BandwidthData *data)
{
    char *log_file = get_log_file_path();
    ensure_log_directory_exists(log_file);

    char current_date[DATE_LEN];
    get_current_date(current_date);

    // Create temp file in same directory as log file
    char temp_path[PATH_MAX];
    snprintf(temp_path, sizeof(temp_path), "%s.tmp", log_file);

    FILE *temp = fopen(temp_path, "w");
    if (!temp)
    {
        free(log_file);
        handle_error("Failed to create temp file", 1);
    }

    // Process existing log file
    FILE *file = fopen(log_file, "r");
    if (file)
    {
        char line[256];
        char date[DATE_LEN];
        while (fgets(line, sizeof(line), file))
        {
            if (sscanf(line, "%10s", date) == 1 &&
                strcmp(date, current_date) != 0)
            {
                fputs(line, temp);
            }
        }
        fclose(file);
    }

    // Write current data
    fprintf(temp, "%s %llu %llu\n", current_date, data->tx, data->rx);
    fclose(temp);

    // Replace old file with new one
    if (rename(temp_path, log_file))
    {
        unlink(temp_path);
        free(log_file);
        handle_error("Failed to update log file", 1);
    }

    free(log_file);
}

BandwidthData get_interface_bytes(const char *interface)
{
    FILE *file = fopen("/proc/net/dev", "r");
    if (!file)
    {
        handle_error("Unable to open /proc/net/dev", 1);
    }

    char buffer[256];
    BandwidthData data = {0};
    int found = 0;

    // Skip header lines
    fgets(buffer, sizeof(buffer), file);
    fgets(buffer, sizeof(buffer), file);

    while (fgets(buffer, sizeof(buffer), file))
    {
        char iface[128];
        unsigned long long stats[16];

        if (sscanf(buffer,
                   " %127[^:]: %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu %llu",
                   iface,
                   &stats[0], &stats[1], &stats[2], &stats[3], &stats[4], &stats[5], &stats[6], &stats[7],
                   &stats[8], &stats[9], &stats[10], &stats[11], &stats[12], &stats[13], &stats[14], &stats[15]) == 17)
        {
            // Trim leading spaces from interface name
            char *trimmed = iface;
            while (*trimmed == ' ')
                trimmed++;

            if (strcmp(trimmed, interface) == 0)
            {
                data.rx = stats[0];
                data.tx = stats[8];
                found = 1;
                break;
            }
        }
    }

    fclose(file);

    if (!found)
    {
        fprintf(stderr, "Interface %s not found!\n", interface);
        exit(1);
    }

    return data;
}

void handle_error(const char *msg, int exit_code)
{
    fprintf(stderr, "Error: %s\n", msg);
    exit(exit_code);
}