import { Accessor } from "ags";
import Gtk from "gi://Gtk?version=4.0";

export const Eventbox = ({
  visible = true,
  class: className = "",
  onClick = () => {},
  onHover = () => {},
  onHoverLost = () => {},
  children = [],
  tooltipText = "",
}: {
  visible?: boolean | Accessor<boolean>;
  class?: string | Accessor<string>;
  onClick?: (self: Gtk.Box, n: number, x: number, y: number) => void;
  onHover?: (self: Gtk.Box) => void;
  onHoverLost?: (self: Gtk.Box) => void;
  children?: Gtk.Widget | Gtk.Widget[] | Object;
  tooltipText?: string | Accessor<string>;
}) => {
  const box = (
    <box
      tooltipText={tooltipText}
      visible={visible}
      class={className}
      $={(self) => {
        // Hover controller
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => onHover(self));
        motion.connect("leave", () => onHoverLost(self));
        self.add_controller(motion);

        // Click controller
        const click = new Gtk.GestureClick();
        click.connect("pressed", (_, n, x, y) => onClick(self, n, x, y));
        self.add_controller(click);

        // Normalize children (single, array, nested arrays)
        const childArray = Array.isArray(children)
          ? children.flat(99)
          : [children];

        for (const child of childArray) {
          if (child) self.append(child);
        }
      }}
    />
  );

  return box;
};
