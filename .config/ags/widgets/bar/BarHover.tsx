import App from "ags/gtk3/app";
import Gtk from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import { barOrientation, setBarVisibility } from "../../variables";
import { createBinding, createComputed } from "ags";

export default (monitor: Gdk.Monitor) => {
  return (
    <window
      name="bar-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={createComputed(() =>
        barOrientation()
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
        <eventbox
          onHover={() => {
            setBarVisibility(true);
          }}
          child={<box css="min-height: 5px;" />}
        ></eventbox>
      }
    ></window>
  );
};
