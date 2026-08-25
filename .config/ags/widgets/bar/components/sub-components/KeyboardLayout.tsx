import { createState, createComputed } from "ags";
import { Gtk } from "ags/gtk4";
import { execAsync } from "ags/process";
import {
  keyboardLayout,
  keyboardLayoutName,
  flagEmoji,
} from "../../../../services/keyboard-layout";
import { Eventbox } from "../../../Custom/Eventbox";

export default function KeyboardLayout() {
  const [showFlag, setShowFlag] = createState(false);

  const displayLabel = createComputed(
    [keyboardLayout, showFlag],
    (layout, flag) => {
      if (!flag) return layout;
      return flagEmoji(layout) ?? layout;
    },
  );

  return (
    <box
      $={(self) => {
        const rightClick = new Gtk.GestureClick({ button: 3 });
        rightClick.connect("pressed", () => setShowFlag((prev) => !prev));
        self.add_controller(rightClick);
      }}
    >
      <Eventbox
        tooltipText={keyboardLayoutName}
        onClick={() => {
          void execAsync([
            "hyprctl",
            "switchxkblayout",
            "current",
            "next",
          ]).catch((error) =>
            printerr(`keyboard-layout: failed to switch layout: ${error}`),
          );
        }}
      >
        <label
          class="keyboard-layout"
          label={displayLabel}
          visible={keyboardLayout((layout) => layout.length > 0)}
          valign={Gtk.Align.CENTER}
        />
      </Eventbox>
    </box>
  );
}
