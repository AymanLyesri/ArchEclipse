import { Gtk } from "astal/gtk3";

export interface WidgetSelector {
  name: string;
  icon: string;
  // make arg0 not necessary
  widget: (...arg0: any) => Gtk.Widget;
  widgetInstance?: Gtk.Widget; // To track the active widget instance
}
