import { createState, Accessor } from "ags";
import GLib from "gi://GLib?version=2.0";
import Cava from "gi://AstalCava";
import { globalTransition } from "../variables";
import Gtk from "gi://Gtk?version=4.0";
const cava = Cava.get_default()!;

// --- Tunable constants (change to lower CPU usage) ---
const CAVA_UPDATE_MS = 100; // coalesced update interval for audio visualizer (larger => less CPU)

// Small lightweight throttle/coalesce helper
function scheduleCoalesced(fn: () => void, delayMs: number) {
  let timeoutId: number | null = null;
  let pending = false;
  return (triggerFn?: () => void) => {
    if (triggerFn) triggerFn();
    if (pending) return; // already scheduled
    pending = true;
    timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delayMs, () => {
      pending = false;
      timeoutId = null;
      try {
        fn();
      } catch (e) {
        // swallow errors to avoid crashing the scheduler
        console.error(e);
      }
      return GLib.SOURCE_REMOVE;
    });
  };
}

export default ({
  transitionType,
  barCount = 12, // Default to 12 if not specified
}: {
  transitionType: Gtk.RevealerTransitionType;
  barCount?: number; // Optional bar count parameter
}) => {
  // Set the number of bars in cava to match our barCount
  cava?.set_bars(barCount);
  const [getBars, setBars] = createState("");

  const BLOCKS = [
    "\u2581",
    "\u2582",
    "\u2583",
    "\u2584",
    "\u2585",
    "\u2586",
    "\u2587",
    "\u2588",
  ];
  const BLOCKS_LENGTH = BLOCKS.length;
  const BAR_COUNT = barCount; // Use the parameter
  const EMPTY_BARS = "".padEnd(BAR_COUNT, "\u2581");
  // Reuse buffer to avoid allocations on every update
  let barArray: string[] = new Array(BAR_COUNT);
  let lastBarString = "";

  // visibility hysteresis: ignore short silence gaps
  const REVEAL_SHOW_DELAY = 300; // ms before showing on non-empty
  const REVEAL_HIDE_DELAY = 2000; // ms before hiding on empty
  let visible = false;
  let showTimeoutId: number | null = null;
  let hideTimeoutId: number | null = null;

  let revealerInstance: Gtk.Revealer | null = null;

  const revealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={transitionType}
      $={(self) => (revealerInstance = self)}
    >
      <label
        class={"cava"}
        onDestroy={() => {
          // bars.drop(); // No drop in signals
          if (showTimeoutId) {
            try {
              GLib.source_remove(showTimeoutId);
            } catch (e) {}
            showTimeoutId = null;
          }
          if (hideTimeoutId) {
            try {
              GLib.source_remove(hideTimeoutId);
            } catch (e) {}
            hideTimeoutId = null;
          }
        }}
        label={getBars}
      />
    </revealer>
  );

  // Create coalesced updater so frequent "notify::values" calls are batched
  const doUpdate = () => {
    const values = lastValuesCache;
    // build barArray for current values; if no values treat as empty
    if (!values || values.length === 0) {
      // fill with empty blocks
      for (let j = 0; j < BAR_COUNT; j++) barArray[j] = BLOCKS[0];
    } else {
      if (barArray.length !== values.length)
        barArray = new Array(values.length);
      for (let i = 0; i < values.length && i < BAR_COUNT; i++) {
        const val = values[i];
        const idx = Math.min(
          Math.floor(val * BLOCKS_LENGTH),
          BLOCKS_LENGTH - 1,
        );
        barArray[i] = BLOCKS[idx];
      }
      for (let j = values.length; j < BAR_COUNT; j++) barArray[j] = BLOCKS[0];
    }

    const b = barArray.join("");

    // if nothing changed, skip heavy work
    if (b === lastBarString) return;
    lastBarString = b;

    // update bound text (cheap) but control reveal/hide with timers (hysteresis)
    setBars(b);

    const isEmpty = b === EMPTY_BARS;

    if (!isEmpty) {
      // audio present -> ensure we will show, cancel any hide timer
      if (hideTimeoutId) {
        try {
          GLib.source_remove(hideTimeoutId);
        } catch (e) {}
        hideTimeoutId = null;
      }

      if (!visible && !showTimeoutId) {
        // schedule show after short delay (ignore brief silence gaps)
        showTimeoutId = GLib.timeout_add(
          GLib.PRIORITY_DEFAULT,
          REVEAL_SHOW_DELAY,
          () => {
            visible = true;
            if (revealerInstance) revealerInstance.reveal_child = true;
            showTimeoutId = null;
            return GLib.SOURCE_REMOVE;
          },
        );
      } else if (visible) {
        // already visible -- ensure revealer stays revealed
        if (revealerInstance) revealerInstance.reveal_child = true;
      }
    } else {
      // empty -> cancel any pending show and schedule hide if currently visible
      if (showTimeoutId) {
        try {
          GLib.source_remove(showTimeoutId);
        } catch (e) {}
        showTimeoutId = null;
      }

      if (visible && !hideTimeoutId) {
        // schedule hide after a longer delay (ignore short silence gaps)
        hideTimeoutId = GLib.timeout_add(
          GLib.PRIORITY_DEFAULT,
          REVEAL_HIDE_DELAY,
          () => {
            visible = false;
            if (revealerInstance) revealerInstance.reveal_child = false;
            hideTimeoutId = null;
            return GLib.SOURCE_REMOVE;
          },
        );
      } else if (!visible) {
        // already hidden
        if (revealerInstance) revealerInstance.reveal_child = false;
      }
    }
  };

  let lastValuesCache: number[] | null = null;
  const schedule = scheduleCoalesced(doUpdate, CAVA_UPDATE_MS);

  cava?.connect("notify::values", () => {
    // store latest values, schedule an update if not already scheduled
    lastValuesCache = cava.get_values() || null;
    schedule();
  });

  return revealer;
};
