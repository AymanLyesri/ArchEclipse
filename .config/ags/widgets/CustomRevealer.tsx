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
  tooltipText = "",
  transitionType = Gtk.RevealerTransitionType.SWING_LEFT,
}: {
  trigger: any;
  child: any;
  visible?: boolean | Accessor<boolean>;
  revealChild?: boolean | Accessor<boolean>;
  custom_class?: string | Accessor<string>;
  on_primary_click?: () => void;
  tooltipText?: string | Accessor<string>;
  transitionType?:
    | Gtk.RevealerTransitionType
    | Accessor<Gtk.RevealerTransitionType>;
}) => {
  const revealer = (
    <revealer
      revealChild={revealChild}
      transitionDuration={globalTransition}
      transitionType={transitionType}
      child={child}
    />
  );

  const _Eventbox = (
    <Eventbox
      visible={visible}
      tooltipText={tooltipText}
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
