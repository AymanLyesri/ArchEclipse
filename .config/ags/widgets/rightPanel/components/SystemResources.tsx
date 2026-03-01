import Gtk from "gi://Gtk?version=4.0";
import { Accessor, createState, With } from "ags";
import { execAsync } from "ags/process";
import { globalSettings, systemResourcesData } from "../../../variables";

interface SystemResourcesData {
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

const POLL_MS = 5000;
const SCRIPT_PATH = "/tmp/ags/system-resources-loop-ags";

function formatOptionalNumber(
  value: number | null | undefined,
  suffix: string,
): string {
  return value === null || value === undefined ? "N/A" : `${value}${suffix}`;
}

function getNowTimeLabel(): string {
  return new Date().toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

export default ({
  className,
  orientation,
}: {
  className?: string | Accessor<string>;
  orientation?: Gtk.Orientation;
}) => {
  const [data, setData] = createState<SystemResourcesData>({
    cpuLoad: 0,
    clockGHz: 0,
    threads: 0,
    cpuTempC: null,
    ramTotalGB: 0,
    ramUsedGB: 0,
    ramFreeGB: 0,
    gpuLoad: null,
    gpuMemoryUsedGB: null,
    gpuTempC: null,
    gpuLabel: "GPU",
    updatedAt: "--:--:--",
  });

  return (
    <box
      class={`system-resources ${className ?? ""}`}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
    >
      <With value={systemResourcesData}>
        {(stats) => (
          <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
            <box class="header" spacing={8}>
              <label
                class="title"
                label="System Resources"
                hexpand
                halign={Gtk.Align.START}
              />
              <label
                class="updated-at"
                label={`Updated: ${stats?.updatedAt}`}
                xalign={1}
              />
            </box>
            <box
              class="resource-columns"
              spacing={10}
              orientation={globalSettings(({ rightPanel }) =>
                (orientation ?? rightPanel.width < 400)
                  ? Gtk.Orientation.VERTICAL
                  : Gtk.Orientation.HORIZONTAL,
              )}
            >
              <box
                class="resource-column cpu"
                orientation={Gtk.Orientation.VERTICAL}
                spacing={6}
                hexpand
              >
                <label class="column-title" label="CPU" xalign={0} />
                <label
                  class="metric"
                  label={`Load: ${stats?.cpuLoad.toFixed(1)}%`}
                  xalign={0}
                />
                <label
                  class="metric"
                  label={`Clock: ${stats?.clockGHz.toFixed(2)} GHz`}
                  xalign={0}
                />
                <label
                  class="metric"
                  label={`Temp: ${formatOptionalNumber(stats?.cpuTempC, "°C")}`}
                  xalign={0}
                />
              </box>

              <box
                class="resource-column ram"
                orientation={Gtk.Orientation.VERTICAL}
                spacing={6}
                hexpand
              >
                <label class="column-title" label="RAM" xalign={0} />
                <label
                  class="metric"
                  label={`Total: ${stats?.ramTotalGB.toFixed(2)} GB`}
                  xalign={0}
                />
                <label
                  class="metric"
                  label={`Used: ${stats?.ramUsedGB.toFixed(2)} GB`}
                  xalign={0}
                />
                <label
                  class="metric"
                  label={`Free: ${stats?.ramFreeGB.toFixed(2)} GB`}
                  xalign={0}
                />
              </box>

              <box
                class="resource-column gpu"
                orientation={Gtk.Orientation.VERTICAL}
                spacing={6}
                hexpand
              >
                <label
                  class="column-title"
                  label={stats?.gpuLabel}
                  xalign={0}
                />
                <label
                  class="metric"
                  label={`Load: ${formatOptionalNumber(stats?.gpuLoad, "%")}`}
                  xalign={0}
                />
                <label
                  class="metric"
                  label={`Memory: ${formatOptionalNumber(stats?.gpuMemoryUsedGB, " GB")}`}
                  xalign={0}
                />
                <label
                  class="metric"
                  label={`Temp: ${formatOptionalNumber(stats?.gpuTempC, "°C")}`}
                  xalign={0}
                />
              </box>
            </box>
          </box>
        )}
      </With>
    </box>
  );
};
