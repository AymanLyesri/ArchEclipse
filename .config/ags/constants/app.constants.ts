import { execAsync } from "astal";
import { LauncherApp } from "../interfaces/app.interface";
import { setGlobalTheme } from "../utils/theme";

export const customApps: LauncherApp[] = [
  {
    app_name: "Light Theme",
    app_icon: "",
    app_launch: () => {
      setGlobalTheme("light");
    },
  },
  {
    app_name: "Dark Theme",
    app_icon: "",
    app_launch: () => {
      setGlobalTheme("dark");
    },
  },
  {
    app_name: "System Sleep",
    app_icon: "",
    app_launch: () => {
      execAsync(`bash -c "$HOME/.config/hypr/scripts/hyprlock.sh suspend"`);
    },
  },
  {
    app_name: "System Restart",
    app_icon: "󰜉",
    app_launch: () => {
      execAsync(`reboot`);
    },
  },
  {
    app_name: "System Shutdown",
    app_icon: "",
    app_launch: () => {
      execAsync(`shutdown now`);
    },
  },
];

export const quickApps: LauncherApp[] = [
  {
    app_name: "Keybinds",
    app_launch: () =>
      execAsync("bash -c 'xdg-open $HOME/.config/hypr/configs/keybinds.conf'"),
    app_icon: "",
  },
  {
    app_name: "Browser",
    app_launch: () => execAsync("xdg-open https://google.com"),
    app_icon: "",
  },
  {
    app_name: "Terminal",
    app_launch: () => execAsync("kitty"),
    app_icon: "",
  },
  {
    app_name: "Files",
    app_launch: () => execAsync("thunar"),
    app_icon: "",
  },
  {
    app_name: "Calculator",
    app_launch: () => execAsync("kitty bc"),
    app_icon: "",
  },
  {
    app_name: "Text Editor",
    app_launch: () => execAsync("code"),
    app_icon: "",
  },
];
