#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

/* Run argv synchronously, return exit code (or -1 on fork/wait error).
 * When null_io is true, child stdout/stderr go to /dev/null. */
static int run_wait_io(char *const argv[], bool null_io) {
    pid_t pid = fork();
    if (pid < 0) {
        return -1;
    }
    if (pid == 0) {
        if (null_io) {
            FILE *devnull = fopen("/dev/null", "w");
            if (devnull) {
                dup2(fileno(devnull), STDOUT_FILENO);
                dup2(fileno(devnull), STDERR_FILENO);
            }
        }
        execvp(argv[0], argv);
        _exit(127);
    }
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
    }
    if (WIFEXITED(status)) {
        return WEXITSTATUS(status);
    }
    return -1;
}

/* Double-fork detach: grandchild is reparented to init, so no zombie. */
static void spawn_detached(char *const argv[]) {
    pid_t pid = fork();
    if (pid < 0) {
        return;
    }
    if (pid == 0) {
        if (fork() == 0) {
            execvp(argv[0], argv);
            _exit(127);
        }
        _exit(0);
    }
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
    }
}

/* Run argv, capture first line of stdout into buf. Returns true on
 * exit-code 0 with readable output. */
static bool exec_capture(char *const argv[], char *buf, size_t size) {
    int pipefd[2];
    if (pipe(pipefd) != 0) {
        return false;
    }
    pid_t pid = fork();
    if (pid < 0) {
        close(pipefd[0]);
        close(pipefd[1]);
        return false;
    }
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        FILE *devnull = fopen("/dev/null", "w");
        if (devnull) {
            dup2(fileno(devnull), STDERR_FILENO);
        }
        execvp(argv[0], argv);
        _exit(127);
    }
    close(pipefd[1]);
    FILE *fp = fdopen(pipefd[0], "r");
    bool ok = fp && fgets(buf, (int)size, fp) != NULL;
    if (fp) {
        fclose(fp);
    } else {
        close(pipefd[0]);
    }
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
    }
    return ok && WIFEXITED(status) && WEXITSTATUS(status) == 0;
}

static void send_notification(const char *title, const char *message,
                              const char *action_title, char *const action[]) {
    int pipefd[2];
    if (pipe(pipefd) != 0) {
        return;
    }
    pid_t pid = fork();
    if (pid < 0) {
        close(pipefd[0]);
        close(pipefd[1]);
        return;
    }
    if (pid == 0) {
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        char action_arg[256];
        snprintf(action_arg, sizeof(action_arg), "--action=update=%s", action_title);
        execlp("notify-send", "notify-send", title, message, action_arg, (char *)NULL);
        _exit(127);
    }
    close(pipefd[1]);
    char response[64] = {0};
    FILE *fp = fdopen(pipefd[0], "r");
    bool clicked = false;
    if (fp) {
        clicked = fgets(response, sizeof(response), fp) != NULL &&
                  strstr(response, "update") != NULL;
        fclose(fp);
    } else {
        close(pipefd[0]);
    }
    int status = 0;
    while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
    }
    if (clicked) {
        spawn_detached(action);
    }
}

static bool check_git_updates(const char *repo) {
    /* Explicit -C: cron's cwd is not guaranteed, and this box uses $HOME
     * itself as the repo. */
    char *const revparse[] = {"git", "-C", (char *)repo, "rev-parse",
                              "--is-inside-work-tree", NULL};
    if (run_wait_io(revparse, true) != 0) {
        return false;
    }

    char *const fetch[] = {"git", "-C", (char *)repo, "fetch", NULL};
    run_wait_io(fetch, true);

    char *const count[] = {"git", "-C",       (char *)repo, "rev-list",
                           "--count", "@..@{u}", NULL};
    char buf[32] = {0};
    if (!exec_capture(count, buf, sizeof(buf))) {
        return false; /* no upstream or fetch failed */
    }

    int behind = atoi(buf);
    if (behind > 0) {
        char message[256];
        snprintf(message, sizeof(message), "We are behind by %d commits.", behind);
        char update_py[1024];
        snprintf(update_py, sizeof(update_py), "%s/.config/hypr/maintenance/update.py", repo);
        char *const action[] = {"kitty", update_py, NULL};
        send_notification("Repository Update", message, "Pull Changes", action);
        return true;
    }
    return false;
}

int main(void) {
    const char *home = getenv("HOME");
    if (!home || home[0] == '\0') {
        return 0;
    }
    check_git_updates(home);

    return 0;
}
