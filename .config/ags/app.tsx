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
import AppLauncher from "./widgets/applauncher/AppLauncher";
import UserPanel from "./widgets/UserPanel";
import NotificationPopups from "./widgets/NotificationPopups";
import { createBinding, For, onCleanup, This } from "ags";
import Notifd from "gi://AstalNotifd";
import KeyStrokeVisualizer from "./widgets/KeyStrokeVisualizer";
import { leftPanelWidgetSelectors } from "./constants/widget.constants";
import { setGlobalSetting } from "./variables";
import { Gtk } from "ags/gtk4";
import AlwaysOnWidget from "./widgets/AlwaysOnWidget";
import { ensureAuthServerRunning } from "./utils/auth-session";
const Notification = Notifd.get_default();

const perMonitorDisplay = () => {
  const monitors = createBinding(app, "monitors");
  const createWidget = (Widget: any, monitor: any) => () => (
    <Widget
      monitor={monitor}
      setup={(self: any) => onCleanup(() => self.destroy())}
    />
  );
  const widgets = [
    Bar,
    BarHover,
    RightPanel,
    RightPanelHover,
    LeftPanel,
    LeftPanelHover,
    NotificationPopups,
    AppLauncher,
    UserPanel,
    WallpaperSwitcher,
    AlwaysOnWidget,
    KeyStrokeVisualizer,
  ];

  return (
    <For each={monitors}>
      {(monitor) => (
        <This this={app}>
          {(() => {
            const connector = monitor.get_connector()! as unknown as string;
            return widgets.map((Widget) =>
              logTimeWidget(connector, createWidget(Widget, monitor)),
            );
          })()}
        </This>
      )}
    </For>
  );
};

app.start({
  css: getCssPath(),
  main: () => {
    ensureAuthServerRunning();
    logTime("Compiling Binaries", () => compileBinaries());
    logTime("\tInitializing Per-Monitor Display", () => perMonitorDisplay());
  },
  requestHandler(argv: string[], response: (response: string) => void) {
    const [cmd, arg, ...rest] = argv;
    const monitor = arg;

    const prefillLauncherInput = (window: any, value: string) => {
      const input = window?.entry as Gtk.TextView | Gtk.Entry | undefined;
      if (!input) return;

      if (
        "buffer" in input &&
        input.buffer &&
        "get_end_iter" in input.buffer &&
        "place_cursor" in input.buffer
      ) {
        const buffer = input.buffer as Gtk.TextBuffer;
        buffer.text = value;
        const iter = buffer.get_end_iter();
        buffer.place_cursor(iter);
        input.grab_focus();
        return;
      }

      if ("set_text" in input) {
        (input as Gtk.Entry).set_text(value);
        (input as Gtk.Entry).set_position(-1);
        (input as Gtk.Entry).grab_focus();
      }
    };

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
        setGlobalSetting("leftPanel.widget", leftPanelWidgetSelectors.find((w) => w.name === "Donations"));
      }
      response("Donations widget opened.");
      return;
    } else if (cmd == "clipboard") {
      const appLauncher = app.get_window(`app-launcher-${monitor}`);
      if (appLauncher) {
        appLauncher.show();
        prefillLauncherInput(appLauncher as any, "cb ");
      }
      response("Clipboard widget opened.");
      return;
    } else if (cmd == "emojis") {
      const appLauncher = app.get_window(`app-launcher-${monitor}`);
      if (appLauncher) {
        appLauncher.show();
        prefillLauncherInput(appLauncher as any, "emoji ");
      }
      response("Emoji picker opened.");
      return;
    } else if (cmd == "notes") {
      const appLauncher = app.get_window(`app-launcher-${monitor}`);
      if (appLauncher) {
        appLauncher.show();
        prefillLauncherInput(appLauncher as any, "note ");
      }
      response("Notes widget opened.");
      return;
    }
    response("unknown command");
  },
});
