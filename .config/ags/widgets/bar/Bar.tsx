import App from "ags/gtk4/app";
import { createBinding, createComputed, For } from "ags";
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
import Astal from "gi://Astal?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import { Eventbox } from "../Custom/Eventbox";

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;
  function widget_halign(widgetName: string) {
    return barLayout((layout) => {
      const index = layout.findIndex((w) => w.name === widgetName);

      if (index === -1) return Gtk.Align.CENTER; // fallback if not found

      switch (layout[index].name) {
        case "workspaces":
          return Gtk.Align.START;
        case "information":
          return Gtk.Align.CENTER;
        case "utilities":
          return Gtk.Align.END;
        default:
          return Gtk.Align.CENTER;
      }
    });
  }

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
    >
      <box
        spacing={5}
        class={emptyWorkspace((empty) => (empty ? "bar empty" : "bar full"))}
      >
        <LeftPanelVisibility />
        <centerbox hexpand>
          <Workspaces
            halign={widget_halign("workspaces")}
            $type="start"
            monitorName={monitorName}
          />
          <Information
            halign={widget_halign("information")}
            $type="center"
            monitorName={monitorName}
          />
          <Utilities
            halign={widget_halign("utilities")}
            $type="end"
            monitorName={monitorName}
          />
        </centerbox>
        <RightPanelVisibility />
      </box>
    </window>
  );
};
