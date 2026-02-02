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
import { createBinding, For, onCleanup, This } from "ags";
import Notifd from "gi://AstalNotifd";
import KeyStrokeVisualizer from "./widgets/KeyStrokeVisualizer";
const Notification = Notifd.get_default();

const perMonitorDisplay = () => {
  const monitors = createBinding(app, "monitors");

  return (
    <box>
      <For each={monitors}>
        {(monitor) => (
          <This this={app}>
            <Bar
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <BarHover
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <RightPanel
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <RightPanelHover
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <LeftPanel
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <LeftPanelHover
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <NotificationPopups
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <AppLauncher
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <UserPanel
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
            <WallpaperSwitcher
              monitor={monitor}
              setup={(self) => onCleanup(() => self.destroy())}
            />
          </This>
        )}
      </For>
      <This this={app}>
        <KeyStrokeVisualizer
          setup={(self) => onCleanup(() => self.destroy())}
        />
      </This>
    </box>
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
