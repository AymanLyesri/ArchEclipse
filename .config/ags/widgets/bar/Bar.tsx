import App from "ags/gtk4/app";
import { createBinding, createComputed, For, With } from "ags";
import Workspaces from "./components/Workspaces";
import Information from "./components/Information";
import Utilities from "./components/Utilities";
import {
  emptyWorkspace,
  focusedClient,
  globalMargin,
  globalSettings,
  setGlobalSetting,
} from "../../variables";
import { getMonitorName } from "../../utils/monitor";
// import { LeftPanelVisibility } from "../leftPanel/LeftPanel";
// import { RightPanelVisibility } from "../rightPanel/RightPanel";
import { WidgetSelector } from "../../interfaces/widgetSelector.interface";
import Astal from "gi://Astal?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import { Eventbox } from "../Custom/Eventbox";
import { RightPanelVisibility } from "../rightPanel/RightPanel";
import { LeftPanelVisibility } from "../leftPanel/LeftPanel";

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
      anchor={globalSettings(({ bar }) => {
        return bar.orientation.value
          ? Astal.WindowAnchor.TOP |
              Astal.WindowAnchor.LEFT |
              Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
              Astal.WindowAnchor.LEFT |
              Astal.WindowAnchor.RIGHT;
      })}
      marginTop={globalMargin}
      visible={createComputed(
        [globalSettings, focusedClient],
        ({ bar }, focusedClient) => {
          if (focusedClient) {
            const isFullscreen: boolean =
              focusedClient.fullscreen === 2 ||
              focusedClient.get_fullscreen?.() === 2;
            const visibility: boolean = !isFullscreen && bar.visibility;
            return visibility;
          } else {
            return bar.visibility;
          }
        }
      )}
      $={(self) => {
        const motion = new Gtk.EventControllerMotion();
        motion.connect("leave", () => {
          if (!globalSettings.peek().bar.lock)
            setGlobalSetting("bar.visibility", false);
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
          <With value={globalSettings(({ bar }) => bar.layout)}>
            {(layout: WidgetSelector[]) => (
              <centerbox hexpand>
                {layout
                  .filter((widget) => widget.enabled)
                  .map((widget: WidgetSelector, key) => {
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
