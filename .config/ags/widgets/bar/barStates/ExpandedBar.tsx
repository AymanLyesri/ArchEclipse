import { Gtk } from "ags/gtk4";
import { globalSettings } from "../../../variables";

const isEnabled = (name: string) =>
  globalSettings(
    (s) =>
      s.bar.layout.find((widget) => widget.name === name)?.enabled ?? false,
  );

export default ({
  start,
  center,
  end,
}: {
  start: Gtk.Widget;
  center: Gtk.Widget;
  end: Gtk.Widget;
}) =>
  (
    <centerbox>
      <box $type="start" visible={isEnabled("workspaces")}>
        {start}
      </box>
      <box $type="center" visible={isEnabled("information")}>
        {center}
      </box>
      <box $type="end" visible={isEnabled("utilities")}>
        {end}
      </box>
    </centerbox>
  ) as Gtk.Widget;
