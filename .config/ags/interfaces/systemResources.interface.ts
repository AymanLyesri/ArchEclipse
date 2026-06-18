export interface SystemResourcesInterface {
  cpuLoad: number;
  clockGHz: number;
  threads: number;
  cpuTempC: number | null;
  ramTotalGB: number;
  ramUsedGB: number;
  ramFreeGB: number;
  gpuLoad: number | null;
  gpuMemoryUsedGB: number | null;
  gpuTempC: number | null;
  gpuLabel: string;
  updatedAt: string;
}
