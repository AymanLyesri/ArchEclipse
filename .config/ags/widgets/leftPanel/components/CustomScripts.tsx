import Gtk from "gi://Gtk?version=4.0";
import KeyBind from "../../KeyBind";
import { customScripts } from "../../../constants/customScript.constant";
import { execAsync } from "ags/process";

import Hyprland from "gi://AstalHyprland";
import { createState } from "gnim";
const hyprland = Hyprland.get_default();

export default () => {
  return (
    <scrolledwindow hexpand vexpand>
      <box
        class="custom-scripts"
        orientation={Gtk.Orientation.VERTICAL}
        hexpand
        spacing={10}
      >
        {customScripts().map((script) => {
          const [isInstalled, setIsInstalled] = createState(
            script.app ? false : true,
          );
          return (
            <box
              spacing={5}
              $={(self) => {
                if (script.app) {
                  execAsync(
                    `bash -c "command -v ${script.app} >/dev/null 2>&1 && echo true || echo false"`,
                  )
                    .then((res) => {
                      setIsInstalled(res.trim() === "true");
                    })
                    .catch(() => {
                      self.sensitive = true;
                      self.tooltipText = script.description;
                    });
                }
              }}
            >
              <button
                class="script"
                onClicked={() => {
                  script.script();
                }}
                sensitive={isInstalled}
                tooltipText={isInstalled((installed) =>
                  installed
                    ? script.description
                    : `${script.app} (Requires installation)`,
                )}
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
                visible={isInstalled((installed) => !installed)}
                tooltipText={`Install ${script.app}`}
                onClicked={() => {
                  const cmd = `bash -c 'yay -S ${script.package || script.app}; echo $?'`;
                  execAsync(`kitty -e ${cmd}`)
                    .then((output) => {
                      // Check the exit code from the output
                      const exitCode = output.trim().split("\n").pop();
                      if (exitCode === "0") {
                        setIsInstalled(true);
                      } else {
                        setIsInstalled(false);
                      }
                    })
                    .catch(() => {
                      setIsInstalled(false);
                    });
                }}
              ></button>
            </box>
          );
        })}
      </box>
    </scrolledwindow>
  );
};
