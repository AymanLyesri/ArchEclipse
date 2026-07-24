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
import SearchBar from "./sub-components/SearchBar";

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

export const [barState, setBarState] = createState<BarStateName>("compact");
export const [stackVisibleChild, setStackVisibleChild] =
  createState<BarStateName>("compact");

// Which monitor's bar requested "search" (and its friends: clipboard,
// emojis, notes, apps). barState/searchQuery/searchActivate below are
// module-level singletons shared by every monitor's Bar instance, so
// without this, activating search pops it open on every monitor and
// each mounted AppLauncher independently launches the selected result
// (one launch per monitor). Falsy means "unscoped" (show everywhere) —
// keeps old behavior if a caller doesn't pass a monitor.
export const [activeSearchMonitor, setActiveSearchMonitor] = createState<
  string | null
>(null);

// ---------------------------------------------------------------------
// Visibility resolver — priority-based instead of scattered if/else.
//
// Every "thing that might want to be shown" registers itself as active
// (or inactive) via activateState/deactivateState instead of calling
// setBarState directly. `barState` is now a *derived* value: whichever
// active entry has the highest priority wins. This is what makes
// "volume flashes over recording, then reverts to recording" and
// "a pulse replaces the expanded view" fall out for free instead of
// needing manual "what was I before" bookkeeping.
//
// NOTE: any other file in the codebase that currently calls
// setBarState(...) directly (e.g. a keybind opening search) should be
// migrated to activateState(...) / deactivateState(...) — calling
// setBarState directly bypasses the resolver and will get stomped on
// by the next state change.
// ---------------------------------------------------------------------

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
 * Marks a state as active. If `holdMs` is given, the state auto-deactivates
 * after that long — and retriggering (calling activateState again while
 * already active) resets the timer rather than stacking a second one.
 * Omit `holdMs` for states that stay active until explicitly deactivated
 * (search toggle, recording, expanded-on-hover).
 */
export function activateState(name: BarStateName, holdMs?: number) {
  const priority = PRIORITY[name];
  const existing = activeStates.get(name);
  existing?.timer?.cancel();

  const entry: StateEntry = { priority };
  if (holdMs !== undefined) {
    entry.timer = timeout(holdMs, () => deactivateState(name));
  }
  activeStates.set(name, entry);

  timeout(100, () => setBarState(resolveVisibleState()));
}

export function deactivateState(name: BarStateName) {
  if (name === "compact") return; // base is permanent, can't be removed
  activeStates.get(name)?.timer?.cancel();
  activeStates.delete(name);

  timeout(100, () => setBarState(resolveVisibleState()));
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

  // player.connect("notify::playback-status", () => {
  //   if (player.playbackStatus === lastStatus) return;
  //   lastStatus = player.playbackStatus;
  //   pulse();
  // });

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

  // "search" is a global priority state shared by every monitor's Bar
  // instance (see activeSearchMonitor above it) — resolve it to "compact"
  // for any monitor that isn't the one search was requested on, so only
  // the target monitor's bar actually expands/shows the search page.
  // `target` is passed in rather than read here so reactive callers can
  // track activeSearchMonitor themselves (peek() wouldn't register as a
  // dependency inside a createComputed producer).
  function resolveMonitorState(
    name: BarStateName,
    target: string | null,
  ): BarStateName {
    return name === "search" && target && target !== monitorName
      ? "compact"
      : name;
  }

  // ---------------------------------------------------------------------
  // Spring physics width animation — lives outside animateWidth so it
  // persists (and keeps momentum) across repeated calls.
  // ---------------------------------------------------------------------
  let widthVelocity = 0;
  let springTimer: Timer | null = null;

  function animateWidth(
    target: number,
    stiffness = 250, // higher = snappier
    damping = 32, // critically damped for stiffness=250/mass=1 — no bounce/jitter
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
  // barState is now driven by the priority resolver above; this block
  // doesn't need to know or care why it changed.
  barState.subscribe(() => {
    // rawName drives the shared stackVisibleChild setter — every monitor's
    // subscriber must write the *same* value here, or whichever instance's
    // resolved (per-monitor) name is written last silently overwrites the
    // others'. Only the width/growing decision below is monitor-scoped.
    const rawName = barState.get();
    const name = resolveMonitorState(rawName, activeSearchMonitor.peek());
    const target = barWidths[name];
    if (target === undefined) return;

    const current = currentWidth.peek();
    const growing = target > current;

    if (growing) {
      animateWidth(target);
      timeout(100, () => setStackVisibleChild(rawName));
    } else {
      setStackVisibleChild(rawName);
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

  /**
   * Wires a GObject signal to activateState() as a transient pulse, with
   * its own first-render guard and "last seen value" dedupe — each call
   * gets independent state, so multiple watchers don't stomp on each
   * other's firstRender/lastValue.
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

      activateState(stateName, holdMs);
    });
  }

  // Using a setup hook on the stack is the most reliable way to register named children in GTK4
  const barStack = (
    <stack
      transitionType={Gtk.StackTransitionType.CROSSFADE}
      transitionDuration={250}
      hhomogeneous={false} // Prevents the expanded width from stretching
      visibleChildName={createComputed(() =>
        resolveMonitorState(stackVisibleChild(), activeSearchMonitor()),
      )}
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
            widget: SearchBar({ widthRequest: currentWidth, monitor: monitorName }),
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

        isRecording.subscribe(() => {
          isRecording.peek()
            ? activateState("recording")
            : deactivateState("recording");
        });
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
      keymode={Astal.Keymode.NONE}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT
      }
      visible={createComputed(() => {
        return !fullscreenClient();
      })}
      layer={Astal.Layer.TOP}
      $={(self) => {
        setup(self);
        (self as any).monitorName = monitorName;
      }}
    >
      <centerbox>
        <box $type="start" hexpand>
          {/* <Gtk.EventControllerMotion
            onEnter={() => {
              if (globalSettings.peek().leftPanel.lock) return;
              const leftPanel = app.get_window(
                `left-panel-${monitorName}`,
              ) as Gtk.Window;
              print(`left-panel-${monitorName}`);
              leftPanel.show();
            }}
          /> */}
        </box>
        <box
          class={createComputed(
            () => `bar ${resolveMonitorState(barState(), activeSearchMonitor())}`,
          )}
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
              // regardless of this call.
              activateState("expanded");
            });

            motion.connect("leave", () => {
              if (leaveTimer !== null) {
                leaveTimer.cancel();
                leaveTimer = null;
              }

              leaveTimer = timeout(250, () => {
                leaveTimer = null;
                if (!windowInstance.popupIsOpen()) {
                  deactivateState("expanded");
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
          {/* <Gtk.EventControllerMotion
            onEnter={() => {
              if (globalSettings.peek().rightPanel.lock) return;
              const rightPanel = app.get_window(
                `right-panel-${monitorName}`,
              ) as Gtk.Window;
              print(`right-panel-${monitorName}`);
              rightPanel.show();
            }}
          /> */}
        </box>
      </centerbox>
    </window>
  );
};
