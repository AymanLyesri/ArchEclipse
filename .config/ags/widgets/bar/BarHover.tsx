import App from "ags/gtk4/app";
import { Gtk } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Astal } from "ags/gtk4";
import {
  globalSettings,
  setGlobalSetting,
  setIsBarExpanded,
} from "../../variables";
import { createComputed } from "ags";
import app from "ags/gtk4/app";
import { getMonitorName } from "../../utils/monitor";

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;
  let hoverStrip: Gtk.Box | null = null;

  const syncHoverHeightToBar = () => {
    const barWindow = app.get_window(`bar-${monitorName}`) as Gtk.Window | null;
    if (!barWindow || !hoverStrip) return;

    // Keep hover sensor the same height as the real bar window.
    const barHeight = Math.max(1, barWindow.get_height());
    hoverStrip.set_size_request(-1, barHeight);
  };

  return (
    <window
      name="bar-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={globalSettings(({ bar }) =>
        bar.orientation.value
          ? Astal.WindowAnchor.TOP |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT,
      )}
      exclusivity={Astal.Exclusivity.IGNORE}
      visible={true}
      layer={Astal.Layer.BACKGROUND}
      $={(self) => {
        setup(self);
        const barWindow = app.get_window(
          `bar-${monitorName}`,
        ) as Gtk.Window | null;

        if (barWindow) {
          barWindow.connect("show", syncHoverHeightToBar);
          barWindow.connect("notify::default-height", syncHoverHeightToBar);
        }

        syncHoverHeightToBar();

        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          syncHoverHeightToBar();
          app.get_window(`bar-${monitorName}`)!.show();
          setIsBarExpanded(true);
        });
        self.add_controller(motion);
      }}
    >
      <box
        css="min-height: 10px; background-color: rgba(0,0,0,0.01);"
        $={(self) => {
          hoverStrip = self;
          syncHoverHeightToBar();
        }}
      />
    </window>
  );
};
