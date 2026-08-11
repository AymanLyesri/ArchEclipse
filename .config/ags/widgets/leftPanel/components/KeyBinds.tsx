import { Gtk } from "ags/gtk4";
import Pango from "gi://Pango";
import KeyBind from "../../KeyBind";
import { execAsync } from "ags/process";
import { createState, For, With } from "gnim";
import GLib from "gi://GLib";

interface KeyBinds {
  [category: string]: {
    description: string;
    keys: string[];
  }[];
}

export default () => {
  const [keyBinds, setKeyBinds] = createState<KeyBinds>({});

  return (
    <scrolledwindow
      hexpand
      vexpand
      hscrollbarPolicy={Gtk.PolicyType.NEVER}
      vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
      $={(self) => {
        execAsync(
          `bash -c "${GLib.get_home_dir()}/.config/ags/scripts/get-keybinds.sh"`,
        )
          .then(JSON.parse)
          .then((keyBinds: KeyBinds) => {
            setKeyBinds(keyBinds);
          })
          .catch((err) => {
            console.error("Failed to load keybinds:", err);
          });
      }}
    >
      <With value={keyBinds}>
        {(keybinds) => (
          <box
            class="keybinds"
            orientation={Gtk.Orientation.VERTICAL}
            hexpand
            spacing={10}
          >
            {Object.entries(keybinds).map(([category, binds]) => (
              <box
                class="keybind-category"
                orientation={Gtk.Orientation.VERTICAL}
                hexpand
                spacing={5}
              >
                <label
                  class="keybind-category-title"
                  label={category}
                  tooltipText={category}
                  ellipsize={Pango.EllipsizeMode.END}
                  maxWidthChars={22}
                  xalign={0}
                />
                {binds.map((bind) => (
                  <box class="keybind-box" spacing={5}>
                    <label
                      class="keybind-description"
                      label={bind.description}
                      tooltipText={bind.description}
                      ellipsize={Pango.EllipsizeMode.END}
                      maxWidthChars={22}
                      hexpand
                      xalign={0}
                    />
                    <KeyBind bindings={bind.keys} />
                  </box>
                ))}
              </box>
            ))}
          </box>
        )}
      </With>
    </scrolledwindow>
  );
};
