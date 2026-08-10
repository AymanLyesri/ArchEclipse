import App from "ags/gtk4/app";
import { Gtk } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Astal } from "ags/gtk4";
import { createComputed } from "gnim";
import { globalSettings, hotZonePreview } from "../../variables";
import app from "ags/gtk4/app";
import { getMonitorName } from "../../utils/monitor";
import { showWindow } from "../../utils/window";

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  return (
    <window
      name="left-panel-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      visible={globalSettings(
        ({ leftPanel }) =>
          !leftPanel.lock && (leftPanel.hotZone.value as boolean),
      )}
      $={(self) => {
        setup(self);
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          showWindow(`left-panel-${getMonitorName(monitor)}`);
        });
        self.add_controller(motion);
      }}
    >
      <box
        css={createComputed(() => {
          const size = globalSettings().leftPanel.hotZoneSize.value as number;
          const background = hotZonePreview()
            ? "rgba(255, 85, 85, 0.4)"
            : "rgba(0,0,0,0.01)";
          return `min-width: ${size}px; background-color: ${background};`;
        })}
      />
    </window>
  );
};
