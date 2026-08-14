#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <errno.h>
#include <time.h>

/* Streams relative vertical mouse motion aggregated over ~30ms windows,
 * one signed integer per line (PS/2 convention: positive = upward).
 * Consumed by the bar's edge reveal to measure how hard the pointer is
 * pushed against a screen edge while the cursor itself is pinned. */

static long long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000LL + ts.tv_nsec / 1000000;
}

int main(void) {
    int fd = open("/dev/input/mice", O_RDONLY | O_NONBLOCK);
    if (fd < 0) return 1;

    struct pollfd pfd = { .fd = fd, .events = POLLIN, .revents = 0 };
    signed char packet[3];
    int accumulated = 0;
    long long last_flush = now_ms();

    while (1) {
        poll(&pfd, 1, 15);

        ssize_t n;
        while ((n = read(fd, packet, sizeof(packet))) == 3) {
            accumulated += packet[2];
        }
        if (n < 0 && errno != EAGAIN && errno != EWOULDBLOCK) return 1;

        long long now = now_ms();
        if (now - last_flush >= 30) {
            if (accumulated != 0) {
                printf("%d\n", accumulated);
                fflush(stdout);
                accumulated = 0;
            }
            last_flush = now;
        }
    }

    return 0;
}
