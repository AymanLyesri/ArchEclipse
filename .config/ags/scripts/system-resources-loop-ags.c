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

#define MAX_GPUS 8

typedef struct {
    char label[96];
    char driver[32];
    double load;
    double memory_used_gb;
    double memory_total_gb;
    double temp_c;
    int has_load;
    int has_memory_used;
    int has_memory_total;
    int has_temp;
} GPUInfo;

static int nvidia_available = 0;
static int sysfs_cards[MAX_GPUS];
static int sysfs_card_count = 0;

/* ---------------- CPU ---------------- */

static int read_cpu_stat(CPUStat *stat) {
    FILE *fp = fopen("/proc/stat", "r");
    if (!fp) return 0;

    unsigned long long user, nice, system, idle, iowait, irq, softirq, steal;

    if (fscanf(fp, "cpu %llu %llu %llu %llu %llu %llu %llu %llu",
               &user, &nice, &system, &idle, &iowait, &irq, &softirq, &steal) != 8) {
        fclose(fp);
        return 0;
    }
    fclose(fp);

    stat->idle = idle + iowait;
    stat->total = user + nice + system + idle + iowait + irq + softirq + steal;
    return 1;
}

static double calculate_cpu_usage(const CPUStat *old_stat, const CPUStat *new_stat) {
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
            if (colon) {
                double mhz = atof(colon + 1);
                fclose(fp);
                return mhz / 1000.0;
            }
        }
    }
    fclose(fp);
    return 0.0;
}

static int get_cpu_threads() {
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (int)n : 0;
}

static int read_double_from_file(const char *path, double *out) {
    FILE *fp = fopen(path, "r");
    if (!fp) return 0;
    int ok = fscanf(fp, "%lf", out) == 1;
    fclose(fp);
    return ok;
}

static int get_cpu_temp(double *temp_c) {
    char path[256], name_path[256], name_buf[64];
    
    for (int hwmon = 0; hwmon < 32; hwmon++) {
        snprintf(name_path, sizeof(name_path), "/sys/class/hwmon/hwmon%d/name", hwmon);
        FILE *fp = fopen(name_path, "r");
        if (!fp) continue;
        
        int read_ok = (fgets(name_buf, sizeof(name_buf), fp) != NULL);
        fclose(fp);
        
        if (read_ok && (strstr(name_buf, "k10temp") || strstr(name_buf, "coretemp") || 
                        strstr(name_buf, "zenpower") || strstr(name_buf, "cpu_thermal"))) {
            snprintf(path, sizeof(path), "/sys/class/hwmon/hwmon%d/temp1_input", hwmon);
            double temp_milli = 0.0;
            if (read_double_from_file(path, &temp_milli)) {
                *temp_c = temp_milli / 1000.0;
                return 1;
            }
        }
    }
    
    char type_path[256], type_buf[64];
    for (int zone = 0; zone < 16; zone++) {
        snprintf(type_path, sizeof(type_path), "/sys/class/thermal/thermal_zone%d/type", zone);
        FILE *fp = fopen(type_path, "r");
        if (!fp) continue;
        
        int read_ok = (fgets(type_buf, sizeof(type_buf), fp) != NULL);
        fclose(fp);
        
        if (read_ok && (strstr(type_buf, "x86_pkg_temp") || strstr(type_buf, "coretemp") || strstr(type_buf, "cpu_thermal"))) {
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

/* ---------------- RAM ---------------- */

static int get_ram_info(double *total_gb, double *used_gb, double *free_gb, double *usage_percent) {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) return 0;

    char key[32], unit[16];
    unsigned long long value, total = 0, available = 0;

    while (fscanf(fp, "%31s %llu %15s\n", key, &value, unit) == 3) {
        if (strcmp(key, "MemTotal:") == 0) total = value;
        else if (strcmp(key, "MemAvailable:") == 0) available = value;
        if (total && available) break;
    }
    fclose(fp);

    if (total == 0) return 0;

    *total_gb = (double)total / 1024.0 / 1024.0;
    *free_gb = (double)available / 1024.0 / 1024.0;
    *used_gb = *total_gb - *free_gb;
    *usage_percent = 100.0 * (1.0 - (double)available / total);
    return 1;
}

/* ---------------- GPU ---------------- */

static void detect_gpus() {
    nvidia_available = (access("/usr/bin/nvidia-smi", X_OK) == 0 ||
                        access("/bin/nvidia-smi", X_OK) == 0);

    char path[256];
    for (int i = 0; i < 8 && sysfs_card_count < MAX_GPUS; i++) {
        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/gpu_busy_percent", i);
        if (access(path, R_OK) == 0) {
            sysfs_cards[sysfs_card_count++] = i;
        }
    }
}

static int read_uevent_driver(int card_index, char *out, size_t out_size) {
    char path[256];
    snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/uevent", card_index);
    FILE *fp = fopen(path, "r");
    if (!fp) return 0;

    char line[128];
    int found = 0;
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "DRIVER=", 7) == 0) {
            line[strcspn(line, "\n")] = '\0';
            snprintf(out, out_size, "%s", line + 7);
            found = 1;
            break;
        }
    }
    fclose(fp);
    return found;
}

static int parse_metric(const char *token, double *out) {
    while (*token == ' ') token++;
    char *end = NULL;
    double val = strtod(token, &end);
    if (end == token) return 0;
    *out = val;
    return 1;
}

static void copy_label_sanitized(char *dst, size_t dst_size, const char *src) {
    size_t j = 0;
    while (*src == ' ') src++;
    for (; *src && j + 1 < dst_size; src++) {
        unsigned char c = (unsigned char)*src;
        if (c == '"' || c == '\\' || c < 0x20) continue;
        dst[j++] = (char)c;
    }
    while (j > 0 && dst[j - 1] == ' ') j--;
    dst[j] = '\0';
}

/* "NVIDIA GeForce RTX 4080" -> "RTX 4080"; the vendor is already carried
 * by the driver field. Keeps the original label if stripping empties it. */
static void shorten_gpu_label(char *label, size_t label_size) {
    static const char *prefixes[] = {
        "NVIDIA ", "GeForce ", "AMD ", "Intel(R) ", "Intel ", "Radeon(TM) ",
    };
    char shortened[96];
    snprintf(shortened, sizeof(shortened), "%s", label);

    int changed = 1;
    while (changed) {
        changed = 0;
        for (size_t i = 0; i < sizeof(prefixes) / sizeof(prefixes[0]); i++) {
            size_t len = strlen(prefixes[i]);
            if (strncmp(shortened, prefixes[i], len) == 0) {
                memmove(shortened, shortened + len, strlen(shortened + len) + 1);
                changed = 1;
            }
        }
    }

    if (shortened[0] != '\0') snprintf(label, label_size, "%s", shortened);
}

static int read_gpu_temp_sysfs(int card_index, double *out) {
    char path[256];
    for (int hw = 0; hw < 8; hw++) {
        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/hwmon/hwmon%d/temp1_input", card_index, hw);
        if (access(path, R_OK) == 0 && read_double_from_file(path, out)) return 1;
    }
    return 0;
}

static int collect_nvidia_gpus(GPUInfo *gpus, int count) {
    FILE *fp = popen("nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null", "r");
    if (!fp) return count;

    char line[256];
    while (count < MAX_GPUS && fgets(line, sizeof(line), fp)) {
        char *fields[5] = {0};
        int nfields = 0;
        char *cursor = line;
        while (nfields < 5 && cursor) {
            fields[nfields++] = cursor;
            char *comma = strchr(cursor, ',');
            if (comma) { *comma = '\0'; cursor = comma + 1; }
            else cursor = NULL;
        }

        GPUInfo g = {0};
        double val = 0.0;

        copy_label_sanitized(g.label, sizeof(g.label), fields[0]);
        shorten_gpu_label(g.label, sizeof(g.label));
        if (nfields > 1 && parse_metric(fields[1], &val)) { g.load = val; g.has_load = 1; }
        if (nfields > 2 && parse_metric(fields[2], &val)) { g.memory_used_gb = val / 1024.0; g.has_memory_used = 1; }
        if (nfields > 3 && parse_metric(fields[3], &val)) { g.memory_total_gb = val / 1024.0; g.has_memory_total = 1; }
        if (nfields > 4 && parse_metric(fields[4], &val)) { g.temp_c = val; g.has_temp = 1; }

        if (g.label[0] == '\0' || !g.has_load) continue;

        snprintf(g.driver, sizeof(g.driver), "nvidia");
        gpus[count++] = g;
    }
    pclose(fp);
    return count;
}

static int collect_sysfs_gpus(GPUInfo *gpus, int count) {
    char path[256];
    for (int i = 0; i < sysfs_card_count && count < MAX_GPUS; i++) {
        int card = sysfs_cards[i];
        GPUInfo g = {0};
        double val = 0.0;

        if (!read_uevent_driver(card, g.driver, sizeof(g.driver))) {
            snprintf(g.driver, sizeof(g.driver), "unknown");
        }

        if (strcmp(g.driver, "amdgpu") == 0 || strcmp(g.driver, "radeon") == 0) {
            snprintf(g.label, sizeof(g.label), "AMD GPU");
        } else if (strcmp(g.driver, "i915") == 0 || strcmp(g.driver, "xe") == 0) {
            snprintf(g.label, sizeof(g.label), "Intel GPU");
        } else {
            snprintf(g.label, sizeof(g.label), "GPU");
        }

        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/gpu_busy_percent", card);
        if (read_double_from_file(path, &val)) { g.load = val; g.has_load = 1; }

        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/mem_info_vram_used", card);
        if (read_double_from_file(path, &val)) {
            g.memory_used_gb = val / (1024.0 * 1024.0 * 1024.0);
            g.has_memory_used = 1;
        }

        snprintf(path, sizeof(path), "/sys/class/drm/card%d/device/mem_info_vram_total", card);
        if (read_double_from_file(path, &val)) {
            g.memory_total_gb = val / (1024.0 * 1024.0 * 1024.0);
            g.has_memory_total = 1;
        }

        if (read_gpu_temp_sysfs(card, &val)) { g.temp_c = val / 1000.0; g.has_temp = 1; }

        gpus[count++] = g;
    }
    return count;
}

static int get_all_gpu_metrics(GPUInfo *gpus) {
    int count = 0;
    if (nvidia_available) count = collect_nvidia_gpus(gpus, count);
    count = collect_sysfs_gpus(gpus, count);
    return count;
}

/* ---------------- JSON OUTPUT ---------------- */

static void print_number_or_null(double value, int has_value, int decimals) {
    if (!has_value || isnan(value) || isinf(value)) {
        printf("null");
    } else {
        if (decimals == 2) printf("%.2f", value);
        else if (decimals == 1) printf("%.1f", value);
        else printf("%.0f", value);
    }
}

static void print_json(double cpu_load, double clock_ghz, int threads, double cpu_temp_c, int has_cpu_temp,
                       double ram_total_gb, double ram_used_gb, double ram_free_gb, double ram_usage,
                       const GPUInfo *gpus, int gpu_count) {
    time_t now = time(NULL);
    struct tm *t = localtime(&now);
    char updated_at[32];
    strftime(updated_at, sizeof(updated_at), "%H:%M:%S", t);

    printf("{");
    printf("\"cpuLoad\":%.1f,", cpu_load);
    printf("\"clockGHz\":%.2f,", clock_ghz);
    printf("\"threads\":%d,", threads);
    printf("\"cpuTempC\":"); print_number_or_null(cpu_temp_c, has_cpu_temp, 1); printf(",");
    
    printf("\"ramTotalGB\":%.2f,", ram_total_gb);
    printf("\"ramUsedGB\":%.2f,", ram_used_gb);
    printf("\"ramFreeGB\":%.2f,", ram_free_gb);
    printf("\"ramUsage\":%.1f,", ram_usage);

    printf("\"gpus\":[");
    for (int i = 0; i < gpu_count; i++) {
        if (i > 0) printf(",");
        printf("{\"label\":\"%s\",\"driver\":\"%s\",", gpus[i].label, gpus[i].driver);
        printf("\"load\":"); print_number_or_null(gpus[i].load, gpus[i].has_load, 1); printf(",");
        printf("\"memoryUsedGB\":"); print_number_or_null(gpus[i].memory_used_gb, gpus[i].has_memory_used, 2); printf(",");
        printf("\"memoryTotalGB\":"); print_number_or_null(gpus[i].memory_total_gb, gpus[i].has_memory_total, 2); printf(",");
        printf("\"tempC\":"); print_number_or_null(gpus[i].temp_c, gpus[i].has_temp, 1);
        printf("}");
    }
    printf("],");


    printf("\"updatedAt\":\"%s\"", updated_at);
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

    GPUInfo gpus[MAX_GPUS];
    int gpu_count = get_all_gpu_metrics(gpus);

    print_json(cpu, clock_ghz, threads, cpu_temp_c, has_cpu_temp,
               ram_total_gb, ram_used_gb, ram_free_gb, ram_usage, gpus, gpu_count);
}

/* ---------------- MAIN ---------------- */

int main(int argc, char **argv) {
    int once = (argc > 1 && strcmp(argv[1], "--once") == 0);

    detect_gpus();

    CPUStat old_stat = {0}, new_stat = {0};

    if (!read_cpu_stat(&old_stat)) return 1;

    if (once) {
        usleep(500000);
        if (!read_cpu_stat(&new_stat)) return 1;
        collect_and_print(&old_stat, &new_stat);
        return 0;
    }

    while (1) {
        sleep(5);
        if (!read_cpu_stat(&new_stat)) continue;
        collect_and_print(&old_stat, &new_stat);
        old_stat = new_stat;
    }

    return 0;
}