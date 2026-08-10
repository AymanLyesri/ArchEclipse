import App from "ags/gtk4/app";
import { Gtk } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Astal } from "ags/gtk4";
import GLib from "gi://GLib";
import { createSubprocess } from "ags/process";
import { timeout, Timer } from "ags/time";
import { globalSettings } from "../../variables";
import { getMonitorName } from "../../utils/monitor";
import { revealBar } from "./Bar";

// One relative-motion stream shared by every monitor's strip; whichever
// strip currently holds the pointer at its edge is the armed sink. The
// pointer is pinned at the screen edge, so the compositor reports no
// motion - physical push only shows up in the raw relative deltas.
let armedSink: ((dy: number) => void) | null = null;
let pressureStreamSeen = false;
let pressureStreamStarted = false;

// Started lazily from the first strip's setup: the helper binary is
// compiled during app startup, and a failed spawn at module scope would
// take the whole bundle down with it.
function ensurePressureStream() {
  if (pressureStreamStarted) return;
  pressureStreamStarted = true;
  try {
    const stream = createSubprocess(
      null,
      `/tmp/ags-${GLib.get_user_name()}/pointer-pressure-loop-ags`,
      (out) => {
        pressureStreamSeen = true;
        const dy = parseInt(out, 10);
        if (!Number.isNaN(dy)) armedSink?.(dy);
        return null;
      },
    );
    stream.subscribe(() => {});
  } catch {
    // No motion stream - the strips' dwell fallback still reveals.
  }
}

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;

  return (
    <window
      name={`bar-hover-${monitorName}`}
      namespace="bar-hover"
      application={App}
      gdkmonitor={monitor}
      anchor={globalSettings(({ bar }) =>
        (bar.orientation.value as boolean)
          ? Astal.WindowAnchor.TOP |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT,
      )}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.TOP}
      visible={globalSettings(({ bar }) => !(bar.lock.value as boolean))}
      $={(self) => {
        setup(self);
        ensurePressureStream();

        // Pressure barrier: while the pointer sits on the outermost edge
        // pixel, physical push (raw relative motion into the edge) is
        // accumulated; crossing the threshold reveals the bar. Moving
        // away bleeds the pressure off. If the motion stream is not
        // available (no read access to /dev/input/mice), a 1s dwell on
        // the edge pixel is the fallback.
        let pressure = 0;
        let atEdge = false;
        let fallbackTimer: Timer | null = null;

        const cancelFallback = () => {
          fallbackTimer?.cancel();
          fallbackTimer = null;
        };

        const sink = (dy: number) => {
          if (!atEdge) return;
          const onTop = globalSettings.peek().bar.orientation.value as boolean;
          const push = onTop ? dy : -dy;
          pressure = Math.max(0, pressure + push);

          const threshold = globalSettings.peek().bar.revealPressure
            .value as number;
          if (pressure >= threshold) {
            pressure = 0;
            revealBar(monitorName);
          }
        };

        const leaveEdge = () => {
          atEdge = false;
          pressure = 0;
          cancelFallback();
          if (armedSink === sink) armedSink = null;
        };

        const updateEdge = (y: number) => {
          const height = Math.max(self.get_height(), 1);
          const onTop = globalSettings.peek().bar.orientation.value as boolean;
          const nowAtEdge = onTop ? y <= 1 : y >= height - 2;

          if (nowAtEdge && !atEdge) {
            atEdge = true;
            pressure = 0;
            armedSink = sink;

            const threshold = globalSettings.peek().bar.revealPressure
              .value as number;
            if (threshold <= 0) {
              revealBar(monitorName);
              return;
            }
            if (!pressureStreamSeen) {
              fallbackTimer = timeout(1000, () => {
                fallbackTimer = null;
                revealBar(monitorName);
              });
            }
          } else if (!nowAtEdge && atEdge) {
            leaveEdge();
          }
        };

        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", (_controller, _x, y) => updateEdge(y));
        motion.connect("motion", (_controller, _x, y) => updateEdge(y));
        motion.connect("leave", leaveEdge);
        self.add_controller(motion);
      }}
    >
      <box css="min-height: 5px; background-color: rgba(0,0,0,0.01);" />
    </window>
  );
};
