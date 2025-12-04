import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import {
  barOrientation,
  barVisibility,
  setBarVisibility,
} from "../../variables";

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
      layer={Astal.Layer.OVERLAY}
      child={
        <Eventbox
          onHover={() => {
            print("visible", barVisibility.get());
            setBarVisibility(true);
          }}
          child={<box css="min-height: 5px;" />}
        ></Eventbox>
      }
    ></window>
  );
};
