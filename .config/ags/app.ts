import app from "ags/gtk4/app";
import Gdk from "gi://Gdk?version=4.0";
import GLib from "gi://GLib";
import Bar from "./widgets/bar/Bar";
import { getCssPath } from "./utils/scss";
import { getMonitorName } from "./utils/monitor";
import { logTime } from "./utils/time";
import { compileBinaries } from "./utils/gcc";
import BarHover from "./widgets/bar/BarHover";
import RightPanelHover from "./widgets/rightPanel/RightPanelHover";
import RightPanel from "./widgets/rightPanel/RightPanel";
import LeftPanel from "./widgets/leftPanel/LeftPanel";
import LeftPanelHover from "./widgets/leftPanel/LeftPanelHover";
import WallpaperSwitcher from "./widgets/WallpaperSwitcher";
import AppLauncher from "./widgets/AppLauncher";
import UserPanel from "./widgets/UserPanel";
import NotificationPopups from "./widgets/NotificationPopups";
import { globalSettings, setGlobalSetting } from "./variables";

// Track monitors that already have widgets created
const initializedMonitors = new Set<string>();

const createWidgetsForMonitor = (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor);

  // Skip if already initialized or if monitor name is invalid
  if (!monitorName || initializedMonitors.has(monitorName)) {
    return;
  }

  print("\t MONITOR: " + monitorName);
  initializedMonitors.add(monitorName);

  // List of widget initializers
  const widgetInitializers = [
    { name: "Bar", fn: () => Bar(monitor) },
    { name: "BarHover", fn: () => BarHover(monitor) },
    { name: "RightPanel", fn: () => RightPanel(monitor) },
    { name: "RightPanelHover", fn: () => RightPanelHover(monitor) },
    { name: "LeftPanel", fn: () => LeftPanel(monitor) },
    { name: "LeftPanelHover", fn: () => LeftPanelHover(monitor) },
    { name: "NotificationPopups", fn: () => NotificationPopups(monitor) },
    { name: "AppLauncher", fn: () => AppLauncher(monitor) },
    { name: "UserPanel", fn: () => UserPanel(monitor) },
    { name: "WallpaperSwitcher", fn: () => WallpaperSwitcher(monitor) },
  ];

  // Launch each widget independently without waiting
  widgetInitializers.forEach(({ name, fn }) => {
    logTime(`\t\t ${name}`, fn);
  });
};

const perMonitorDisplay = () => {
  const monitors = app.get_monitors();
  print("\t TOTAL MONITORS DETECTED: " + monitors.length);

  // Process each monitor independently with error handling
  // This ensures one monitor's errors don't prevent widgets on other monitors
  monitors.forEach((monitor) => {
    try {
      createWidgetsForMonitor(monitor);
    } catch (e) {
      print("\t ERROR creating widgets for monitor: " + monitor.get_connector() + " - " + e);
    }
  });
};

// Setup monitor hotplug detection
const setupMonitorHotplug = () => {
  app.connect("notify::monitors", () => {
    // Defer widget creation to next idle to avoid context issues
    GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
      print("\t MONITOR CHANGE DETECTED");
      const monitors = app.get_monitors();
      print("\t CURRENT MONITORS: " + monitors.length);
      monitors.forEach((monitor) => createWidgetsForMonitor(monitor));
      return GLib.SOURCE_REMOVE;
    });
  });
};

app.start({
  css: getCssPath(),
  main: () => {
    logTime("\t Compiling Binaries", () => compileBinaries());
    setupMonitorHotplug();
    perMonitorDisplay();
  },
});
