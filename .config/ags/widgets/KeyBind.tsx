import { Gtk } from "ags/gtk4";
import { Accessor } from "gnim";

interface KeyBindProps {
  bindings: string[];
  className?: string;
  onButtonClick?: (binding: string, index: number) => void;
  halign?: Gtk.Align | Accessor<Gtk.Align> | undefined;
}

export default function ({
  bindings,
  className = "",
  onButtonClick,
  halign,
}: KeyBindProps) {
  return (
    <box class={`keybind ${className}`} spacing={5} halign={halign}>
      {bindings.map((binding, index) => (
        <>
          <button
            class="binding"
            onClicked={() => {
              if (onButtonClick) {
                onButtonClick(binding, index);
              }
            }}
          >
            <label label={binding} />
          </button>
          {index < bindings.length - 1 && <label label="+" />}
        </>
      ))}
    </box>
  );
}
