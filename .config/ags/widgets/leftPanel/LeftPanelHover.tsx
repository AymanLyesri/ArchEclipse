import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import {
  leftPanelLock,
  leftPanelVisibility,
  setLeftPanelVisibility,
} from "../../variables";
import { createComputed } from "gnim";

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
      visible={createComputed(
        [leftPanelVisibility, leftPanelLock],
        (v, l) => !v && !l
      )}
      $={(self) => {
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          setLeftPanelVisibility(true);
        });
        self.add_controller(motion);
      }}
    >
      <box css="min-width: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
