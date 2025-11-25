import Gtk from "gi://Gtk?version=3.0";

export interface WidgetSelector {
  name: string;
  icon: string;
  // make arg0 not necessary
  widget: (...arg0: any) => Gtk.Widget;
  widgetInstance?: Gtk.Widget; // To track the active widget instance
}
