import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import Gtk from "gi://Gtk?version=3.0";

const customScripts = [
  {
    name: "HyprPicker",
    icon: "",
    description: "Color Picker for Hyprland",
    script: () => {
      execAsync("hyprpicker")
        .then((res) => {
          execAsync(`wl-copy "${res}"`);
        })
        .catch((err) => notify({ summary: "HyprPicker", body: err }));
    },
  },
  {
    name: "Change Resolution",
    icon: "󰍹",
    description: "Change Resolution",
    script: () => {
      execAsync(
        `bash -c "kitty $HOME/.config/hypr/scripts/change-resolution.sh"`
      ).catch((err) => notify({ summary: "Resolution", body: err }));
    },
  },
  {
    name: "Update Packages",
    icon: "󰏗",
    description: "Update Packages (pac-man)",
    script: () => {
      execAsync(`bash -c "kitty sudo pacman -Syu"`).catch((err) =>
        notify({ summary: "Update", body: err })
      );
    },
  },
];

export default () => {
  return (
    <box class="custom-scripts" vertical hexpand spacing={10}>
      {customScripts.map((script) => (
        <eventbox
          class={"script-eventbox"}
          onClick={() => {
            script.script();
          }}
          child={
            <box class="script" spacing={10}>
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
                label={script.name}
              />
            </box>
          }
        />
      ))}
    </box>
  );
};
