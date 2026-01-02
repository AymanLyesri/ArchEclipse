import app from "ags/gtk4/app";
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

const perMonitorDisplay = () =>
  app.get_monitors().map((monitor) => {
    print("\t MONITOR: " + getMonitorName(monitor.get_display(), monitor));

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
  });

app.start({
  css: getCssPath(),
  main: () => {
    logTime("\t Compiling Binaries", () => compileBinaries());
    perMonitorDisplay();
  },
});
