import { Gtk } from "ags/gtk4";
import Information from "../components/Information";
import Battery from "../components/sub-components/Battery";
import { WorkspacesCompact } from "../components/Workspaces";
import Volume from "../components/sub-components/Volume";

export default ({ components }: { components: Gtk.Widget[] }) =>
  (
    <box spacing={5} halign={Gtk.Align.CENTER} hexpand>
      {components.map((component, index) => (
        <box>{component}</box>
      ))}
    </box>
  ) as Gtk.Widget;
