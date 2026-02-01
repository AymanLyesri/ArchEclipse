#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

double get_cpu_usage() {
    unsigned long long user1, nice1, system1, idle1, iowait1, irq1, softirq1, steal1;
    unsigned long long user2, nice2, system2, idle2, iowait2, irq2, softirq2, steal2;

    FILE *fp = fopen("/proc/stat", "r");
    if (!fp) return 0.0;
    fscanf(fp, "cpu %llu %llu %llu %llu %llu %llu %llu %llu", 
        &user1, &nice1, &system1, &idle1, &iowait1, &irq1, &softirq1, &steal1);
    fclose(fp);

    usleep(100000); // 0.1 seconds

    fp = fopen("/proc/stat", "r");
    if (!fp) return 0.0;
    fscanf(fp, "cpu %llu %llu %llu %llu %llu %llu %llu %llu", 
        &user2, &nice2, &system2, &idle2, &iowait2, &irq2, &softirq2, &steal2);
    fclose(fp);

    unsigned long long total1 = user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1;
    unsigned long long total2 = user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2;
    unsigned long long idle_total1 = idle1 + iowait1;
    unsigned long long idle_total2 = idle2 + iowait2;

    double usage = 100.0 * (1.0 - (double)(idle_total2 - idle_total1) / (double)(total2 - total1));
    return usage;
}

double get_ram_usage() {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) return 0.0;
    char line[256];
    double mem_total = 0, mem_free = 0, buffers = 0, cached = 0;

    while (fgets(line, sizeof(line), fp)) {
        if (sscanf(line, "MemTotal: %lf kB", &mem_total)) continue;
        if (sscanf(line, "MemFree: %lf kB", &mem_free)) continue;
        if (sscanf(line, "Buffers: %lf kB", &buffers)) continue;
        if (sscanf(line, "Cached: %lf kB", &cached)) continue;
    }
    fclose(fp);

    double used = mem_total - (mem_free + buffers + cached);
    return (used / mem_total) * 100.0;
}

double get_gpu_usage() {
    // Check NVIDIA first
    if (system("command -v nvidia-smi > /dev/null 2>&1") == 0) {
        FILE *fp = popen("nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits", "r");
        if (!fp) return 0.0;
        double gpu;
        fscanf(fp, "%lf", &gpu);
        pclose(fp);
        return gpu;
    } 
    // Fallback: sensors for AMD
    if (system("command -v sensors > /dev/null 2>&1") == 0) {
        FILE *fp = popen("sensors | awk '/edge:/ {print $2+0; exit}'", "r");
        if (!fp) return 0.0;
        double gpu;
        fscanf(fp, "%lf", &gpu);
        pclose(fp);
        return gpu;
    }
    return 0.0;
}

int main() {
    while (1) {
        double cpu = get_cpu_usage();
        double ram = get_ram_usage();
        double gpu = get_gpu_usage();

        printf("[%.1f, %.1f, %.1f]\n", cpu, ram, gpu);
        fflush(stdout);
        
        sleep(3);
    }
    return 0;
}
