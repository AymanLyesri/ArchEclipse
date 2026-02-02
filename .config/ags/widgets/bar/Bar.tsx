import App from "ags/gtk4/app";
import { createComputed, With } from "ags";
import Workspaces from "./components/Workspaces";
import Information from "./components/Information";
import Utilities from "./components/Utilities";
import {
  emptyWorkspace,
  focusedClient,
  fullscreenClient,
  globalMargin,
  globalSettings,
} from "../../variables";
import { getMonitorName } from "../../utils/monitor";
import { WidgetSelector } from "../../interfaces/widgetSelector.interface";
import Astal from "gi://Astal?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import { RightPanelVisibility } from "../rightPanel/RightPanel";
import { LeftPanelVisibility } from "../leftPanel/LeftPanel";
import app from "ags/gtk4/app";

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;

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
      marginRight={globalMargin}
      marginLeft={globalMargin}
      visible={createComputed(
        [globalSettings, fullscreenClient],
        ({ bar }, fullscreenClient) => {
          const visibility: boolean = !fullscreenClient && bar.lock; // Hide when a client is fullscreen
          return visibility;
        },
      )}
      $={(self) => {
        setup(self);
        (self as any).monitorName = monitorName;
        const motion = new Gtk.EventControllerMotion();
        motion.connect("leave", () => {
          if (!globalSettings.peek().bar.lock)
            app.get_window(`bar-${monitorName}`)!.hide();
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
                        return <Workspaces halign={halign} $type={type} />;
                      case "information":
                        return <Information halign={halign} $type={type} />;
                      case "utilities":
                        return <Utilities halign={halign} $type={type} />;
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
