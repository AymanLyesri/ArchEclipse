import { createBinding, createComputed } from "ags";
import Player from "./Player";

import Mpris from "gi://AstalMpris";
import App from "ags/gtk3/app";
import Gtk from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import { barOrientation, globalMargin } from "../variables";
import { hideWindow } from "../utils/window";
import { getMonitorName } from "../utils/monitor";

const mpris = Mpris.get_default();
const players = createBinding(mpris, "players");

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor);
  return (
    <window
      gdkmonitor={monitor}
      name={`media-${monitorName}`}
      namespace={"media"}
      application={App}
      anchor={createComputed(() =>
        barOrientation() ? Astal.WindowAnchor.TOP : Astal.WindowAnchor.BOTTOM
      )}
      margin={globalMargin}
      visible={false}
      child={
        <box
          className="media-popup"
          child={
            <eventbox
              onHoverLost={() => hideWindow(`media-${monitorName}`)}
              child={
                <box vertical={true} spacing={10}>
                  {createComputed(() =>
                    players().map((player) => (
                      <eventbox
                        className={"player-eventbox"}
                        child={<Player player={player} playerType="popup" />}
                      />
                    ))
                  )}
                </box>
              }
            ></eventbox>
          }
        ></box>
      }
    ></window>
  );
};
