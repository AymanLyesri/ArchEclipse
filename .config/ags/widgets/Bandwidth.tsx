import { createPoll } from "ags/time";
import Gtk from "gi://Gtk?version=4.0";
import { With } from "gnim";

const BANDWIDTH_POLL_MS = 2000; // bandwidth poll period (increase to reduce CPU)

export default () => {
  const bandwidth = createPoll(
    [],
    BANDWIDTH_POLL_MS,
    ["./assets/binaries/bandwidth"],
    (out) => {
      try {
        const parsed = JSON.parse(out);
        return [
          Math.round((parsed[0] / 1024) * 100) / 100,
          Math.round((parsed[1] / 1024) * 100) / 100,
          Math.round((parsed[2] / 1024) * 100) / 100,
          Math.round((parsed[3] / 1024) * 100) / 100,
        ];
      } catch (e) {
        return [0, 0, 0, 0];
      }
    }
  );

  function formatKiloBytes(kb: number): string {
    if (kb === undefined || kb === null || isNaN(kb)) {
      return "0.0 KB";
    }
    const units = ["KB", "MB", "GB", "TB"];
    let idx = 0;
    let val = kb;
    while (val >= 1024 && idx < units.length - 1) {
      val /= 1024;
      idx++;
    }
    return `${val.toFixed(2)} ${units[idx]}`;
  }

  return (
    <menubutton class={"bandwidth"}>
      <box class="bandwidth-button" spacing={3} tooltipText={"click to open"}>
        <label class="packet upload" label={bandwidth((b) => `${b[0]}`)} />
        <label class="separator" label={"-"} />
        <label class="packet download" label={bandwidth((b) => `${b[1]}`)} />
      </box>
      <popover>
        <box
          class="bandwidth-popover"
          spacing={12}
          orientation={Gtk.Orientation.VERTICAL}
        >
          <label class="bandwidth-heading" label="Network Statistics" />
          <With value={bandwidth}>
            {(b) => {
              if (!b || b.length !== 4)
                return <label label="Network data unavailable" />;

              return (
                <box spacing={12}>
                  <box
                    class="bandwidth-section"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={8}
                  >
                    <label class="bandwidth-subheading" label="Upload" />
                    <box class="bandwidth-detail" spacing={8}>
                      <box
                        class="bandwidth-item"
                        orientation={Gtk.Orientation.VERTICAL}
                        spacing={2}
                        hexpand
                      >
                        <label class="bandwidth-label" label="Packets" />
                        <label class="bandwidth-value" label={`${b[0]}`} />
                      </box>
                      <box
                        class="bandwidth-item"
                        orientation={Gtk.Orientation.VERTICAL}
                        spacing={2}
                        hexpand
                      >
                        <label class="bandwidth-label" label="Data" />
                        <label
                          class="bandwidth-value"
                          label={formatKiloBytes(b[2])}
                        />
                      </box>
                    </box>
                  </box>

                  <box
                    class="bandwidth-section"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={8}
                  >
                    <label class="bandwidth-subheading" label="Download" />
                    <box class="bandwidth-detail" spacing={8}>
                      <box
                        class="bandwidth-item"
                        orientation={Gtk.Orientation.VERTICAL}
                        spacing={2}
                        hexpand
                      >
                        <label class="bandwidth-label" label="Packets" />
                        <label class="bandwidth-value" label={`${b[1]}`} />
                      </box>
                      <box
                        class="bandwidth-item"
                        orientation={Gtk.Orientation.VERTICAL}
                        spacing={2}
                        hexpand
                      >
                        <label class="bandwidth-label" label="Data" />
                        <label
                          class="bandwidth-value"
                          label={formatKiloBytes(b[3])}
                        />
                      </box>
                    </box>
                  </box>
                </box>
              );
            }}
          </With>
        </box>
      </popover>
    </menubutton>
  );
};
