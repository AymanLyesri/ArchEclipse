import App from "ags/gtk3/app";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import { rightPanelLock, setRightPanelVisibility } from "../../variables";

export default (monitor: Gdk.Monitor) => {
  return (
    <window
      gdkmonitor={monitor}
      className="RightPanel"
      application={App}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      anchor={
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      child={
        <eventbox
          onHover={() => {
            if (!rightPanelLock()) setRightPanelVisibility(true);
          }}
          child={<box css="min-width: 1px" />}
        ></eventbox>
      }
    ></window>
  );
};
