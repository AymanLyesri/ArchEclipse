import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { createComputed } from "gnim";
import { globalSettings, setGlobalSetting } from "../../variables";
import app from "ags/gtk4/app";
import { getMonitorName } from "../../utils/monitor";
import { showWindow } from "../../utils/window";

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  return (
    <window
      name="left-panel-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      visible={globalSettings(({ leftPanel }) => !leftPanel.lock)}
      $={(self) => {
        setup(self);
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          showWindow(`left-panel-${getMonitorName(monitor)}`);
        });
        self.add_controller(motion);
      }}
    >
      <box css="min-width: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
