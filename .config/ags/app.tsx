import app from "ags/gtk4/app";
import Bar from "./widgets/bar/Bar";
import { getCssPath } from "./utils/scss";
import { getMonitorName } from "./utils/monitor";
import { logTime, logTimeWidget } from "./utils/time";
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
import { createBinding, For, onCleanup, This } from "ags";
import { Gtk } from "ags/gtk4";

// const perMonitorDisplay = () =>
//   app.get_monitors().map((monitor) => {
//     print("\t MONITOR: " + getMonitorName(monitor));

//     // List of widget initializers
//     const widgetInitializers = [
//       { name: "Bar", widget: Bar(monitor) },
//       { name: "BarHover", widget: BarHover(monitor) },
//       { name: "RightPanel", widget: RightPanel(monitor) },
//       { name: "RightPanelHover", widget: RightPanelHover(monitor) },
//       { name: "LeftPanel", widget: LeftPanel(monitor) },
//       { name: "LeftPanelHover", widget: LeftPanelHover(monitor) },
//       { name: "NotificationPopups", widget: NotificationPopups(monitor) },
//       { name: "AppLauncher", widget: AppLauncher(monitor) },
//       { name: "UserPanel", widget: UserPanel(monitor) },
//       { name: "WallpaperSwitcher", widget: WallpaperSwitcher(monitor) },
//     ];

//     // Launch each widget independently without waiting
// widgetInitializers.forEach(({ name, fn }) => {
//   logTime(`\t\t ${name}`, fn);
// });
//   });

const perMonitorDisplay = () => {
  const monitors = createBinding(app, "monitors");

  return (
    <For each={monitors}>
      {(monitor) => {
        const widgetInitializers = [
          { name: "Bar", fn: () => Bar({ monitor: monitor }) },
          { name: "BarHover", fn: () => BarHover({ monitor: monitor }) },
          { name: "RightPanel", fn: () => RightPanel({ monitor: monitor }) },
          {
            name: "RightPanelHover",
            fn: () => RightPanelHover({ monitor: monitor }),
          },
          { name: "LeftPanel", fn: () => LeftPanel({ monitor: monitor }) },
          {
            name: "LeftPanelHover",
            fn: () => LeftPanelHover({ monitor: monitor }),
          },
          {
            name: "NotificationPopups",
            fn: () => NotificationPopups({ monitor: monitor }),
          },
          { name: "AppLauncher", fn: () => AppLauncher({ monitor: monitor }) },
          { name: "UserPanel", fn: () => UserPanel({ monitor: monitor }) },
          {
            name: "WallpaperSwitcher",
            fn: () => WallpaperSwitcher({ monitor: monitor }),
          },
        ];
        return (
          <This this={app}>
            {widgetInitializers.map(({ name, fn }) =>
              logTimeWidget(`\t\t ${name}`, fn)
            )}
          </This>
        );
      }}
    </For>
  );
};

app.start({
  css: getCssPath(),
  // requestHandler(argv: string[], response: (response: string) => void) {
  //   const [cmd, arg, ...rest] = argv;
  //   if (cmd == "toggle") {
  //     if (arg == "left-panel") {
  //       setGlobalSetting(
  //         "leftPanel.visibility",
  //         !globalSettings.peek().leftPanel.visibility
  //       );
  //       return response("ok");
  //     }
  //     if (arg == "right-panel") {
  //       setGlobalSetting(
  //         "rightPanel.visibility",
  //         !globalSettings.peek().rightPanel.visibility
  //       );
  //       return response("ok");
  //     }
  //   }
  //   response("unknown command");
  // },
  main: () => {
    logTime("\t Compiling Binaries", () => compileBinaries());
    logTime("\t Initializing Per-Monitor Display", () => perMonitorDisplay());
  },
});
