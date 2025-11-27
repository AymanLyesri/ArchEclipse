import App from "ags/gtk3/app";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import { leftPanelLock, setLeftPanelVisibility } from "../../variables";

export default (monitor: Gdk.Monitor) => {
  return (
    <window
      gdkmonitor={monitor}
      class="LeftPanel"
      application={App}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      child={
        <eventbox
          onHover={() => {
            if (!leftPanelLock()) setLeftPanelVisibility(true);
          }}
          child={<box css="min-width: 1px" />}
        ></eventbox>
      }
    ></window>
  );
};
