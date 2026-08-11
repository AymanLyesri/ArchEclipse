import { Gtk } from "ags/gtk4";
import { Accessor, With } from "ags";
import { globalSettings, systemResourcesData } from "../../../variables";

function formatOptionalNumber(
  value: number | null | undefined,
  suffix: string,
): string {
  return value === null || value === undefined ? "N/A" : `${value}${suffix}`;
}

function formatGpuMemory(used: number | null, total: number | null): string {
  if (used === null) return "N/A";
  return total === null
    ? `${used.toFixed(2)} GB`
    : `${used.toFixed(2)}/${total.toFixed(2)} GB`;
}

export default ({
  className,
  orientation,
}: {
  className?: string | Accessor<string>;
  orientation?: Gtk.Orientation;
}) => {
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
              homogeneous
              orientation={globalSettings(
                ({ rightPanel }) =>
                  orientation ??
                  (rightPanel.width < 400
                    ? Gtk.Orientation.VERTICAL
                    : Gtk.Orientation.HORIZONTAL),
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

              {(stats?.gpus ?? []).map((gpu) => (
                <box
                  class="resource-column gpu"
                  orientation={Gtk.Orientation.VERTICAL}
                  spacing={6}
                  hexpand
                >
                  <label class="column-title" label={gpu.label} xalign={0} />
                  <label
                    class="metric driver"
                    label={`Driver: ${gpu.driver}`}
                    xalign={0}
                  />
                  <label
                    class="metric"
                    label={`Load: ${formatOptionalNumber(gpu.load, "%")}`}
                    xalign={0}
                  />
                  <label
                    class="metric"
                    label={`Memory: ${formatGpuMemory(gpu.memoryUsedGB, gpu.memoryTotalGB)}`}
                    xalign={0}
                  />
                  <label
                    class="metric"
                    label={`Temp: ${formatOptionalNumber(gpu.tempC, "°C")}`}
                    xalign={0}
                  />
                </box>
              ))}
            </box>
          </box>
        )}
      </With>
    </box>
  );
};
