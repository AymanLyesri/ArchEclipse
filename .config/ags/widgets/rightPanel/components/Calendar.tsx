import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib?version=2.0";
import { createPoll } from "ags/time";
import { Accessor } from "ags";

export default function ({
  className,
}: {
  className?: string | Accessor<string>;
}) {
  return (
    <box
      class={`calendarBox ${className ?? ""}`}
      orientation={Gtk.Orientation.VERTICAL}
    >
      <Gtk.Calendar
        canFocus={false}
        focusOnClick={false}
        cssClasses={["calendar"]}
      />
    </box>
  );
}
