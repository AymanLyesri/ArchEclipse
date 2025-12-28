import App from "ags/gtk4/app";
import { createBinding, createComputed, For, With } from "ags";
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

  return (
    <window
      gdkmonitor={monitor}
      name={`bar-${monitorName}`}
      namespace="bar"
      class="Bar"
      application={App}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      anchor={barOrientation(({ value }) =>
        value
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
      $={(self) => {
        const motion = new Gtk.EventControllerMotion();
        motion.connect("leave", () => {
          if (!barLock.get()) setBarVisibility(false);
        });
        self.add_controller(motion);
      }}
    >
      <box
        spacing={5}
        class={emptyWorkspace((empty) => (empty ? "bar empty" : "bar full"))}
      >
        <LeftPanelVisibility />

        <box class="bar-center" hexpand>
          <With value={barLayout}>
            {(layout) => (
              <centerbox hexpand>
                {layout.map((widget: WidgetSelector, key) => {
                  const types =
                    layout.length === 1
                      ? ["center"]
                      : layout.length === 2
                      ? ["start", "end"]
                      : ["start", "center", "end"];
                  const type = types[key];
                  const halign =
                    type === "start"
                      ? Gtk.Align.START
                      : type === "center"
                      ? Gtk.Align.CENTER
                      : Gtk.Align.END;
                  switch (widget.name) {
                    case "workspaces":
                      return (
                        <Workspaces
                          halign={halign}
                          $type={type}
                          monitorName={monitorName}
                        />
                      );
                    case "information":
                      return (
                        <Information
                          halign={halign}
                          $type={type}
                          monitorName={monitorName}
                        />
                      );
                    case "utilities":
                      return (
                        <Utilities
                          halign={halign}
                          $type={type}
                          monitorName={monitorName}
                        />
                      );
                    default:
                      return <box />;
                  }
                })}
              </centerbox>
            )}
          </With>
        </box>

        <RightPanelVisibility />
      </box>
    </window>
  );
};
