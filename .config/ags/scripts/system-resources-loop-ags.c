#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <math.h>
#include <time.h>

typedef struct {
    unsigned long long total;
    unsigned long long idle;
} CPUStat;

typedef enum {
    GPU_NONE,
    GPU_NVIDIA,
    GPU_SYSFS
} GPUType;

static GPUType gpu_type = GPU_NONE;

typedef struct {
    double load;
    double memory_used_gb;
    double temp_c;
    int has_load;
    int has_memory;
    int has_temp;
    const char *label;
} GPUMetrics;

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

static double calculate_cpu_usage(const CPUStat *old_stat,
                                  const CPUStat *new_stat)
{
    unsigned long long delta_total = new_stat->total - old_stat->total;
    unsigned long long delta_idle  = new_stat->idle  - old_stat->idle;

    if (delta_total == 0) return 0.0;

    return 100.0 * (1.0 - (double)delta_idle / delta_total);
}

static double get_cpu_clock_ghz() {
    FILE *fp = fopen("/proc/cpuinfo", "r");
    if (!fp) return 0.0;

    char line[256];
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "cpu MHz", 7) == 0) {
            char *colon = strchr(line, ':');
            if (!colon) break;
            double mhz = atof(colon + 1);
            fclose(fp);
            return mhz / 1000.0;
        }
    }

    fclose(fp);
    return 0.0;
}

static int get_cpu_threads() {
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (int)n : 0;
}

/* ---------------- RAM ---------------- */

static int get_ram_info(double *total_gb, double *used_gb,
                        double *free_gb, double *usage_percent) {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) return 0;

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

    if (total == 0) return 0;

    double total_val = (double)total / 1024.0 / 1024.0;
    double free_val = (double)available / 1024.0 / 1024.0;
    double used_val = total_val - free_val;

    *total_gb = total_val;
    *used_gb = used_val;
    *free_gb = free_val;
    *usage_percent = 100.0 * (1.0 - (double)available / total);
    return 1;
}

/* ---------------- GPU ---------------- */

static void detect_gpu() {
    if (access("/usr/bin/nvidia-smi", X_OK) == 0 ||
        access("/bin/nvidia-smi", X_OK) == 0)
    {
        gpu_type = GPU_NVIDIA;
        return;
    }

    gpu_type = GPU_SYSFS;
}

static int read_double_from_file(const char *path, double *out) {
    FILE *fp = fopen(path, "r");
    if (!fp) return 0;
    int ok = fscanf(fp, "%lf", out) == 1;
    fclose(fp);
    return ok;
}

static int read_first_card_metric(const char *pattern, double *out) {
    char path[256];
    for (int card = 0; card < 16; card++) {
        snprintf(path, sizeof(path), pattern, card);
        if (access(path, R_OK) == 0 && read_double_from_file(path, out))
            return 1;
    }
    return 0;
}

static int read_first_temp_metric(double *out) {
    char path[256];
    for (int card = 0; card < 16; card++) {
        for (int hw = 0; hw < 16; hw++) {
            snprintf(path, sizeof(path),
                     "/sys/class/drm/card%d/device/hwmon/hwmon%d/temp1_input",
                     card, hw);
            if (access(path, R_OK) == 0 && read_double_from_file(path, out))
                return 1;
        }
    }
    return 0;
}

static int get_cpu_temp(double *temp_c) {
    char path[256];
    char name_path[256];
    char name_buf[64];
    
    // Try hwmon sensors first (more reliable for CPU temps)
    for (int hwmon = 0; hwmon < 16; hwmon++) {
        snprintf(name_path, sizeof(name_path), "/sys/class/hwmon/hwmon%d/name", hwmon);
        
        FILE *fp = fopen(name_path, "r");
        if (!fp) continue;
        
        int read_ok = (fgets(name_buf, sizeof(name_buf), fp) != NULL);
        fclose(fp);
        
        if (!read_ok) continue;
        
        // Look for CPU temperature sensors (k10temp for AMD, coretemp for Intel)
        if (strstr(name_buf, "k10temp") || 
            strstr(name_buf, "coretemp") ||
            strstr(name_buf, "cpu_thermal")) {
            
            snprintf(path, sizeof(path), "/sys/class/hwmon/hwmon%d/temp1_input", hwmon);
            double temp_milli = 0.0;
            if (read_double_from_file(path, &temp_milli)) {
                *temp_c = temp_milli / 1000.0;
                return 1;
            }
        }
    }
    
    // Fallback to thermal zones
    char type_path[256];
    char type_buf[64];
    
    for (int zone = 0; zone < 16; zone++) {
        snprintf(type_path, sizeof(type_path), "/sys/class/thermal/thermal_zone%d/type", zone);
        
        FILE *fp = fopen(type_path, "r");
        if (!fp) continue;
        
        int read_ok = (fgets(type_buf, sizeof(type_buf), fp) != NULL);
        fclose(fp);
        
        if (!read_ok) continue;
        
        // Look for CPU temperature zones
        if (strstr(type_buf, "x86_pkg_temp") || 
            strstr(type_buf, "coretemp") ||
            strstr(type_buf, "cpu_thermal")) {
            
            snprintf(path, sizeof(path), "/sys/class/thermal/thermal_zone%d/temp", zone);
            double temp_milli = 0.0;
            if (read_double_from_file(path, &temp_milli)) {
                *temp_c = temp_milli / 1000.0;
                return 1;
            }
        }
    }
    
    return 0;
}

static GPUMetrics get_gpu_metrics() {
    GPUMetrics m = {0};
    m.label = "GPU";

    if (gpu_type == GPU_NVIDIA) {
        FILE *fp = popen(
            "nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu "
            "--format=csv,noheader,nounits | head -n1",
            "r");

        if (!fp) return m;

        double util = 0.0, mem_mb = 0.0, temp = 0.0;
        int parsed = fscanf(fp, " %lf , %lf , %lf", &util, &mem_mb, &temp);
        pclose(fp);

        m.label = "GPU (NVIDIA)";
        if (parsed >= 1) {
            m.load = util;
            m.has_load = 1;
        }
        if (parsed >= 2) {
            m.memory_used_gb = mem_mb / 1024.0;
            m.has_memory = 1;
        }
        if (parsed >= 3) {
            m.temp_c = temp;
            m.has_temp = 1;
        }
        return m;
    }

    if (gpu_type == GPU_SYSFS) {
        double busy = 0.0, vram_bytes = 0.0, temp_milli = 0.0;

        if (read_first_card_metric(
                "/sys/class/drm/card%d/device/gpu_busy_percent", &busy)) {
            m.load = busy;
            m.has_load = 1;
        }

        if (read_first_card_metric(
                "/sys/class/drm/card%d/device/mem_info_vram_used", &vram_bytes)) {
            m.memory_used_gb = vram_bytes / 1024.0 / 1024.0 / 1024.0;
            m.has_memory = 1;
        }

        if (read_first_temp_metric(&temp_milli)) {
            m.temp_c = temp_milli / 1000.0;
            m.has_temp = 1;
        }
    }

    return m;
}

/* ---------------- JSON OUTPUT ---------------- */

static void print_number_or_null(double value, int has_value, int decimals) {
    if (!has_value || isnan(value) || isinf(value)) {
        printf("null");
        return;
    }

    if (decimals == 2)
        printf("%.2f", value);
    else
        printf("%.1f", value);
}

static void get_time_label(char *buffer, size_t size) {
    time_t now = time(NULL);
    struct tm *local = localtime(&now);
    if (!local) {
        snprintf(buffer, size, "--:--:--");
        return;
    }
    strftime(buffer, size, "%H:%M:%S", local);
}

static void print_json(double cpu_load,
                       double clock_ghz,
                       int threads,
                       double cpu_temp_c,
                       int has_cpu_temp,
                       double ram_total_gb,
                       double ram_used_gb,
                       double ram_free_gb,
                       double ram_usage,
                       GPUMetrics gpu)
{
    char updated_at[16];
    get_time_label(updated_at, sizeof(updated_at));

    printf("{");
    printf("\"cpuLoad\":%.1f,", cpu_load);
    printf("\"clockGHz\":%.2f,", clock_ghz);
    printf("\"threads\":%d,", threads);
    printf("\"cpuTempC\":");
    print_number_or_null(cpu_temp_c, has_cpu_temp, 1);
    printf(",\"ramTotalGB\":%.2f,", ram_total_gb);
    printf("\"ramUsedGB\":%.2f,", ram_used_gb);
    printf("\"ramFreeGB\":%.2f,", ram_free_gb);
    printf("\"ramUsage\":%.1f,", ram_usage);

    printf("\"gpuLoad\":");
    print_number_or_null(gpu.load, gpu.has_load, 1);
    printf(",\"gpuMemoryUsedGB\":");
    print_number_or_null(gpu.memory_used_gb, gpu.has_memory, 2);
    printf(",\"gpuTempC\":");
    print_number_or_null(gpu.temp_c, gpu.has_temp, 1);
    printf(",\"gpuLabel\":\"%s\"", gpu.label);
    printf(",\"updatedAt\":\"%s\"", updated_at);
    printf("}\n");
    fflush(stdout);
}

static void collect_and_print(const CPUStat *old_stat, const CPUStat *new_stat) {
    double cpu = calculate_cpu_usage(old_stat, new_stat);
    double clock_ghz = get_cpu_clock_ghz();
    int threads = get_cpu_threads();

    double cpu_temp_c = 0.0;
    int has_cpu_temp = get_cpu_temp(&cpu_temp_c);

    double ram_total_gb = 0.0, ram_used_gb = 0.0, ram_free_gb = 0.0, ram_usage = 0.0;
    get_ram_info(&ram_total_gb, &ram_used_gb, &ram_free_gb, &ram_usage);

    GPUMetrics gpu = get_gpu_metrics();

    print_json(cpu, clock_ghz, threads, cpu_temp_c, has_cpu_temp,
               ram_total_gb, ram_used_gb, ram_free_gb, ram_usage,
               gpu);
}

/* ---------------- MAIN ---------------- */

int main(int argc, char **argv) {
    int once = (argc > 1 && strcmp(argv[1], "--once") == 0);

    detect_gpu();

    CPUStat old_stat = {0}, new_stat = {0};

    if (!read_cpu_stat(&old_stat))
        return 1;

    if (once) {
        usleep(500000);
        if (!read_cpu_stat(&new_stat))
            return 1;

        collect_and_print(&old_stat, &new_stat);
        return 0;
    }

    while (1) {
        sleep(5);

        if (!read_cpu_stat(&new_stat))
            continue;

        collect_and_print(&old_stat, &new_stat);
        old_stat = new_stat;
    }

    return 0;
}
