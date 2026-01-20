import Gtk from "gi://Gtk?version=4.0";
import KeyBind from "../../KeyBind";
import { customScripts } from "../../../constants/customScript.constant";
import { execAsync } from "ags/process";

import Hyprland from "gi://AstalHyprland";
import { createState, For } from "gnim";
const hyprland = Hyprland.get_default();

export default () => {
  const [getCustomScripts, setCustomScripts] = createState(customScripts());

  return (
    <scrolledwindow hexpand vexpand>
      <box
        class="custom-scripts"
        orientation={Gtk.Orientation.VERTICAL}
        hexpand
        spacing={10}
      >
        <For each={getCustomScripts}>
          {(script) => (
            <box spacing={5}>
              <button
                class="script"
                onClicked={() => {
                  script.script();
                }}
                $={(self) => {
                  if (script.app) {
                    execAsync(
                      `bash -c "command -v ${script.app} >/dev/null 2>&1 && echo true || echo false"`,
                    )
                      .then((res) => {
                        self.sensitive = res.trim() === "true";
                        self.tooltipText =
                          res.trim() === "true"
                            ? script.description
                            : `${script.app} (Requires installation)`;
                      })
                      .catch(() => {
                        self.sensitive = true;
                        self.tooltipText = script.description;
                      });
                  }
                }}
              >
                <box spacing={10}>
                  <label
                    class="icon"
                    halign={Gtk.Align.START}
                    wrap
                    label={`${script.icon}`}
                  />
                  <label
                    class="name"
                    halign={Gtk.Align.START}
                    wrap
                    wrapMode={Gtk.WrapMode.WORD_CHAR}
                    label={script.name}
                    hexpand
                  />
                  {script.keybind && <KeyBind bindings={script.keybind} />}
                </box>
              </button>
              <button
                class="install-button"
                label=""
                visible={false}
                tooltipText={`Install ${script.app}`}
                $={(self) => {
                  if (script.app) {
                    execAsync(
                      `bash -c "command -v ${script.app} >/dev/null 2>&1 && echo true || echo false"`,
                    )
                      .then((res) => {
                        self.visible = res.trim() === "false";
                      })
                      .catch(() => {
                        self.visible = true;
                      });
                  }
                }}
                onClicked={() => {
                  const cmd = `bash -c 'yay -S ${script.package || script.app}'`;
                  execAsync(`kitty -e ${cmd}`)
                    .then((output) => {
                      setCustomScripts(customScripts());
                    })
                    .catch(() => {});
                }}
              ></button>
            </box>
          )}
        </For>
      </box>
    </scrolledwindow>
  );
};
