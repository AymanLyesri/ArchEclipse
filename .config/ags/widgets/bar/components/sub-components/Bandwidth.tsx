import { createPoll } from "ags/time";
import Gtk from "gi://Gtk?version=4.0";
import { With } from "gnim";
import { formatKiloBytes } from "../../../../utils/bytes";
import { createSubprocess } from "ags/process";

export default () => {
  const bandwidth = createSubprocess(
    [0, 0, 0, 0],
    ["./assets/binaries/bandwidth-loop-ags"],
    (out, prev) => {
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
    },
  );

  return (
    <menubutton class={"bandwidth"}>
      <box class="bandwidth-button" tooltipText={"click to open"}>
        <label
          class="packet upload"
          label={bandwidth((b) => `${b[0]?.toFixed(0)}`)}
          css={bandwidth((b) => {
            // min-width based on bandwidth numbers 1 11 111 1111
            const len = b[0]?.toFixed(0).length || 1;
            return `min-width: ${len * 10}px;`;
          })}
        />
        <label class="separator" label={"-"} />
        <label
          class="packet download"
          label={bandwidth((b) => `${b[1]?.toFixed(0)}`)}
          css={bandwidth((b) => {
            // min-width based on bandwidth numbers 1 11 111 1111
            const len = b[1]?.toFixed(0).length || 1;
            return `min-width: ${len * 10}px;`;
          })}
        />
      </box>
      <popover
        $={(self) => {
          self.connect("notify::visible", () => {
            if (self.visible) self.add_css_class("popover-open");
            else if (self.get_child()) self.remove_css_class("popover-open");
          });
        }}
      >
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
