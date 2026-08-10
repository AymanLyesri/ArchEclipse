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
        // Pressure barrier: the pointer must hold the edge strip for the
        // configured delay before the bar reveals, so brushing the screen
        // edge (browser tabs, window buttons) doesn't summon it.
        let pressureTimer: Timer | null = null;
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          pressureTimer?.cancel();
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
        });
        motion.connect("leave", () => {
          pressureTimer?.cancel();
          pressureTimer = null;
        });
        self.add_controller(motion);
      }}
    >
      <box css="min-height: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
