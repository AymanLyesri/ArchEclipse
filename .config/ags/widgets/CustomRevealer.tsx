import Gtk from "gi://Gtk?version=4.0";
import { globalTransition } from "../variables";
import { Eventbox } from "./Custom/Eventbox";
import { Accessor } from "ags";

export default ({
  trigger,
  child,
  visible = true,
  revealChild = false,
  custom_class = "",
  on_primary_click = () => {},
}: {
  trigger: any;
  child: any;
  visible?: boolean | Accessor<boolean>;
  revealChild?: boolean | Accessor<boolean>;
  custom_class?: string | Accessor<string>;
  on_primary_click?: () => void;
}) => {
  const revealer = (
    <revealer
      revealChild={revealChild}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SWING_LEFT}
      child={child}
    />
  );

  const _Eventbox = (
    <Eventbox
      visible={visible}
      class={"custom-revealer " + custom_class}
      onHover={(self) => {
        (revealer as Gtk.Revealer).reveal_child = true;
      }}
      onHoverLost={() => {
        (revealer as Gtk.Revealer).reveal_child = false;
      }}
      onClick={() => on_primary_click()}
    >
      <box class={"content"}>
        {trigger}
        {revealer}
      </box>
    </Eventbox>
  );

  return _Eventbox;
};
