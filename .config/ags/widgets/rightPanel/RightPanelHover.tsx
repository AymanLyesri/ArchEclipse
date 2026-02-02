import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { createComputed } from "gnim";
import { globalSettings, setGlobalSetting } from "../../variables";
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
      name="right-panel-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      visible={globalSettings(({ rightPanel }) => !rightPanel.lock)}
      $={(self) => {
        setup(self);
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          app.get_window(`right-panel-${getMonitorName(monitor)}`)!.show();
        });
        self.add_controller(motion);
      }}
    >
      <box css="min-width: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
