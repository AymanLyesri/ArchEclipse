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
import { leftPanelWidgetSelectors } from "./constants/widget.constants";
import { setGlobalSetting } from "./variables";
import { Gtk } from "ags/gtk4";
const Notification = Notifd.get_default();

const perMonitorDisplay = () => {
  const monitors = createBinding(app, "monitors");

  return (
    <box>
      <For each={monitors}>
        {(monitor) => (
          <This this={app}>
            {logTimeWidget(
              `\t Bar [Monitor ${monitor.get_connector()}]`,
              () => (
                <Bar
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t BarHover [Monitor ${monitor.get_connector()}]`,
              () => (
                <BarHover
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t RightPanel [Monitor ${monitor.get_connector()}]`,
              () => (
                <RightPanel
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t RightPanelHover [Monitor ${monitor.get_connector()}]`,
              () => (
                <RightPanelHover
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t LeftPanel [Monitor ${monitor.get_connector()}]`,
              () => (
                <LeftPanel
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t LeftPanelHover [Monitor ${monitor.get_connector()}]`,
              () => (
                <LeftPanelHover
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t NotificationPopups [Monitor ${monitor.get_connector()}]`,
              () => (
                <NotificationPopups
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t AppLauncher [Monitor ${monitor.get_connector()}]`,
              () => (
                <AppLauncher
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t UserPanel [Monitor ${monitor.get_connector()}]`,
              () => (
                <UserPanel
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
            {logTimeWidget(
              `\t WallpaperSwitcher [Monitor ${monitor.get_connector()}]`,
              () => (
                <WallpaperSwitcher
                  monitor={monitor}
                  setup={(self) => onCleanup(() => self.destroy())}
                />
              ),
            )}
          </This>
        )}
      </For>
      <This this={app}>
        {logTimeWidget(`\t KeyStrokeVisualizer`, () => (
          <KeyStrokeVisualizer
            setup={(self) => onCleanup(() => self.destroy())}
          />
        ))}
      </This>
    </box>
  );
};

app.start({
  css: getCssPath(),
  main: () => {
    logTime("Compiling Binaries", () => compileBinaries());
    logTime("\t\t Initializing Per-Monitor Display", () => perMonitorDisplay());
  },
  requestHandler(argv: string[], response: (response: string) => void) {
    const [cmd, arg, ...rest] = argv;
    const monitor = arg;
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
    } else if (cmd == "donations") {
      const leftPanel = app.get_window(`left-panel-${monitor}`);
      if (leftPanel) {
        leftPanel.show();
        setGlobalSetting("leftPanel.widget", leftPanelWidgetSelectors[6]);
      }
      response("Donations widget opened.");
      return;
    } else if (cmd == "clipboard") {
      const appLauncher = app.get_window(`app-launcher-${monitor}`);
      if (appLauncher) {
        appLauncher.show();
        ((appLauncher as any).entry as Gtk.Entry)?.set_text("cb ");
        ((appLauncher as any).entry as Gtk.Entry)?.set_position(-1);
      }
      response("Clipboard widget opened.");
      return;
    } else if (cmd == "emojis") {
      const appLauncher = app.get_window(`app-launcher-${monitor}`);
      if (appLauncher) {
        appLauncher.show();
        ((appLauncher as any).entry as Gtk.Entry)?.set_text("emojis ");
        ((appLauncher as any).entry as Gtk.Entry)?.set_position(-1);
      }
      response("Emoji picker opened.");
      return;
    }
    response("unknown command");
  },
});
