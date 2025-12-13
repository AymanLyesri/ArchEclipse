import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import {
  barLock,
  barOrientation,
  barVisibility,
  setBarVisibility,
} from "../../variables";
import { createComputed } from "ags";

export default (monitor: Gdk.Monitor) => {
  return (
    <window
      name="bar-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={barOrientation((orientation) =>
        orientation
          ? Astal.WindowAnchor.TOP |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
      )}
      exclusivity={Astal.Exclusivity.IGNORE}
      visible={createComputed([barVisibility, barLock], (v, l) => !v && !l)}
      layer={Astal.Layer.TOP}
      $={(self) => {
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          setBarVisibility(true);
          print("visible", barVisibility.get());
        });
        self.add_controller(motion);
      }}
    >
      <box css="min-height: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
