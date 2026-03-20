import { LauncherApp } from "../interfaces/app.interface";
import { subprocess, exec, execAsync, createSubprocess } from "ags/process";
import { setGlobalTheme, globalSettings, setGlobalSetting } from "../variables";
import { leftPanelWidgetSelectors } from "./widget.constants";
import app from "ags/gtk4/app";

// File manager command mapping
const fileManagerCommands: Record<string, string> = {
  nautilus: "nautilus",
  thunar: "thunar",
  dolphin: "dolphin",
  nemo: "nemo",
  pcmanfm: "pcmanfm",
  ranger: "foot ranger",
};

// Get the configured file manager command
const getFileManagerCommand = () => {
  const fm = globalSettings.peek().fileManager || "nautilus";
  return fileManagerCommands[fm] || "nautilus";
};

export const customApps: LauncherApp[] = [
  {
    app_name: "Light Theme",
    app_icon: "",
    app_launch: () => {
      setGlobalTheme(true);
    },
  },
  {
    app_name: "Dark Theme",
    app_icon: "",
    app_launch: () => {
      setGlobalTheme(false);
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
    app_launch: (monitor) => {
      const leftPanel = app.get_window(`left-panel-${monitor}`);
      if (!leftPanel) {
        console.error(`Left panel for monitor ${monitor} not found.`);
        return;
      }
      leftPanel.show();
      setGlobalSetting("leftPanel.widget", leftPanelWidgetSelectors[6]);
    },
    app_icon: "",
    app_description: "View or edit your Hyprland keybinds",
  },
  {
    app_name: "Browser",
    app_launch: () => execAsync("xdg-open ."),
    app_icon: "",
    app_description: "Open your default web browser",
  },
  {
    app_name: "Terminal",
    app_launch: () => execAsync("foot"),
    app_icon: "",
    app_description: "Open a new terminal window",
  },
  {
    app_name: "Files",
    app_launch: () => execAsync(getFileManagerCommand()),
    app_icon: "",
    app_description: "Open your file manager",
  },
  {
    app_name: "Calculator",
    app_launch: () => execAsync("foot bc"),
    app_icon: "",
    app_description: "Open the calculator",
  },
  {
    app_name: "Text Editor",
    app_launch: () => execAsync("code"),
    app_icon: "",
    app_description: "Open your default text editor",
  },
];
