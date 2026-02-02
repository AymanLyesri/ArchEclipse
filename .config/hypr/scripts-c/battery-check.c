#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

#define LOW_BATTERY_THRESHOLD 25
#define CHECK_INTERVAL 120 //  seconds between checks
#define ALERT_INTERVAL 25  // seconds between alerts

bool is_charging()
{
    FILE *fp = popen("upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep 'state' | awk '{print $2}'", "r");
    if (!fp)
        return false;

    char status[16];
    if (fgets(status, sizeof(status), fp))
    {
        pclose(fp);
        return strstr(status, "discharging") == NULL;
    }
    pclose(fp);
    return false;
}

int get_battery_percentage()
{
    FILE *fp = popen("upower -i /org/freedesktop/UPower/devices/battery_BAT0 | grep 'percentage' | awk '{print $2}' | tr -d '%'", "r");
    if (!fp)
        return -1;

    int percentage = 0;
    fscanf(fp, "%d", &percentage);
    pclose(fp);
    return percentage;
}

void send_notification(const char *title, const char *message)
{
    char command[256];
    snprintf(command, sizeof(command), "notify-send -u critical '%s' '%s'", title, message);
    system(command);
}

int main()
{
    int percentage = get_battery_percentage();
    bool charging = is_charging();

    if (percentage > 0 &&
        percentage <= LOW_BATTERY_THRESHOLD &&
        !charging)
    {
        send_notification(
            "Battery Low!",
            "Please plug in your charger."
        );
    }

    return 0;
}
