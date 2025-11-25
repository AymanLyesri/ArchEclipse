import App from "ags/gtk3/app";
import Gtk from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import { createBinding, createComputed } from "ags";
import Workspaces from "./components/Workspaces";
import Information from "./components/Information";
import Utilities from "./components/Utilities";
import {
  barLayout,
  barLock,
  barOrientation,
  barVisibility,
  setBarVisibility,
  emptyWorkspace,
  focusedClient,
  globalMargin,
} from "../../variables";
import { getMonitorName } from "../../utils/monitor";
import { LeftPanelVisibility } from "../leftPanel/LeftPanel";
import { RightPanelVisibility } from "../rightPanel/RightPanel";

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;

  return (
    <window
      gdkmonitor={monitor}
      name={`bar-${monitorName}`}
      namespace="bar"
      className="Bar"
      application={App}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      anchor={createComputed(() =>
        barOrientation()
          ? Astal.WindowAnchor.TOP |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
      )}
      margin={createComputed(() => (emptyWorkspace() ? globalMargin : 5))}
      visible={createComputed(() => {
        const visible = barVisibility();
        const client = focusedClient();
        if (client) {
          // @ts-ignore
          const isFullscreen: boolean =
            client.fullscreen === 2 || client.get_fullscreen?.() === 2;
          const visibility: boolean = !isFullscreen && visible;
          return visibility;
        } else {
          return visible;
        }
      })}
      child={
        <eventbox
          onHoverLost={() => {
            if (!barLock()) setBarVisibility(false);
          }}
          child={
            <box
              spacing={5}
              className={createComputed(() =>
                emptyWorkspace() ? "bar empty" : "bar full"
              )}
            >
              <LeftPanelVisibility />
              <centerbox hexpand>
                {createComputed(() =>
                  barLayout().map((widgetSelector, key) => {
                    // set halign based on the key
                    const halign = key === 0 ? Gtk.Align.START : Gtk.Align.END;
                    switch (widgetSelector.name) {
                      case "workspaces":
                        return (
                          <Workspaces
                            halign={halign}
                            monitorName={monitorName}
                          />
                        );
                      case "information":
                        return (
                          <Information
                            halign={halign}
                            monitorName={monitorName}
                          />
                        );
                      case "utilities":
                        return (
                          <Utilities
                            halign={halign}
                            monitorName={monitorName}
                          />
                        );
                    }
                  })
                )}
              </centerbox>
              <RightPanelVisibility />
            </box>
          }
        ></eventbox>
      }
    ></window>
  );
};
