import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { globalSettings, setGlobalSetting } from "../../variables";
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
  return (
    <window
      name="bar-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={globalSettings(({ bar }) =>
        bar.orientation
          ? Astal.WindowAnchor.TOP |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT,
      )}
      exclusivity={Astal.Exclusivity.IGNORE}
      visible={globalSettings(({ bar }) => !bar.lock)}
      layer={Astal.Layer.TOP}
      $={(self) => {
        setup(self);
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          app.get_window(`bar-${getMonitorName(monitor)}`)!.show();
        });
        self.add_controller(motion);
      }}
    >
      <box css="min-height: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
