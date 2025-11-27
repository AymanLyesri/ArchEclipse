import Gtk from "gi://Gtk?version=3.0";
import { globalTransition } from "../variables";

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
  visible?: boolean;
  revealChild?: boolean | (() => boolean);
  custom_class?: string;
  on_primary_click?: () => void;
}) => {
  const revealer: Gtk.Revealer = (
    <revealer
      revealChild={revealChild}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
      child={child}
    />
  );

  const eventBox = (
    <eventbox
      visible={visible}
      class={"custom-revealer " + custom_class}
      onHover={(self) => {
        revealer.reveal_child = true;
      }}
      onHoverLost={() => {
        revealer.reveal_child = false;
      }}
      onClick={on_primary_click}
      child={
        <box class={"content"}>
          {trigger}
          {revealer}
        </box>
      }
    />
  );

  return eventBox;
};
