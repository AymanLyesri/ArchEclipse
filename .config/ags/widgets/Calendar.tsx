import Gtk from "gi://Gtk?version=4.0";

export default () => {
  return <box class={"calendar"} child={<Gtk.Calendar hexpand={true} />}></box>;
};
