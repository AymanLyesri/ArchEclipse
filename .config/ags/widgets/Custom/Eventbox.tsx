import Gtk from "gi://Gtk?version=4.0";

export const Eventbox = ({
  visible = true,
  class: className = "",
  onClick = () => {},
  onHover = () => {},
  onHoverLost = () => {},
  children = [],
}: {
  visible?: boolean;
  class?: string;
  onClick?: (self: Gtk.Box, n: number, x: number, y: number) => void;
  onHover?: (self: Gtk.Box) => void;
  onHoverLost?: (self: Gtk.Box) => void;
  children?: Gtk.Widget | Gtk.Widget[];
}) => {
  const box = new Gtk.Box({
    visible,
    css_classes: className ? className.split(" ").filter(Boolean) : [],
  });

  // Hover controller
  const motion = new Gtk.EventControllerMotion();
  motion.connect("enter", () => onHover(box));
  motion.connect("leave", () => onHoverLost(box));
  box.add_controller(motion);

  // Click controller
  const click = new Gtk.GestureClick();
  click.connect("pressed", (_, n, x, y) => onClick(box, n, x, y));
  box.add_controller(click);

  // Normalize children (single, array, nested arrays)
  const childArray = Array.isArray(children) ? children.flat(99) : [children];

  for (const child of childArray) {
    if (child) box.append(child);
  }

  return box;
};
