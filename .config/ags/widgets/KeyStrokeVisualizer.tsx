import { Astal } from "ags/gtk4";
import app from "ags/gtk4/app";
import { subprocess } from "ags/process";
import Gtk from "gi://Gtk?version=4.0";
import { fullscreenClient, globalMargin, globalSettings } from "../variables";
import GLib from "gi://GLib";
import { createState, createComputed } from "ags";

interface KeyStrokeWidget {
  revealer: Gtk.Revealer;
  id: string;
}

export default () => {
  const maxKeystrokes = 5;
  const keystrokeTimeout = 3000; // milliseconds before each keystroke fades out
  const [keystrokes, setKeystrokes] = createState<KeyStrokeWidget[]>([]);

  // One persistent container
  const row = new Gtk.Box({
    spacing: 5,
    hexpand: true,
  });

  let counter = 0;

  function createKeystroke(key: string): Gtk.Revealer {
    const button = (
      <button label={key} class="keystroke" focusable={false} />
    ) as Gtk.Widget;

    const revealer = new Gtk.Revealer({
      transition_type: Gtk.RevealerTransitionType.SWING_RIGHT,
      transition_duration: 300,
      reveal_child: false,
      child: button,
    });

    return revealer;
  }

  return (
    <window
      class="keystroke-visualizer"
      application={app}
      name="keystroke-visualizer"
      namespace="keystroke-visualizer"
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.NORMAL}
      anchor={Astal.WindowAnchor.BOTTOM}
      visible={createComputed(
        () =>
          !fullscreenClient() &&
          keystrokes().length > 0 &&
          globalSettings().keyStrokeVisualizer.visibility.value,
      )}
      resizable={false}
      margin={globalMargin}
      $={() => {
        subprocess(`bash -c "./scripts/ags-keystroke-listener.sh"`, (out) => {
          const key = out.trim();
          if (!key) return;

          const revealer = createKeystroke(key);
          const id = `keystroke-${counter++}`;

          row.append(revealer);
          const newKeystrokes = [...keystrokes(), { revealer, id }];
          setKeystrokes(newKeystrokes);

          // Animate IN (next frame ensures layout exists)
          GLib.idle_add(GLib.PRIORITY_DEFAULT, () => {
            revealer.reveal_child = true;
            return GLib.SOURCE_REMOVE;
          });

          // Auto-hide after delay
          setTimeout(() => {
            const currentKeystrokes = keystrokes();
            const idx = currentKeystrokes.findIndex((ks) => ks.id === id);
            if (idx !== -1) {
              const item = currentKeystrokes[idx];
              item.revealer.transitionType =
                Gtk.RevealerTransitionType.SWING_LEFT;
              item.revealer.reveal_child = false;

              const updatedKeystrokes = currentKeystrokes.filter(
                (ks) => ks.id !== id,
              );
              setKeystrokes(updatedKeystrokes);

              // Remove after animation finishes
              setTimeout(() => {
                row.remove(item.revealer);
              }, 200);
            }
          }, keystrokeTimeout);

          // Animate OUT oldest if max exceeded
          if (newKeystrokes.length > maxKeystrokes) {
            const old = newKeystrokes[0];
            old.revealer.transitionType = Gtk.RevealerTransitionType.SWING_LEFT;
            old.revealer.reveal_child = false;

            const updatedKeystrokes = newKeystrokes.slice(1);
            setKeystrokes(updatedKeystrokes);

            // Remove after animation finishes
            setTimeout(() => {
              row.remove(old.revealer);
            }, 300);
          }
        });
      }}
    >
      <box hexpand vexpand heightRequest={28}>
        {row}
      </box>
    </window>
  );
};
