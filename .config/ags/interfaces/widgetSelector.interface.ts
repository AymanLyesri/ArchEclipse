import Gtk from "gi://Gtk?version=4.0";
import { Accessor } from "gnim";

export interface WidgetSelector {
  name: string;
  icon: string;
  // make arg0 not necessary
  widget: ({
    width,
    height,
    halign,
    className,
  }: {
    width?: number | Accessor<number>;
    height?: number | Accessor<number>;
    halign?: Gtk.Align | Accessor<Gtk.Align>;
    className?: string | Accessor<string>;
  }) => Gtk.Widget | Object;
  widgetInstance?: Gtk.Widget; // To track the active widget instance
  enabled: boolean;
}
