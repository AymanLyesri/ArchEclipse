import Gtk from "gi://Gtk?version=4.0";
import KeyBind from "../../KeyBind";
import { execAsync } from "ags/process";
import { createState, For, With } from "gnim";

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
      $={(self) => {
        execAsync(`bash -c "./scripts/get-keybinds.sh"`)
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
            spacing={15}
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
                  xalign={0}
                />
                {binds.map((bind) => (
                  <box class="keybind-box" spacing={5}>
                    <label
                      class="keybind-description"
                      label={bind.description}
                      wrap
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
