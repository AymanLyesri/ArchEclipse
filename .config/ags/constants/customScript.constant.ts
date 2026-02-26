import { Gtk } from "ags/gtk4";
import { CustomScript } from "../interfaces/customScript.interface";
import { globalSettings } from "../variables";

import Hyprland from "gi://AstalHyprland";
import { execAsync } from "ags/process";
import GLib from "gi://GLib?version=2.0";
const hyprland = Hyprland.get_default();

export const customScripts = (): CustomScript[] => [
  {
    name: "Restart Bar",
    icon: "󰜉",
    description: "Restart the AGS bar",
    keybind: ["SUPER", "B"],
    script: () => {
      // execAsync(`bash -c "$HOME/.config/hypr/scripts/bar.sh"`).catch((err) =>
      //   notify({ summary: "AGS Bar", body: err }),
      // );
      hyprland.dispatch("exec", `bash -c "$HOME/.config/hypr/scripts/bar.sh"`);
    },
  },
  {
    name: "HyprPicker",
    icon: "",
    description: "Color Picker for Hyprland",
    app: "hyprpicker",
    script: () => {
      // execAsync("hyprpicker")
      //   .then((res) => {
      //     execAsync(`wl-copy "${res}"`);
      //   })
      //   .catch((err) => notify({ summary: "HyprPicker", body: err }));
      hyprland.dispatch("exec", "hyprpicker");
    },
  },
  {
    name: "Change Resolution",
    icon: "󰍹",
    description: "Change Resolution",
    app: "hyprmon",
    package: "hyprmon-bin",
    script: () => {
      hyprland.dispatch("exec", "foot hyprmon");
    },
  },
  {
    name: "Update Packages",
    icon: "󰏗",
    description: "Update Packages (pacman)",
    script: () => {
      hyprland.dispatch("exec", "foot -e sudo pacman -Syu");
    },
  },
  // Clipboard Utilities
  {
    name: "Clear Clipboard",
    icon: "󰃢",
    description: "Clear clipboard history",
    app: "wl-copy",
    package: "wl-clipboard",
    script: () => {
      hyprland.dispatch("exec", "wl-copy --clear");
    },
  },
  {
    name: "Screenshot Screen",
    icon: "",
    description: "Screenshot entire screen",
    keybind: ["SUPER", "SHIFT", "S"],
    app: "grimblast",
    package: "grimblast-git",
    script: () => {
      hyprland.dispatch(
        "exec",
        `bash -c "$HOME/.config/hypr/scripts/screenshot.sh --now"`,
      );
    },
  },
  {
    name: "Screenshot Area",
    icon: "",
    description: "Select area to screenshot",
    keybind: ["SUPER", "CTRL", "SHIFT", "S"],
    app: "grimblast",
    package: "grimblast-git",
    script: () => {
      hyprland.dispatch(
        "exec",
        `bash -c "$HOME/.config/hypr/scripts/screenshot.sh --area"`,
      );
    },
  },

  {
    name: "Record Screen",
    icon: "",
    description: "Record entire screen",
    keybind: ["SUPER", "SHIFT", "R"],
    app: "wf-recorder",
    script: () => {
      hyprland.dispatch(
        "exec",
        `bash -c "$HOME/.config/hypr/scripts/screenrecord.sh --now"`,
      );
    },
  },
  {
    name: "Record Area",
    icon: "",
    description: "Record selected area",
    keybind: ["SUPER", "CTRL", "SHIFT", "R"],
    app: "wf-recorder",
    script: () => {
      hyprland.dispatch(
        "exec",
        `bash -c "$HOME/.config/hypr/scripts/screenrecord.sh --area"`,
      );
    },
  },
  // System Utilities
  {
    name: "Restart Hyprland",
    icon: "󰑓",
    description: "Restart Hyprland session",
    script: () => {
      hyprland.dispatch("dispatch", "exit");
    },
  },
  {
    name: "System Monitor",
    icon: "󰍛",
    description: "Open system monitor",
    app: "btop",
    script: () => {
      hyprland.dispatch("exec", "foot -e btop");
    },
  },

  // Audio Utilities
  {
    name: "Volume Control",
    icon: "󰕾",
    description: "Adjust volume",
    app: "pavucontrol",
    script: () => {
      hyprland.dispatch("exec", "pavucontrol");
    },
  },

  {
    name: globalSettings(({ fileManager }) => `${fileManager} File Manager`),
    icon: "󰉋",
    description: `Open ${globalSettings.peek().fileManager}`,
    script: () => {
      const fileManager = globalSettings.peek().fileManager;
      hyprland.dispatch("exec", fileManager);
    },
  },
  // Development Tools
  {
    name: "Lazygit",
    icon: "󰊢",
    description: "Git Manager",
    app: "lazygit",
    script: () => {
      hyprland.dispatch("exec", `bash -c "lazygit"`);
    },
  },
  {
    name: "Visual Studio Code",
    icon: "󰨞",
    description: "Code Editor",
    app: "code",
    package: "visual-studio-code-bin",
    script: () => {
      hyprland.dispatch("exec", "code");
    },
  },
  // spotube
  {
    name: "Spotube",
    icon: "",
    description: "Spotify Client (lightweight - downloaded music)",
    app: "spotube",
    package: "spotube-bin",
    script: () => {
      hyprland.dispatch("exec", "spotube");
    },
  },
  // steam
  {
    name: "Steam",
    icon: "",
    description: "Game Launcher",
    app: "steam",
    script: () => {
      hyprland.dispatch("exec", "steam");
    },
  },
  // pipes
  {
    name: "Pipes.sh",
    icon: "󰟥",
    description: "Pipes Animation",
    app: "pipes.sh",
    script: () => {
      hyprland.dispatch("exec", "foot -e pipes.sh");
    },
  },
  // cava
  {
    name: "Cava",
    icon: "󰕾",
    description: "Audio Visualizer",
    app: "cava",
    script: () => {
      hyprland.dispatch("exec", "foot -e cava");
    },
  },
  // cmatrix
  {
    name: "CMatrix",
    icon: "󱔼",
    description: "Matrix Digital Rain",
    app: "cmatrix",
    script: () => {
      hyprland.dispatch("exec", "foot -e cmatrix");
    },
  },
  // asciiquarium
  {
    name: "Asciiquarium",
    icon: "",
    description: "Aquarium Animation",
    app: "asciiquarium",
    script: () => {
      hyprland.dispatch("exec", "foot -e asciiquarium");
    },
  },
  // reset ags settings
  {
    name: "Reset AGS Settings",
    icon: "󰜉",
    description: "Reset all AGS settings to default",
    script: (self: Gtk.Button) => {
      // create and open a confirmation popover before resetting settings
      const parentBox = self.get_parent() as Gtk.Box;
      if (!parentBox) return;

      // Check if buttonBox already exists
      if (!(parentBox as any).resetButtonBox) {
        const buttonBox = new Gtk.Box({
          orientation: Gtk.Orientation.HORIZONTAL,
          visible: false,
          spacing: 10,
        });
        const yesButton = new Gtk.Button({ 
          label: "Yes",
          css_classes: ["danger"]
        });
        const noButton = new Gtk.Button({ 
          label: "No",
          css_classes: ["button"]
        });

        yesButton.connect("clicked", () => {
          print("Yes button clicked");
          execAsync(
            `rm -rf ${GLib.get_home_dir()}/.config/ags/cache/settings/settings.json`,
          ).then(() => {
            hyprland.dispatch(
              "exec",
              `bash -c "$HOME/.config/hypr/scripts/bar.sh"`,
            );
          });
          buttonBox.visible = false;
        });

        noButton.connect("clicked", () => {
          print("No button clicked");
          buttonBox.visible = false;
        });

        buttonBox.append(yesButton);
        buttonBox.append(noButton);
        parentBox.append(buttonBox);

        // Store reference to avoid re-creating
        (parentBox as any).resetButtonBox = buttonBox;
      }

      // Toggle visibility
      (parentBox as any).resetButtonBox.visible = true;
    },
  },
];
