import { Gtk } from "ags/gtk4";
import { Accessor, With } from "ags";
import { globalTransition } from "../variables";
import { createState } from "ags";
import GLib from "gi://GLib";
import { timeout, Timer } from "ags/time";

const Spinner = () => <Gtk.Spinner spinning={true} />;
export const Progress = ({
  status,
  text,
  custom_class = "",
  transitionType = Gtk.RevealerTransitionType.SLIDE_DOWN,
  showWhenIdle = false,
}: {
  status: Accessor<"loading" | "error" | "success" | "idle">;
  text?: Accessor<string>;
  custom_class?: string;
  transitionType?: Gtk.RevealerTransitionType;
  showWhenIdle?: boolean;
}) => {
  //calculate the latency between the start of the loading and the success status
  const displayLatency = () => {
    let startTime: number | null = null;

    return (
      <label
        label={"0"}
        visible={status((s) => s === "success" || s === "error")}
        $={(self) => {
          status.subscribe(() => {
            const currentStatus = status.get();
            if (currentStatus === "loading") {
              startTime = GLib.get_monotonic_time();
            } else if (currentStatus === "success" && startTime !== null) {
              const endTime = GLib.get_monotonic_time();
              const latencySeconds = (endTime - startTime) / 1_000_000;
              self.label = `${latencySeconds.toFixed(2)}s`;
              startTime = null; // reset for the next loading cycle
            }
          });
        }}
      ></label>
    );
  };

  return (
    <revealer
      class={`progress-widget ${custom_class}`}
      transitionDuration={globalTransition}
      transitionType={transitionType}
      $={(self) => {
        let Timeout: Timer | null = null;

        status.subscribe(() => {
          const newStatus = status.peek();
          if (newStatus === "success") {
            // Reveal only if shouldReveal is true
            self.revealChild = true;
            Timeout = timeout(3000, () => {
              self.revealChild = false;
              Timeout = null;
            });
          } else if (newStatus === "loading" || newStatus === "error") {
            // Cancel the hide timeout if status becomes loading again
            if (Timeout !== null) {
              Timeout.cancel();
              Timeout = null;
            }
            self.revealChild = true;
          } else {
            self.revealChild = showWhenIdle;
          }
        });
      }}
    >
      <box class={status((status) => `progress ${status}`)} spacing={5} hexpand>
        <box class="progress-icon">
          <With value={status}>
            {(status) =>
              status === "error" ? (
                <label class="progress-error" label="❌" />
              ) : status === "success" ? (
                <label class="progress-success" label="✅" />
              ) : status === "loading" ? (
                <Spinner />
              ) : null
            }
          </With>
        </box>
        <box class="progress-content">
          <label class="progress-text" label={text ?? status} />
        </box>
        <box class="progress-latency" halign={Gtk.Align.END} hexpand>
          {displayLatency()}
        </box>
      </box>
    </revealer>
  );
};
