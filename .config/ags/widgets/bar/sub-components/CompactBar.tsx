import { Gtk } from "ags/gtk4";
import Information from "../components/Information";
import Battery from "../components/sub-components/Battery";
import { WorkspacesCompact } from "../components/Workspaces";
import Volume from "../components/sub-components/Volume";

export default () =>
  (
    <box spacing={5} halign={Gtk.Align.CENTER} hexpand>
      <WorkspacesCompact />
      <Information />
      <Battery />
      <Volume />
    </box>
  ) as Gtk.Widget;
