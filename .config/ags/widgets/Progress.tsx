import Gtk from "gi://Gtk?version=4.0";
import { Accessor, With } from "ags";
import { globalTransition } from "../variables";
import { createState } from "ags";
import GLib from "gi://GLib?version=2.0";
import { timeout } from "ags/time";

const Spinner = () => <Gtk.Spinner spinning={true} />;
export const Progress = ({
  status,
  custom_class = "",
  transitionType = Gtk.RevealerTransitionType.SLIDE_DOWN,
}: {
  status:
    | Accessor<"loading" | "error" | "success" | "idle">
    | "loading"
    | "error"
    | "success"
    | "idle";
  custom_class?: string;
  transitionType?: Gtk.RevealerTransitionType;
}) => {
  return (
    <revealer
      class={`progress-widget ${custom_class}`}
      transitionDuration={globalTransition}
      transitionType={transitionType}
      $={(self) => {
        if (typeof status === "string") {
          self.revealChild = status === "loading" || status === "success";
          return;
        }

        status.subscribe(() => {
          const newStatus = status.get();
          if (newStatus === "success") {
            // Reveal only if shouldReveal is true
            self.revealChild = true;
            timeout(3000, () => {
              self.revealChild = false;
            });
          } else if (newStatus === "loading" || newStatus === "error") {
            self.revealChild = true;
          } else {
            self.revealChild = false;
          }
        });
      }}
    >
      {
        /* Content */
        typeof status === "string" ? (
          <box spacing={5} hexpand>
            <box class="progress-icon">
              {status === "error" ? (
                <label class="progress-error" label="❌" />
              ) : status === "success" ? (
                <label class="progress-success" label="✅" />
              ) : status === "loading" ? (
                <Spinner />
              ) : null}
            </box>
            <box class="progress-content">
              <label class="progress-text" label={status} />
            </box>
          </box>
        ) : (
          <box
            class={status((status) => `progress ${status}`)}
            spacing={5}
            hexpand
          >
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
              <label class="progress-text" label={status} />
            </box>
          </box>
        )
      }
    </revealer>
  );
};
// const BLOCKS = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];

// const LoadingBarsLabel = ({
//   barCount = 10,
//   maxLevel = 5, // numeric "5"
//   interval = 50,
//   className = "loading-bars",
// }: {
//   barCount?: number;
//   maxLevel?: number;
//   interval?: number;
//   className?: string;
// }) => {
//   const [getText, setText] = createState("");

//   let pos = 0;
//   let dir = 1; // 1 → right, -1 → left
//   let timeoutId: number | null = null;

//   const tick = () => {
//     const bars = new Array(barCount);

//     for (let i = 0; i < barCount; i++) {
//       const dist = Math.abs(i - pos);
//       const level = Math.max(0, maxLevel - dist);
//       const idx = Math.min(level, BLOCKS.length - 1);
//       bars[i] = BLOCKS[idx];
//     }

//     setText(bars.join(""));

//     // ping-pong movement
//     if (pos === barCount - 1) dir = -1;
//     else if (pos === 0) dir = 1;
//     pos += dir;

//     return GLib.SOURCE_CONTINUE;
//   };

//   return (
//     <label
//       class={className}
//       label={getText}
//       $={() => {
//         timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, interval, tick);
//       }}
//       onDestroy={() => {
//         if (timeoutId) {
//           try {
//             GLib.source_remove(timeoutId);
//           } catch {}
//           timeoutId = null;
//         }
//       }}
//     />
//   );
// };
