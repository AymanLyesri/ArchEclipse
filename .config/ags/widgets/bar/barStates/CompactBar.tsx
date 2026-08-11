import { Gtk } from "ags/gtk4";

export default ({ components }: { components: Gtk.Widget[] }) =>
  (
    <box spacing={5} halign={Gtk.Align.CENTER} hexpand>
      {components.map((component) => (
        <box>{component}</box>
      ))}
    </box>
  ) as Gtk.Widget;
