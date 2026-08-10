export interface GpuStatInterface {
  label: string;
  driver: string;
  load: number | null;
  memoryUsedGB: number | null;
  memoryTotalGB: number | null;
  tempC: number | null;
}

export interface SystemResourcesInterface {
  cpuLoad: number;
  clockGHz: number;
  threads: number;
  cpuTempC: number | null;
  ramTotalGB: number;
  ramUsedGB: number;
  ramFreeGB: number;
  ramUsage: number;
  gpus: GpuStatInterface[];
  updatedAt: string;
}
