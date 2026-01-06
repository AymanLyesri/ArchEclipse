import { execAsync } from "ags/process";
import { CustomScript } from "../interfaces/customScript.interface";
import { notify } from "../utils/notification";
import { globalSettings } from "../variables";

export const customScripts = (): CustomScript[] => [
  {
    name: "Restart Bar",
    icon: "󰜉",
    description: "Restart the AGS bar",
    keybind: ["SUPER", "B"],
    script: () => {
      execAsync(`bash -c "$HOME/.config/hypr/scripts/bar.sh"`).catch((err) =>
        notify({ summary: "AGS Bar", body: err })
      );
    },
  },
  {
    name: "HyprPicker",
    icon: "",
    description: "Color Picker for Hyprland",
    sensitive: execAsync(
      `bash -c "command -v hyprpicker >/dev/null 2>&1 && echo true || echo false"`
    )
      .then((res) => res.trim() === "true")
      .catch(() => false),
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
      execAsync(`kitty hyprmon`).catch((err) =>
        notify({ summary: "Resolution", body: err })
      );
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
    name: "Screenshot Screen",
    icon: "󰍺",
    description: "Screenshot entire screen",
    keybind: ["SUPER", "SHIFT", "S"],
    script: () => {
      execAsync(`bash -c "$HOME/.config/hypr/scripts/screenshot.sh --now"`)
        .then(() => notify({ summary: "Screenshot", body: "Screenshot saved" }))
        .catch((err) => notify({ summary: "Screenshot", body: err }));
    },
  },
  {
    name: "Screenshot Area",
    icon: "󰢨",
    description: "Select area to screenshot",
    keybind: ["SUPER", "SHIFT", "Z"],
    script: () => {
      execAsync(`bash -c "$HOME/.config/hypr/scripts/screenshot.sh --area"`)
        .then(() =>
          notify({ summary: "Screenshot", body: "Area screenshot saved" })
        )
        .catch((err) => notify({ summary: "Screenshot", body: err }));
    },
  },

  // {
  //   name: "Screen Record",
  //   icon: "󰑬",
  //   description: "Record screen (Ctrl+Alt+R to stop)",
  //   sensitive: false,
  //   script: () => {
  //     execAsync(
  //       `bash -c "wf-recorder -g \"$(slurp)\" -f ~/Videos/recording-$(date +%Y%m%d-%H%M%S).mp4"`
  //     )
  //       .then(() =>
  //         notify({ summary: "Recording", body: "Screen recording started" })
  //       )
  //       .catch((err) => notify({ summary: "Recording", body: err }));
  //   },
  // },
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
  // {
  //   name: "Mute/Unmute",
  //   icon: "󰖁",
  //   description: "Toggle audio mute",
  //   sensitive: false,
  //   script: () => {
  //     execAsync("pactl set-sink-mute @DEFAULT_SINK@ toggle")
  //       .then(() => notify({ summary: "Audio", body: "Toggled mute" }))
  //       .catch((err) => notify({ summary: "Audio", body: err }));
  //   },
  // },

  {
    name: globalSettings(({ fileManager }) => `${fileManager} File Manager`),
    icon: "󰉋",
    description: globalSettings(({ fileManager }) => `Open ${fileManager}`),
    script: () => {
      const fileManager = globalSettings.peek().fileManager;
      execAsync(`bash -c "${fileManager}"`).catch((err) =>
        notify({ summary: "Files", body: err })
      );
    },
  },
  // Development Tools
  {
    name: "Lazygit",
    icon: "󰊢",
    description: "Git Manager",
    sensitive: execAsync(
      `bash -c "command -v lazygit >/dev/null 2>&1 && echo true || echo false"`
    )
      .then((res) => res.trim() === "true")
      .catch(() => false),
    script: () => {
      execAsync(`bash -c "lazygit"`).catch((err) =>
        notify({ summary: "Git", body: err })
      );
    },
  },
  {
    name: "Visual Studio Code",
    icon: "󰨞",
    description: "Code Editor",
    sensitive: execAsync(
      `bash -c "command -v code >/dev/null 2>&1 && echo true || echo false"`
    )
      .then((res) => res.trim() === "true")
      .catch(() => false),
    script: () => {
      execAsync(`bash -c "code"`).catch((err) =>
        notify({ summary: "Editor", body: err })
      );
    },
  },
];
