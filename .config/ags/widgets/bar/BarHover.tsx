import App from "ags/gtk4/app";
import { Gtk } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Astal } from "ags/gtk4";
import { timeout, Timer } from "ags/time";
import { globalSettings } from "../../variables";
import { getMonitorName } from "../../utils/monitor";
import { revealBar } from "./Bar";

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;

  return (
    <window
      name={`bar-hover-${monitorName}`}
      namespace="bar-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={globalSettings(({ bar }) =>
        (bar.orientation.value as boolean)
          ? Astal.WindowAnchor.TOP |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT,
      )}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      visible={globalSettings(({ bar }) => !(bar.lock.value as boolean))}
      $={(self) => {
        setup(self);
        // Pressure barrier: revealing requires pushing the pointer against
        // the outermost screen edge pixel and holding it there for the
        // configured delay - merely crossing the strip does nothing.
        let pressureTimer: Timer | null = null;

        const cancelPressure = () => {
          pressureTimer?.cancel();
          pressureTimer = null;
        };

        const applyPressure = (y: number) => {
          const height = Math.max(self.get_height(), 1);
          const onTop = globalSettings.peek().bar.orientation.value as boolean;
          const atEdge = onTop ? y <= 1 : y >= height - 2;

          if (!atEdge) {
            cancelPressure();
            return;
          }
          if (pressureTimer) return;

          const delay = globalSettings.peek().bar.revealPressure
            .value as number;
          if (delay <= 0) {
            revealBar(monitorName);
            return;
          }
          pressureTimer = timeout(delay, () => {
            pressureTimer = null;
            revealBar(monitorName);
          });
        };

        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", (_controller, _x, y) => applyPressure(y));
        motion.connect("motion", (_controller, _x, y) => applyPressure(y));
        motion.connect("leave", cancelPressure);
        self.add_controller(motion);
      }}
    >
      <box css="min-height: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
