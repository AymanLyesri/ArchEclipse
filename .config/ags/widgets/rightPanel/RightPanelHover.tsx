import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import {
  rightPanelLock,
  rightPanelVisibility,
  setRightPanelVisibility,
} from "../../variables";
import { createComputed } from "gnim";

export default (monitor: Gdk.Monitor) => {
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
      visible={createComputed(
        [rightPanelVisibility, rightPanelLock],
        (v, l) => !v && !l
      )}
      $={(self) => {
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          setRightPanelVisibility(true);
        });
        self.add_controller(motion);
      }}
    >
      <box css="min-width: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
