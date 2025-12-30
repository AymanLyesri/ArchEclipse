import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib?version=2.0";
import { createPoll } from "ags/time";

export default function () {
  return (
    <box cssClasses={["calendarBox"]} orientation={Gtk.Orientation.VERTICAL}>
      <Gtk.Calendar
        canFocus={false}
        focusOnClick={false}
        cssClasses={["calendar"]}
      />
    </box>
  );
}
