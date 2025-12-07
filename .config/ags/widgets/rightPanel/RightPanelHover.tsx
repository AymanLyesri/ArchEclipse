import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import {
  rightPanelLock,
  rightPanelVisibility,
  setRightPanelVisibility,
} from "../../variables";
import { Eventbox } from "../Custom/Eventbox";

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
    >
      <Eventbox
        onHover={() => {
          if (!rightPanelLock.get()) setRightPanelVisibility(true);
        }}
      >
        <box css="min-width: 1px;" />
      </Eventbox>
    </window>
  );
};
