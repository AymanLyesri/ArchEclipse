#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

typedef struct {
    unsigned long long total;
    unsigned long long idle;
} CPUStat;

typedef enum {
    GPU_NONE,
    GPU_NVIDIA,
    GPU_AMD
} GPUType;

static GPUType gpu_type = GPU_NONE;

/* ---------------- CPU ---------------- */

static int read_cpu_stat(CPUStat *stat) {
    FILE *fp = fopen("/proc/stat", "r");
    if (!fp) return 0;

    unsigned long long user, nice, system, idle, iowait, irq, softirq, steal;

    if (fscanf(fp,
        "cpu %llu %llu %llu %llu %llu %llu %llu %llu",
        &user, &nice, &system, &idle,
        &iowait, &irq, &softirq, &steal) != 8)
    {
        fclose(fp);
        return 0;
    }

    fclose(fp);

    stat->idle = idle + iowait;
    stat->total = user + nice + system + idle +
                  iowait + irq + softirq + steal;

    return 1;
}

static double calculate_cpu_usage(const CPUStat *old,
                                  const CPUStat *new)
{
    unsigned long long delta_total = new->total - old->total;
    unsigned long long delta_idle  = new->idle  - old->idle;

    if (delta_total == 0) return 0.0;

    return 100.0 * (1.0 - (double)delta_idle / delta_total);
}

/* ---------------- RAM ---------------- */

static double get_ram_usage() {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) return 0.0;

    char key[32];
    unsigned long long value;
    char unit[16];

    unsigned long long total = 0, available = 0;

    while (fscanf(fp, "%31s %llu %15s\n", key, &value, unit) == 3) {
        if (strcmp(key, "MemTotal:") == 0)
            total = value;
        else if (strcmp(key, "MemAvailable:") == 0)
            available = value;

        if (total && available)
            break;
    }

    fclose(fp);

    if (total == 0) return 0.0;

    return 100.0 * (1.0 - (double)available / total);
}

/* ---------------- GPU ---------------- */

static void detect_gpu() {
    if (access("/usr/bin/nvidia-smi", X_OK) == 0 ||
        access("/bin/nvidia-smi", X_OK) == 0)
    {
        gpu_type = GPU_NVIDIA;
        return;
    }

    if (access("/usr/bin/sensors", X_OK) == 0 ||
        access("/bin/sensors", X_OK) == 0)
    {
        gpu_type = GPU_AMD;
        return;
    }

    gpu_type = GPU_NONE;
}

static double get_gpu_usage() {
    if (gpu_type == GPU_NVIDIA) {
        FILE *fp = popen(
            "nvidia-smi --query-gpu=utilization.gpu "
            "--format=csv,noheader,nounits",
            "r");
        if (!fp) return 0.0;

        double gpu = 0.0;
        fscanf(fp, "%lf", &gpu);
        pclose(fp);
        return gpu;
    }

    if (gpu_type == GPU_AMD) {
        FILE *fp = popen("sensors", "r");
        if (!fp) return 0.0;

        char line[256];
        double temp = 0.0;

        while (fgets(line, sizeof(line), fp)) {
            if (strstr(line, "edge:")) {
                sscanf(line, "%*s %lf", &temp);
                break;
            }
        }

        pclose(fp);
        return temp;  // temperature fallback
    }

    return 0.0;
}

/* ---------------- MAIN ---------------- */

int main() {
    detect_gpu();

    CPUStat old_stat = {0}, new_stat = {0};

    if (!read_cpu_stat(&old_stat))
        return 1;

    while (1) {
        sleep(5);  // single sleep, no internal blocking

        if (!read_cpu_stat(&new_stat))
            continue;

        double cpu = calculate_cpu_usage(&old_stat, &new_stat);
        double ram = get_ram_usage();
        double gpu = get_gpu_usage();

        printf("[%.1f,%.1f,%.1f]\n", cpu, ram, gpu);
        fflush(stdout);

        old_stat = new_stat;
    }

    return 0;
}
