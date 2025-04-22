#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

// 5 hour in seconds
#define CHECK_INTERVAL (5 * 60 * 60)
#define MAX_UPDATES 1000

void send_notification(const char *title, const char *message, const char *action)
{
    char command[512];
    snprintf(command, sizeof(command),
             "notify-send \"%s\" \"%s\" --hint=string:actions:'[[\"%s\", \"%s\"]]'",
             title, message, action, action);
    system(command);
}

bool check_pacman_updates()
{
    FILE *fp = popen("yay -Qu 2>/dev/null", "r");
    if (!fp)
        return false;

    char buffer[256];
    int update_count = 0;

    while (fgets(buffer, sizeof(buffer), fp))
    {
        update_count++;
        if (update_count >= MAX_UPDATES)
            break;
    }
    pclose(fp);

    if (update_count > 0)
    {
        char message[256];
        snprintf(message, sizeof(message), "There are %d updates available.", update_count);
        send_notification("System Update", message, "kitty sudo pacman -Syu");
        return true;
    }
    return false;
}

bool check_git_updates()
{
    // First check if we're in a git repo
    if (system("git rev-parse --is-inside-work-tree >/dev/null 2>&1") != 0)
    {
        return false;
    }

    system("git fetch >/dev/null 2>&1");

    FILE *fp = popen("git rev-list --count @..@{u} 2>/dev/null", "r");
    if (!fp)
        return false;

    int behind = 0;
    fscanf(fp, "%d", &behind);
    pclose(fp);

    if (behind > 0)
    {
        char message[256];
        snprintf(message, sizeof(message), "We are behind by %d commits.", behind);
        send_notification("Repository Update", message, "kitty git pull");
        return true;
    }
    return false;
}

int main()
{
    do
    {
        check_pacman_updates();
        check_git_updates();
        sleep(CHECK_INTERVAL);
    } while (1);

    return 0;
}