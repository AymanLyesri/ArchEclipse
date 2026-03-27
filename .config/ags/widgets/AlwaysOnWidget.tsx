import { Astal, Gdk, Gtk } from "ags/gtk4";
import { getMonitorName } from "../utils/monitor";
import app from "ags/gtk4/app";
import { Weather } from "./Weather";
import { fullscreenClient, globalMargin, globalSettings } from "../variables";
import { createComputed } from "gnim";

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
      layer={Astal.Layer.BOTTOM}
      gdkmonitor={monitor}
      namespace="always-on-widget"
      name={`always-on-widget-${monitorName}`}
      application={app}
      visible={createComputed(() => {
        return (
          globalSettings().alwaysOnWidget.visibility.value &&
          !fullscreenClient()
        );
      })}
      keymode={Astal.Keymode.ON_DEMAND}
      exclusivity={Astal.Exclusivity.IGNORE}
      anchor={Astal.WindowAnchor.LEFT | Astal.WindowAnchor.BOTTOM}
      margin={globalMargin((m) => m * 3)}
      $={async (self) => {
        // setup(self);
      }}
    >
      <Weather />
    </window>
  );
};
