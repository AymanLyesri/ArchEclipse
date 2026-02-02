import { Astal } from "ags/gtk4";
import app from "ags/gtk4/app";
import { subprocess } from "ags/process";
import Gtk from "gi://Gtk?version=4.0";
import { fullscreenClient, globalMargin, globalSettings } from "../variables";
import GLib from "gi://GLib";
import { createState, createComputed } from "ags";
import { timeout, Timer } from "ags/time";

interface KeyStrokeWidget {
  revealer: Gtk.Revealer;
  id: string;
}

export default ({ setup }: { setup: (self: Gtk.Window) => void }) => {
  const maxKeystrokes = 5;
  const hideDelay = 2000; // milliseconds of inactivity before hiding the window
  const [keystrokes, setKeystrokes] = createState<KeyStrokeWidget[]>([]);

  // One persistent container
  const row = new Gtk.Box({
    spacing: 5,
    hexpand: true,
  });

  let counter = 0;
  let hideTimer: number | null = null;

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
      anchor={globalSettings((settings) => {
        const anchor = settings.keyStrokeVisualizer.anchor.value;
        if (Array.isArray(anchor)) {
          let result = Astal.WindowAnchor.NONE;
          for (const a of anchor) {
            switch (a) {
              case "bottom":
                result |= Astal.WindowAnchor.BOTTOM;
                break;
              case "left":
                result |= Astal.WindowAnchor.LEFT;
                break;
              case "right":
                result |= Astal.WindowAnchor.RIGHT;
                break;
              case "top":
                result |= Astal.WindowAnchor.TOP;
                break;
            }
          }
          return result;
        }
        return Astal.WindowAnchor.BOTTOM;
      })}
      visible={createComputed(
        () =>
          !fullscreenClient() &&
          keystrokes().length > 0 &&
          globalSettings().keyStrokeVisualizer.visibility.value,
      )}
      resizable={false}
      margin={globalMargin}
      $={(self) => {
        setup(self);
        let Timeout: Timer | null = null;
        subprocess(`./assets/binaries/keystroke-loop-ags`, (out) => {
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
          // Reset hide timer on each keystroke
          if (Timeout !== null) {
            Timeout.cancel();
            Timeout = null;
          }

          // Set timer to hide window after inactivity
          Timeout = timeout(hideDelay, () => {
            // Clear all keystrokes
            const currentKeystrokes = keystrokes();
            currentKeystrokes.forEach((ks) => {
              ks.revealer.reveal_child = false;
              setTimeout(() => {
                row.remove(ks.revealer);
              });
            });
            setKeystrokes([]);
          });
        });
      }}
    >
      <box hexpand vexpand heightRequest={28}>
        {row}
      </box>
    </window>
  );
};
