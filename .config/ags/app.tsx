import app from "ags/gtk4/app";
import Bar, {
  activateState,
  barState,
  deactivateState,
  setBarState,
  setSearchQuery,
} from "./widgets/bar/Bar";
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
import { startFastfetchPinsSync } from "./services/fastfetch";
import { isRecording, toggleRecording } from "./services/record.service";
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
    // BarHover,
    RightPanel,
    RightPanelHover,
    LeftPanel,
    LeftPanelHover,
    NotificationPopups,
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
    startFastfetchPinsSync();
    logTime("Compiling Binaries", () => compileBinaries());
    logTime("\tInitializing Per-Monitor Display", () => perMonitorDisplay());
  },
  async requestHandler(argv: string[], response: (response: string) => void) {
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
        setGlobalSetting(
          "leftPanel.widget",
          leftPanelWidgetSelectors.find((w) => w.name === "Donations"),
        );
      }
      response("Donations widget opened.");
      return;
    } else if (cmd == "clipboard") {
      activateState("search");
      setSearchQuery("cb ");
      response("Clipboard widget opened.");
      return;
    } else if (cmd == "emojis") {
      activateState("search");
      setSearchQuery("emoji ");
      response("Emoji picker opened.");
      return;
    } else if (cmd == "notes") {
      activateState("search");
      setSearchQuery("note ");
      response("Notes widget opened.");
      return;
    } else if (cmd == "apps") {
      activateState("search");
      setSearchQuery("apps ");
      response("Apps list opened.");
      return;
    }

    if (cmd == "screenrecord") {
      const state = await toggleRecording(arg as "now" | "area");
      response(`Recording ${state}.`);
      return;
    }

    if (cmd == "search") {
      if (barState.peek() === "search") {
        deactivateState("search");
      } else {
        activateState("search");
      }
      response("Search toggled.");
      return;
    }
    response("unknown command");
  },
});
