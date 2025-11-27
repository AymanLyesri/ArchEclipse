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
import { WidgetSelector } from "../../interfaces/widgetSelector.interface";

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;

  return (
    <window
      gdkmonitor={monitor}
      name={`bar-${monitorName}`}
      namespace="bar"
      class="Bar"
      application={App}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      anchor={barOrientation((orientation: boolean) =>
        orientation
          ? Astal.WindowAnchor.TOP |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
      )}
      margin={emptyWorkspace((empty) => (empty ? globalMargin : 5))}
      visible={createComputed(
        [barVisibility, focusedClient],
        (barVisibility, focusedClient) => {
          if (focusedClient) {
            const isFullscreen: boolean =
              focusedClient.fullscreen === 2 ||
              focusedClient.get_fullscreen?.() === 2;
            const visibility: boolean = !isFullscreen && barVisibility;
            return visibility;
          } else {
            return barVisibility;
          }
        }
      )}
      child={
        <eventbox
          onHoverLost={() => {
            if (!barLock.get()) setBarVisibility(false);
          }}
          child={
            <box
              spacing={5}
              class={emptyWorkspace((empty) =>
                empty ? "bar empty" : "bar full"
              )}
            >
              <LeftPanelVisibility />
              <centerbox
                hexpand
                children={
                  // barLayout((layout) =>
                  barLayout.get().map(
                    (widgetSelector: WidgetSelector, key: number) => {
                      // set halign based on the key
                      const halign =
                        key === 0 ? Gtk.Align.START : Gtk.Align.END;
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
                    }
                    // })
                  )
                }
              ></centerbox>
              <RightPanelVisibility />
            </box>
          }
        ></eventbox>
      }
    ></window>
  );
};
