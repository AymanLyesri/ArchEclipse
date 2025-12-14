import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import Gtk from "gi://Gtk?version=4.0";
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
    description: "Update Packages (pacman)",
    script: () => {
      execAsync(`bash -c "kitty sudo pacman -Syu"`).catch((err) =>
        notify({ summary: "Update", body: err })
      );
    },
  },
  // Clipboard Utilities
  {
    name: "Clear Clipboard",
    icon: "󰃢",
    description: "Clear clipboard history",
    script: () => {
      execAsync("wl-copy --clear")
        .then(() => notify({ summary: "Clipboard", body: "Cleared clipboard" }))
        .catch((err) => notify({ summary: "Clipboard", body: err }));
    },
  },
  {
    name: "Clipboard History",
    icon: "󰅍",
    description: "Show clipboard history",
    script: () => {
      execAsync(
        `bash -c "cliphist list | rofi -dmenu | cliphist decode | wl-copy"`
      ).catch((err) => notify({ summary: "Clipboard", body: err }));
    },
  },
  // Screenshot Utilities
  {
    name: "Screenshot Area",
    icon: "󰢨",
    description: "Select area to screenshot",
    script: () => {
      execAsync(
        `bash -c "grim -g \"$(slurp)\" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"`
      )
        .then(() =>
          notify({ summary: "Screenshot", body: "Area screenshot saved" })
        )
        .catch((err) => notify({ summary: "Screenshot", body: err }));
    },
  },
  {
    name: "Screenshot Screen",
    icon: "󰍺",
    description: "Screenshot entire screen",
    script: () => {
      execAsync(
        `bash -c "grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png"`
      )
        .then(() => notify({ summary: "Screenshot", body: "Screenshot saved" }))
        .catch((err) => notify({ summary: "Screenshot", body: err }));
    },
  },
  {
    name: "Screen Record",
    icon: "󰑬",
    description: "Record screen (Ctrl+Alt+R to stop)",
    script: () => {
      execAsync(
        `bash -c "wf-recorder -g \"$(slurp)\" -f ~/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4"`
      )
        .then(() =>
          notify({ summary: "Recording", body: "Screen recording started" })
        )
        .catch((err) => notify({ summary: "Recording", body: err }));
    },
  },
  // System Utilities
  {
    name: "Restart Hyprland",
    icon: "󰑓",
    description: "Restart Hyprland session",
    script: () => {
      execAsync("hyprctl dispatch exit").catch((err) =>
        notify({ summary: "Hyprland", body: err })
      );
    },
  },
  {
    name: "System Monitor",
    icon: "󰍛",
    description: "Open system monitor",
    script: () => {
      execAsync(`bash -c "kitty btop"`).catch((err) =>
        notify({ summary: "Monitor", body: err })
      );
    },
  },
  {
    name: "Power Menu",
    icon: "⏻",
    description: "Power options (shutdown/reboot/sleep)",
    script: () => {
      execAsync(
        `bash -c "echo -e 'Shutdown\\nReboot\\nSuspend\\nLogout' | rofi -dmenu -p 'Power' | xargs -I {} systemctl {}"`
      ).catch((err) => notify({ summary: "Power", body: err }));
    },
  },
  // Network Utilities
  {
    name: "WiFi Connect",
    icon: "󰖩",
    description: "Connect to WiFi network",
    script: () => {
      execAsync(
        `bash -c "nmcli device wifi connect $(nmcli device wifi list | tail -n +2 | rofi -dmenu | awk '{print \$1}')"`
      ).catch((err) => notify({ summary: "WiFi", body: err }));
    },
  },
  {
    name: "VPN Connect",
    icon: "󰖯",
    description: "Connect to VPN",
    script: () => {
      execAsync(
        `bash -c "nmcli connection up $(nmcli connection show | tail -n +2 | rofi -dmenu | awk '{print \$1}')"`
      ).catch((err) => notify({ summary: "VPN", body: err }));
    },
  },
  // Audio Utilities
  {
    name: "Volume Control",
    icon: "󰕾",
    description: "Adjust volume",
    script: () => {
      execAsync(`bash -c "pavucontrol"`).catch((err) =>
        notify({ summary: "Volume", body: err })
      );
    },
  },
  {
    name: "Mute/Unmute",
    icon: "󰖁",
    description: "Toggle audio mute",
    script: () => {
      execAsync("pactl set-sink-mute @DEFAULT_SINK@ toggle")
        .then(() => notify({ summary: "Audio", body: "Toggled mute" }))
        .catch((err) => notify({ summary: "Audio", body: err }));
    },
  },

  {
    name: "File Browser",
    icon: "󰉋",
    description: "Open file browser",
    script: () => {
      execAsync(`bash -c "thunar"`).catch((err) =>
        notify({ summary: "Files", body: err })
      );
    },
  },
  // Development Tools
  {
    name: "Git Manager",
    icon: "󰊢",
    description: "Git GUI",
    script: () => {
      execAsync(`bash -c "lazygit"`).catch((err) =>
        notify({ summary: "Git", body: err })
      );
    },
  },
  {
    name: "Code Editor",
    icon: "󰨞",
    description: "Open code editor",
    script: () => {
      execAsync(`bash -c "code"`).catch((err) =>
        notify({ summary: "Editor", body: err })
      );
    },
  },
  // Media Utilities
  // {
  //   name: "Media Player",
  //   icon: "󰎄",
  //   description: "Open media player",
  //   script: () => {
  //     execAsync(`bash -c "celluloid"`).catch((err) =>
  //       notify({ summary: "Media", body: err })
  //     );
  //   },
  // },
];

export default () => {
  return (
    <box
      class="custom-scripts"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      spacing={10}
    >
      {customScripts.map((script) => (
        <button
          onClicked={() => {
            script.script();
          }}
          tooltipText={script.description}
        >
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
        </button>
      ))}
    </box>
  );
};
