import {
  Accessor,
  createBinding,
  createComputed,
  createState,
  With,
} from "ags";
import Workspaces, { WorkspacesCompact } from "./components/Workspaces";
import Information from "./components/Information";
import Utilities from "./components/Utilities";
import {
  fullscreenClient,
  globalMargin,
  globalSettings,
} from "../../variables";
import { getMonitorName } from "../../utils/monitor";
import { WidgetSelector } from "../../interfaces/widgetSelector.interface";
import { Astal } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Gtk } from "ags/gtk4";
import app from "ags/gtk4/app";
import { interval, timeout, Timer } from "ags/time";
import { Window } from "../../utils/window";
import Volume from "./components/sub-components/Volume";
import Battery from "./components/sub-components/Battery";
import Wp from "gi://AstalWp";
import Brightness from "../../services/brightness";
import BrightnessWidget from "./components/sub-components/BrightnessWidget";
import Recording from "./components/sub-components/Recording";
import { isRecording } from "../../services/record.service";
import AppLauncher from "../applauncher/AppLauncher";
import GLib from "gi://GLib";
import AstalMpris from "gi://AstalMpris";
import PlayerWidget from "./components/sub-components/PlayerWidget";
import NetworkWidget from "./sub-components/NetworkWidget";
import CompactBar from "./sub-components/CompactBar";
import ExpandedBar from "./sub-components/ExpandedBar";

const mpris = AstalMpris.get_default();

export type BarStateName =
  | "compact"
  | "expanded"
  | "recording"
  | "volume"
  | "brightness"
  | "search"
  | "player"
  | "network";

// =============================================================================
// PER-MONITOR ISOLATION (see default export below)
// =============================================================================
// In the previous iteration of this refactor, `barState`, `stackVisibleChild`,
// and `activeStates` (the whole priority resolver) lived at module scope --
// meaning every monitor's bar shared ONE resolver. Hovering monitor A's bar
// to expand it would also expand monitor B's (and C's, ...), because there
// was only a single `activeStates` Map / `barState` for the whole process.
// This is the exact same bug already fixed on ChatBot.tsx and the plain
// (non-upstream) Bar.tsx -- it just came back with this resolver rewrite.
//
// Fix: each monitor's own priority resolver (activeStates map, barState,
// stackVisibleChild, resolveVisibleState) now lives inside the per-instance
// closure in the default export below, so hovering/pulsing one monitor's bar
// can never affect another's.
//
// Two things legitimately need to reach every open bar, and still do:
//   1. Other files calling the exported activateState()/deactivateState()
//      directly (e.g. a keybind opening "search").
//   2. The single module-level mpris player watcher below, which by design
//      watches each real player only once for all N bars.
// Both now go through `barInstanceListeners`: each mounted bar instance
// registers its own LOCAL activate/deactivate pair on mount and unregisters
// it on destroy, and the exported activateState()/deactivateState() simply
// broadcast to every registered instance -- same external signature and
// behaviour as before this patch.
//
// Things that already listen to one real, genuinely-global source
// independently per monitor -- recording, volume, brightness, the
// hover-triggered "expanded" state -- call their OWN instance's local
// resolver directly and never touch this broadcast layer, since each
// monitor already sets up its own watcher/controller for those.
// =============================================================================

export const [searchQuery, setSearchQuery] = createState<string>("");
export const [searchActivate, setSearchActivate] = createState<number>(0);
export const activeSearchMonitors = new Set<string>();

const PRIORITY: Record<BarStateName, number> = {
  compact: 0,
  recording: 40,
  expanded: 60,
  volume: 80,
  brightness: 80,
  network: 80,
  player: 80,
  search: 100,
};

type StateEntry = {
  priority: number;
  timer?: Timer;
};

type LocalStateController = {
  activate: (name: BarStateName, holdMs?: number) => void;
  deactivate: (name: BarStateName) => void;
};

const barInstanceListeners = new Set<LocalStateController>();
const barInstanceMap = new Map<string, LocalStateController>();

/**
 * External API -- unchanged signature/behaviour for any other file in the
 * codebase that calls this directly (e.g. a keybind opening search).
 * Broadcasts to every currently mounted bar instance; each instance decides
 * locally how that affects ITS OWN barState/stackVisibleChild.
 */
export function activateState(name: BarStateName, holdMs?: number) {
  for (const listener of barInstanceListeners) {
    listener.activate(name, holdMs);
  }
}

export function deactivateState(name: BarStateName) {
  for (const listener of barInstanceListeners) {
    listener.deactivate(name);
  }
}

/**
 * Activate state on a specific monitor only.
 */
export function activateStateOnMonitor(
  monitorName: string,
  state: BarStateName,
  holdMs?: number,
) {
  const controller = barInstanceMap.get(monitorName);
  if (controller) {
    controller.activate(state, holdMs);
  }
}

/**
 * Deactivate state on a specific monitor only.
 */
export function deactivateStateOnMonitor(
  monitorName: string,
  state: BarStateName,
) {
  const controller = barInstanceMap.get(monitorName);
  if (controller) {
    controller.deactivate(state);
  }
}
// ---------------------------------------------------------------------
// Player watcher — module scope, not per-monitor, since mpris players
// are global and shouldn't be watched N times for N bars.
//
// "player" is a pulse: whenever any mpris player's playback-status or
// title changes, that player becomes the `activePlayer` and "player"
// gets activated for a couple seconds, same as a volume/brightness
// nudge. It doesn't try to track "the" active player across pauses —
// whichever player changed most recently wins, which matches how a
// person actually thinks about it ("something just changed").
// ---------------------------------------------------------------------

export const [activePlayer, setActivePlayer] =
  createState<AstalMpris.Player | null>(null);

const PLAYER_HOLD_MS = 2500;
const watchedPlayers = new Set<AstalMpris.Player>();

function watchPlayerTransient(player: AstalMpris.Player) {
  let lastStatus = player.playbackStatus;
  let lastTitle = player.title;
  let debounceTimer: Timer | null = null;

  // notify::title / notify::artist / notify::playback-status tend to
  // fire in a burst for one logical track change — coalesce them into
  // a single pulse instead of resetting the hold timer 3-4 times.
  const pulse = () => {
    setActivePlayer(player);
    debounceTimer?.cancel();
    debounceTimer = timeout(50, () => {
      debounceTimer = null;
      activateState("player", PLAYER_HOLD_MS);
    });
  };

  player.connect("notify::playback-status", () => {
    if (player.playbackStatus === lastStatus) return;
    lastStatus = player.playbackStatus;
    pulse();
  });

  player.connect("notify::title", () => {
    if (player.title === lastTitle) return;
    lastTitle = player.title;
    pulse();
  });
}

function syncWatchedPlayers() {
  const current = new Set(playersBinding.get());

  for (const player of current) {
    if (!watchedPlayers.has(player)) {
      watchedPlayers.add(player);
      watchPlayerTransient(player);
    }
  }

  // A player disappearing (app closed) shouldn't leave a stale
  // activePlayer sitting around if it's the one currently shown.
  for (const player of watchedPlayers) {
    if (!current.has(player)) {
      watchedPlayers.delete(player);
      if (activePlayer.peek() === player) {
        setActivePlayer(null);
        deactivateState("player");
      }
    }
  }
}

const playersBinding = createBinding(mpris, "players");
playersBinding.subscribe(syncWatchedPlayers);
syncWatchedPlayers();

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;
  const [currentWidth, setCurrentWidth] = createState(0);

  // ---------------------------------------------------------------------
  // Priority resolver -- PER INSTANCE (see the isolation note near the top
  // of this file). Every "thing that might want to be shown" registers
  // itself as active (or inactive) via activateLocalState/deactivateLocalState
  // instead of calling setBarState directly. `barState` is a *derived*
  // value: whichever active entry has the highest priority wins. This is
  // what makes "volume flashes over recording, then reverts to recording"
  // and "a pulse replaces the expanded view" fall out for free, scoped to
  // THIS monitor only.
  // ---------------------------------------------------------------------
  const [barState, setBarState] = createState<BarStateName>("compact");
  const [stackVisibleChild, setStackVisibleChild] =
    createState<BarStateName>("compact");

  const activeStates = new Map<BarStateName, StateEntry>();
  // compact is the permanent base — always present, lowest priority.
  activeStates.set("compact", { priority: PRIORITY.compact });

  function resolveVisibleState(): BarStateName {
    let best: BarStateName = "compact";
    let bestPriority = -Infinity;
    for (const [name, entry] of activeStates) {
      if (entry.priority > bestPriority) {
        best = name;
        bestPriority = entry.priority;
      }
    }
    return best;
  }

  /**
   * Marks a state as active on THIS monitor's bar only. If `holdMs` is
   * given, the state auto-deactivates after that long — and retriggering
   * (calling this again while already active) resets the timer rather than
   * stacking a second one. Omit `holdMs` for states that stay active until
   * explicitly deactivated (search toggle, recording, expanded-on-hover).
   */
  function activateLocalState(name: BarStateName, holdMs?: number) {
    const priority = PRIORITY[name];
    const existing = activeStates.get(name);
    existing?.timer?.cancel();

    const entry: StateEntry = { priority };
    if (holdMs !== undefined) {
      entry.timer = timeout(holdMs, () => deactivateLocalState(name));
    }
    activeStates.set(name, entry);

    if (name === "search") {
      activeSearchMonitors.add(monitorName);
    }

    timeout(100, () => setBarState(resolveVisibleState()));
  }

  function deactivateLocalState(name: BarStateName) {
    if (name === "compact") return; // base is permanent, can't be removed
    activeStates.get(name)?.timer?.cancel();
    activeStates.delete(name);

    if (name === "search") {
      activeSearchMonitors.delete(monitorName);
    }

    timeout(100, () => setBarState(resolveVisibleState()));
  }

  // Register this instance so the exported (module-level) activateState()/
  // deactivateState() -- used by other files, e.g. a keybind opening search,
  // and by the shared mpris player watcher -- can reach THIS monitor's bar
  // too. Unregistered on window destroy, further down.
  const instanceStateController: LocalStateController = {
    activate: activateLocalState,
    deactivate: deactivateLocalState,
  };
  barInstanceListeners.add(instanceStateController);
  barInstanceMap.set(monitorName, instanceStateController);
  // ---------------------------------------------------------------------
  // Spring physics width animation — lives outside animateWidth so it
  // persists (and keeps momentum) across repeated calls.
  // ---------------------------------------------------------------------
  let widthVelocity = 0;
  let springTimer: Timer | null = null;

  function animateWidth(
    target: number,
    stiffness = 250, // higher = snappier
    damping = 15, // lower = more bounce
    mass = 1,
  ) {
    // Cancel any in-flight spring so we don't run two at once —
    // but we DON'T reset velocity, so momentum carries over
    if (springTimer !== null) {
      springTimer.cancel();
      springTimer = null;
    }

    const dt = 16 / 1000; // seconds, matches the 16ms tick below

    springTimer = interval(16, () => {
      const current = currentWidth();
      const displacement = current - target;

      const springForce = -stiffness * displacement;
      const dampingForce = -damping * widthVelocity;
      const acceleration = (springForce + dampingForce) / mass;

      widthVelocity += acceleration * dt;
      const next = current + widthVelocity * dt;

      setCurrentWidth(next);

      // Settle once close enough to target and nearly stopped
      if (Math.abs(next - target) < 0.5 && Math.abs(widthVelocity) < 0.5) {
        setCurrentWidth(target);
        widthVelocity = 0;
        springTimer?.cancel();
        springTimer = null;
      }
    });
  }

  // ---------------------------------------------------------------------
  // Widget / width registry — single source of truth for every stack
  // page instead of one `let widthX` variable per widget. Adding a new
  // bar state later is just one more registerBarWidget() call.
  // ---------------------------------------------------------------------
  const barWidgets = {} as Record<BarStateName, Gtk.Widget>;
  const barWidths = {} as Record<BarStateName, number>;

  // Auto-animate width on every bar-state change — single source of truth.
  // barState is now driven by the priority resolver above (per instance);
  // this block doesn't need to know or care why it changed.
  const unsubscribeBarStateWidth = barState.subscribe(() => {
    const name = barState.get();
    const target = barWidths[name];
    if (target === undefined) return;

    const current = currentWidth.peek();
    const growing = target > current;

    if (growing) {
      animateWidth(target);
      timeout(100, () => setStackVisibleChild(name));
    } else {
      setStackVisibleChild(name);
      timeout(100, () => animateWidth(target));
    }
  });

  /**
   * Registers a widget under a bar-state name and caches its measured
   * natural width (plus an explicit padding fudge-factor, replacing the
   * old unexplained `*= 1.5` / `*= 5` multipliers).
   */
  function registerBarWidget({
    name,
    widget,
    padding = 250,
  }: {
    name: BarStateName;
    widget: Gtk.Widget;
    padding?: number;
    width?: number;
  }) {
    barWidgets[name] = widget;
    const [, natural] = widget.measure(Gtk.Orientation.HORIZONTAL, -1);
    barWidths[name] = natural + padding;
    return widget;
  }

  function SearchBar({ widthRequest }: { widthRequest?: Accessor<number> }) {
    let entryRef: Gtk.TextView | null = null;
    let popoverRef: Gtk.Popover | null = null;
    let settingFromState = false; // guards buffer<->state feedback loop

    const closePopover = () => {
      popoverRef?.popdown();
    };

    return (
      <box class="search-bar">
        <scrolledwindow vscrollbarPolicy={Gtk.PolicyType.EXTERNAL}>
          <Gtk.TextView
            wrapMode={Gtk.WrapMode.WORD_CHAR}
            hexpand
            $={(self) => {
              entryRef = self;

              // state -> widget (e.g. prefillLauncherInput from main.tsx,
              // or launcher clearing the query on launch)
              searchQuery.subscribe(() => {
                const next = searchQuery.get();
                if (self.buffer.text === next) return;
                settingFromState = true;
                self.buffer.text = next;
                const iter = self.buffer.get_end_iter();
                self.buffer.place_cursor(iter);
                settingFromState = false;
              });

              // widget -> state
              self.buffer.connect("changed", () => {
                if (settingFromState) return;
                setSearchQuery(self.buffer.text);
              });

              barState.subscribe(() => {
                if (barState.get() === "search") {
                  const window = barWidgets.search?.get_root() as
                    | Gtk.Window
                    | undefined;
                  if (!window) return; // not registered yet — ignore the initial fire
                  window.keymode = Astal.Keymode.ON_DEMAND; // set BEFORE popup
                  timeout(50, () => {
                    popoverRef?.popup();
                    entryRef?.grab_focus();
                  });
                } else {
                  popoverRef?.popdown();
                }
              });
            }}
          >
            <Gtk.EventControllerKey
              onKeyPressed={(
                _,
                keyval: number,
                _keycode: number,
                state: number,
              ) => {
                if (keyval === Gdk.KEY_Escape) {
                  closePopover();
                  return true;
                }

                const isEnter =
                  keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter;
                if (!isEnter) return false;

                const isShiftPressed =
                  (state & Gdk.ModifierType.SHIFT_MASK) !== 0;
                if (isShiftPressed) return false; // Shift+Enter -> newline

                setSearchActivate(searchActivate.peek() + 1);
                return true; // swallow Enter so TextView doesn't insert \n
              }}
            />
          </Gtk.TextView>
        </scrolledwindow>

        <Gtk.Popover
          autohide={false}
          hasArrow={false}
          marginTop={50}
          $={(self) => {
            popoverRef = self;
            self.set_parent(entryRef!);
            self.set_offset(0, 15); // x, y — replaces marginTop (position offset)
            self.connect("closed", () => {
              if (barState.peek() !== "search") return; // only reset if search was active
              // Local, not the broadcast deactivateState(): closing THIS
              // monitor's popover (Escape, click-away, launch) must not
              // close search on every other monitor too.
              deactivateLocalState("search");
              setSearchQuery("");
            });
          }}
        >
          <AppLauncher monitor={monitor} onLaunched={closePopover} />
        </Gtk.Popover>
      </box>
    ) as Gtk.Widget;
  }

  /**
   * Wires a GObject signal to activateLocalState() as a transient pulse
   * scoped to THIS monitor's bar, with its own first-render guard and "last
   * seen value" dedupe — each call gets independent state, so multiple
   * watchers don't stomp on each other's firstRender/lastValue. Each
   * monitor sets up its own watcher on the same global signal (speaker
   * volume, screen brightness), so no cross-instance broadcast is needed:
   * every monitor independently notices the same real-world change and
   * pulses its own bar.
   */
  function watchTransient<T>(
    connectTo: { connect: (signal: string, cb: () => void) => void },
    signal: string,
    getValue: () => T,
    stateName: BarStateName,
    holdMs = 2000,
  ) {
    let isFirst = true;
    let last: T;

    connectTo.connect(signal, () => {
      const current = getValue();

      // Skip the initial notification on mount
      if (isFirst) {
        isFirst = false;
        last = current;
        return;
      }

      // Ignore spurious notifications where the value didn't actually change
      if (current === last) return;
      last = current;

      activateLocalState(stateName, holdMs);
    });
  }

  // Using a setup hook on the stack is the most reliable way to register named children in GTK4
  const barStack = (
    <stack
      transitionType={Gtk.StackTransitionType.CROSSFADE}
      transitionDuration={250}
      hhomogeneous={false} // Prevents the expanded width from stretching
      visibleChildName={stackVisibleChild}
      $={(self) => {
        self.add_named(
          registerBarWidget({
            name: "compact",
            widget: CompactBar(),
            padding: 400,
          }),
          "compact",
        );
        self.add_named(
          registerBarWidget({
            name: "expanded",
            widget: ExpandedBar(),
            padding: 500,
          }),
          "expanded",
        );
        self.add_named(
          registerBarWidget({
            name: "volume",
            widget: Volume({ widthRequest: currentWidth }),
          }),
          "volume",
        );

        self.add_named(
          registerBarWidget({
            name: "brightness",
            widget: BrightnessWidget({
              widthRequest: currentWidth,
            }),
          }),
          "brightness",
        );

        self.add_named(
          registerBarWidget({
            name: "recording",
            widget: Recording({ widthRequest: currentWidth }),
          }),
          "recording",
        );

        self.add_named(
          registerBarWidget({
            name: "player",
            widget: PlayerWidget({ widthRequest: currentWidth }),
            padding: 350,
          }),
          "player",
        );

        self.add_named(
          registerBarWidget({
            name: "search",
            widget: SearchBar({ widthRequest: currentWidth }),
            padding: 500,
          }),
          "search",
        );

        const networkWidget = NetworkWidget({
          widthRequest: currentWidth,
        });

        self.add_named(
          registerBarWidget({
            name: "network",
            widget: networkWidget,
            padding: 300,
          }),
          "network",
        );

        setCurrentWidth(barWidths.compact);

        const speaker = Wp.get_default()?.audio.defaultSpeaker!;
        watchTransient(
          speaker,
          "notify::volume",
          () => speaker.volume,
          "volume",
        );

        const brightness = Brightness.get_default();
        watchTransient(
          brightness,
          "notify::screen",
          () => brightness.screen,
          "brightness",
        );

        // Recording is continuous, not transient — it stays active for as
        // long as isRecording is true, and simply won't be the *visible*
        // state if something higher-priority (search, a volume pulse,
        // hover-expanded) is active in the meantime. Each monitor watches
        // the same global isRecording accessor independently and pulses
        // its OWN local resolver -- no broadcast needed.
        const unsubscribeIsRecording = isRecording.subscribe(() => {
          isRecording.peek()
            ? activateLocalState("recording")
            : deactivateLocalState("recording");
        });

        // Cleanup on window close: drop this instance from the broadcast
        // registry (so external activateState()/deactivateState() calls
        // and the shared mpris player watcher stop reaching a destroyed
        // bar) and unsubscribe the local watchers set up above.
        self.connect("destroy", () => {
          barInstanceListeners.delete(instanceStateController);
          barInstanceMap.delete(monitorName);
          unsubscribeBarStateWidth();
          unsubscribeIsRecording();
      }}
    />
  ) as Gtk.Widget;

  return (
    <window
      gdkmonitor={monitor}
      name={`bar-${monitorName}`}
      namespace="bar"
      class="Bar"
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT
      }
      visible={createComputed(() => {
        return !fullscreenClient() && globalSettings().bar.lock; // Hide when a client is fullscreen
      })}
      layer={Astal.Layer.TOP}
      $={(self) => {
        setup(self);
        (self as any).monitorName = monitorName;
      }}
    >
      <centerbox>
        <box $type="start" hexpand>
          <Gtk.EventControllerMotion
            onEnter={() => {
              if (globalSettings.peek().leftPanel.lock) return;
              const leftPanel = app.get_window(
                `left-panel-${monitorName}`,
              ) as Gtk.Window;
              print(`left-panel-${monitorName}`);
              leftPanel.show();
            }}
          />
        </box>
        <box
          class={"bar"}
          $type="center"
          widthRequest={currentWidth}
          $={(self) => {
            const windowInstance = new Window();
            (self as any).barWindow = windowInstance;
            let leaveTimer: Timer | null = null;
            const motion = new Gtk.EventControllerMotion();

            motion.connect("enter", () => {
              if (leaveTimer !== null) {
                leaveTimer.cancel();
                leaveTimer = null;
              }
              // No manual "am I allowed to expand right now" guard needed —
              // if search or a volume/brightness pulse is active, they
              // outrank "expanded" in the resolver and stay visible
              // regardless of this call. Local only: hovering THIS
              // monitor's bar must never expand another monitor's bar.
              activateLocalState("expanded");
            });

            motion.connect("leave", () => {
              if (leaveTimer !== null) {
                leaveTimer.cancel();
                leaveTimer = null;
              }

              leaveTimer = timeout(250, () => {
                leaveTimer = null;
                if (!windowInstance.popupIsOpen()) {
                  deactivateLocalState("expanded");
                }
              });
            });
            self.add_controller(motion);
          }}
          hexpand={false}
        >
          {barStack}
        </box>
        <box $type="end" hexpand>
          <Gtk.EventControllerMotion
            onEnter={() => {
              if (globalSettings.peek().rightPanel.lock) return;
              const rightPanel = app.get_window(
                `right-panel-${monitorName}`,
              ) as Gtk.Window;
              print(`right-panel-${monitorName}`);
              rightPanel.show();
            }}
          />
        </box>
      </centerbox>
    </window>
  );
};
