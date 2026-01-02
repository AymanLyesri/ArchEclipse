import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { createComputed } from "gnim";
import { globalSettings, setGlobalSetting } from "../../variables";

export default (monitor: Gdk.Monitor) => {
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
      visible={globalSettings(
        ({ leftPanel }) => !leftPanel.visibility && !leftPanel.lock
      )}
      $={(self) => {
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          setGlobalSetting("leftPanel.visibility", true);
        });
        self.add_controller(motion);
      }}
    >
      <box css="min-width: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
