import { createBinding, createComputed } from "ags";
import Player from "./Player";

import Mpris from "gi://AstalMpris";
import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
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
          class="media-popup"
          child={
            <Eventbox
              onHoverLost={() => hideWindow(`media-${monitorName}`)}
              child={
                <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
                  {createComputed(() =>
                    players().map((player) => (
                      <Eventbox
                        class={"player-Eventbox"}
                        child={<Player player={player} playerType="popup" />}
                      />
                    ))
                  )}
                </box>
              }
            ></Eventbox>
          }
        ></box>
      }
    ></window>
  );
};
