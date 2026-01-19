import app from "ags/gtk4/app";
import Bar from "./widgets/bar/Bar";
import { getCssPath } from "./utils/scss";
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
import { createBinding, For, This } from "ags";
import Notifd from "gi://AstalNotifd";
const Notification = Notifd.get_default();

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
              logTimeWidget(`\t\t ${name}`, fn),
            )}
          </This>
        );
      }}
    </For>
  );
};

app.start({
  css: getCssPath(),
  main: () => {
    logTime("\t Compiling Binaries", () => compileBinaries());
    logTime("\t Initializing Per-Monitor Display", () => perMonitorDisplay());
  },
  requestHandler(argv: string[], response: (response: string) => void) {
    const [cmd, arg, ...rest] = argv;
    if (cmd == "delete-notification") {
      const id = parseInt(arg);
      const notification = Notification.notifications.find((n) => n.id === id);
      if (notification) {
        notification.dismiss();
        response(`Notification ${id} dismissed.`);
      } else {
        response(`Notification ${id} not found.`);
      }
      return;
    }
    response("unknown command");
  },
});
