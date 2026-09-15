#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define LOW_BATTERY_THRESHOLD 25

/* Read first line of a sysfs file, stripped of trailing newline. */
static bool read_sysfs_line(const char *path, char *buf, size_t size) {
    FILE *fp = fopen(path, "r");
    if (!fp) {
        return false;
    }
    bool ok = fgets(buf, (int)size, fp) != NULL;
    fclose(fp);
    if (ok) {
        buf[strcspn(buf, "\n")] = '\0';
    }
    return ok;
}

/* Locate first readable battery (BAT0, then BAT1). Returns false on
 * desktops with no battery — caller should exit quietly. */
static bool find_battery(char *dir, size_t size) {
    static const char *names[] = {"BAT0", "BAT1", NULL};
    char cap[256];
    for (int i = 0; names[i] != NULL; i++) {
        snprintf(cap, sizeof(cap), "/sys/class/power_supply/%s/capacity", names[i]);
        if (access(cap, R_OK) == 0) {
            snprintf(dir, size, "/sys/class/power_supply/%s", names[i]);
            return true;
        }
    }
    return false;
}

/* fork+exec notify-send directly: no shell, no quoting hazards. */
static void send_notification(const char *title, const char *message) {
    pid_t pid = fork();
    if (pid < 0) {
        return;
    }
    if (pid == 0) {
        execlp("notify-send", "notify-send", "-u", "critical", title, message,
               (char *)NULL);
        _exit(127);
    }
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
    }
}

int main(void) {
    char dir[256];
    if (!find_battery(dir, sizeof(dir))) {
        return 0;
    }

    char path[300], buf[64];
    snprintf(path, sizeof(path), "%s/capacity", dir);
    if (!read_sysfs_line(path, buf, sizeof(buf))) {
        return 0;
    }
    int percentage = atoi(buf);

    bool charging = true;
    snprintf(path, sizeof(path), "%s/status", dir);
    if (read_sysfs_line(path, buf, sizeof(buf))) {
        charging = strcmp(buf, "Discharging") != 0;
    }

    if (percentage > 0 && percentage <= LOW_BATTERY_THRESHOLD && !charging) {
        send_notification("Battery Low!", "Please plug in your charger.");
    }

    return 0;
}
