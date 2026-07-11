import { createState, Accessor } from "ags";
import GLib from "gi://GLib";
import Cava from "gi://AstalCava";
import { globalTransition } from "../variables";
import { Gtk } from "ags/gtk4";

// Use a single cava instance for all widgets
const cava = Cava.get_default()!;

// --- Tunable constants ---
const CAVA_UPDATE_MS = 100;
const DEFAULT_BAR_COUNT = 12;

// Global signal connection (only ONE for all widgets)
let cavaValues: number[] | null = null;
let globalSignalId: number | null = null;
let refCount = 0;

// Small lightweight throttle/coalesce helper
function scheduleCoalesced(fn: () => void, delayMs: number) {
  let timeoutId: number | null = null;
  let pending = false;
  return (triggerFn?: () => void) => {
    if (triggerFn) triggerFn();
    if (pending) return;
    pending = true;
    timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delayMs, () => {
      pending = false;
      timeoutId = null;
      try {
        fn();
      } catch (e) {
        console.error(e);
      }
      return GLib.SOURCE_REMOVE;
    });
  };
}

// Global callback list for value updates
const updateCallbacks: Set<() => void> = new Set();

function ensureCavaConnected() {
  if (refCount === 0 && globalSignalId === null) {
    globalSignalId =
      cava?.connect("notify::values", () => {
        cavaValues = cava.get_values() || null;
        // Notify all widgets about new values. Snapshot the callbacks
        // first: widgets can be destroyed/created synchronously as a
        // reaction to this same notification (e.g. MPRIS players
        // appearing/disappearing), which would otherwise mutate
        // updateCallbacks mid-iteration.
        const callbacksSnapshot = Array.from(updateCallbacks);
        callbacksSnapshot.forEach((cb) => {
          try {
            cb();
          } catch (e) {
            console.error(e);
          }
        });
      }) || null;
  }
  refCount++;
}

function releaseCavaConnection() {
  refCount--;
  if (refCount === 0 && globalSignalId !== null) {
    const idToDisconnect = globalSignalId;
    // We may be called from inside the "notify::values" handler itself
    // (e.g. a player disappears and its widget is destroyed synchronously
    // while updateCallbacks.forEach() is still iterating during the same
    // signal emission). Disconnecting a GObject signal from inside its
    // own emission corrupts GObject's internal signal-handler bookkeeping
    // and was the actual source of the g_array_remove_range assertion —
    // deferring to an idle callback guarantees we only disconnect once
    // the current emission has fully finished.
    globalSignalId = null;
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      // Only disconnect if nothing re-subscribed in the meantime.
      if (refCount === 0) {
        try {
          cava?.disconnect(idToDisconnect);
        } catch (e) {}
      }
      return GLib.SOURCE_REMOVE;
    });
  }
}

export default ({
  transitionType,
  barCount = 12,
  isPlaying = true,
}: {
  transitionType: Gtk.RevealerTransitionType;
  barCount?: number;
  isPlaying?: Accessor<boolean> | boolean;
}) => {
  print(
    `[Cava] Initialized with ${barCount} bars and transition type ${transitionType}`,
  );
  // Connect to global cava signal (only once for all widgets)
  ensureCavaConnected();

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
  const BAR_COUNT = barCount || DEFAULT_BAR_COUNT;
  const EMPTY_BARS = "".padEnd(BAR_COUNT, "\u2581");
  let barArray: string[] = new Array(BAR_COUNT);
  let lastBarString = "";

  const REVEAL_SHOW_DELAY = 0;
  const REVEAL_HIDE_DELAY = 2000;
  let visible = false;
  let showTimeoutId: number | null = null;
  let hideTimeoutId: number | null = null;

  let revealerInstance: Gtk.Revealer | null = null;

  const getIsPlaying = () => {
    if (typeof isPlaying === "function") {
      return (isPlaying as Accessor<boolean>)();
    }
    return !!isPlaying;
  };

  const clearTimeoutIfSet = (timeoutId: number | null) => {
    if (!timeoutId) return null;
    try {
      GLib.source_remove(timeoutId);
    } catch (e) {}
    return null;
  };

  let unsubscribeIsPlaying: (() => void) | null = null;

  // Callback for global cava updates
  const onCavaUpdate = () => {
    if (getIsPlaying()) {
      schedule();
    }
  };

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
          showTimeoutId = clearTimeoutIfSet(showTimeoutId);
          hideTimeoutId = clearTimeoutIfSet(hideTimeoutId);

          if (unsubscribeIsPlaying) {
            unsubscribeIsPlaying();
            unsubscribeIsPlaying = null;
          }

          // Remove from global callbacks
          updateCallbacks.delete(onCavaUpdate);

          // Release global cava connection
          releaseCavaConnection();
        }}
        label={getBars}
      />
    </revealer>
  );

  // Create coalesced updater
  const doUpdate = () => {
    if (!getIsPlaying()) {
      showTimeoutId = clearTimeoutIfSet(showTimeoutId);
      hideTimeoutId = clearTimeoutIfSet(hideTimeoutId);
      visible = false;
      if (revealerInstance) revealerInstance.reveal_child = false;
      if (lastBarString !== EMPTY_BARS) {
        lastBarString = EMPTY_BARS;
        setBars(EMPTY_BARS);
      }
      return;
    }

    const values = cavaValues;
    if (!values || values.length === 0) {
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

    if (b === lastBarString) return;
    lastBarString = b;

    setBars(b);

    const isEmpty = b === EMPTY_BARS;

    if (!isEmpty) {
      if (hideTimeoutId) {
        try {
          GLib.source_remove(hideTimeoutId);
        } catch (e) {}
        hideTimeoutId = null;
      }

      if (!visible && !showTimeoutId) {
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
        if (revealerInstance) revealerInstance.reveal_child = true;
      }
    } else {
      if (showTimeoutId) {
        try {
          GLib.source_remove(showTimeoutId);
        } catch (e) {}
        showTimeoutId = null;
      }

      if (visible && !hideTimeoutId) {
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
        if (revealerInstance) revealerInstance.reveal_child = false;
      }
    }
  };

  const schedule = scheduleCoalesced(doUpdate, CAVA_UPDATE_MS);

  if (typeof isPlaying === "function") {
    const playableAccessor = isPlaying as Accessor<boolean> & {
      subscribe?: (callback: () => void) => () => void;
    };
    if (typeof playableAccessor.subscribe === "function") {
      unsubscribeIsPlaying = playableAccessor.subscribe(() => {
        schedule();
      });
    }
  }

  // Register for global cava updates
  updateCallbacks.add(onCavaUpdate);

  // Schedule initial update
  schedule();

  return revealer;
};
