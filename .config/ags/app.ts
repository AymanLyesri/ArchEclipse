import app from "ags/gtk4/app";
import Bar from "./widgets/bar/Bar";
import { getCssPath } from "./utils/scss";
import RightPanel from "./widgets/rightPanel/RightPanel";
import RightPanelHover from "./widgets/rightPanel/RightPanelHover";
import NotificationPopups from "./widgets/NotificationPopups";
import AppLauncher from "./widgets/AppLauncher";
import Progress from "./widgets/Progress";
import UserPanel from "./widgets/UserPanel";
import WallpaperSwitcher from "./widgets/WallpaperSwitcher";
import MediaPopups from "./widgets/MediaPopups";
import SettingsWidget from "./widgets/SettingsWidget";
import BarHover from "./widgets/bar/BarHover";
import OSD from "./widgets/OSD";
import { getMonitorName } from "./utils/monitor";
import { logTime } from "./utils/time";
import LeftPanel from "./widgets/leftPanel/LeftPanel";
import LeftPanelHover from "./widgets/leftPanel/LeftPanelHover";
import { compileBinaries } from "./utils/gcc";
// import "./services/autoSwitchWorkspace";
import ScreenShot from "./widgets/ScreenShot";

const perMonitorDisplay = () =>
  app.get_monitors().map((monitor) => {
    print("\t MONITOR: " + getMonitorName(monitor.get_display(), monitor));

    // List of widget initializers
    const widgetInitializers = [
      { name: "Bar", fn: () => Bar(monitor) },
      // { name: "BarHover", fn: () => BarHover(monitor) },
      // { name: "Progress", fn: () => Progress(monitor) },
      // { name: "RightPanel", fn: () => RightPanel(monitor) },
      // { name: "RightPanelHover", fn: () => RightPanelHover(monitor) },
      // { name: "LeftPanel", fn: () => LeftPanel(monitor) },
      // { name: "LeftPanelHover", fn: () => LeftPanelHover(monitor) },
      // { name: "NotificationPopups", fn: () => NotificationPopups(monitor) },
      // { name: "AppLauncher", fn: () => AppLauncher(monitor) },
      // { name: "UserPanel", fn: () => UserPanel(monitor) },
      // { name: "WallpaperSwitcher", fn: () => WallpaperSwitcher(monitor) },
      // { name: "MediaPopups", fn: () => MediaPopups(monitor) },
      // { name: "SettingsWidget", fn: () => SettingsWidget(monitor) },
      // { name: "OSD", fn: () => OSD(monitor) },
      // { name: "ScreenShot", fn: () => ScreenShot(monitor) },
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
