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
  hotZonePreview,
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
import AstalMpris from "gi://AstalMpris";
import Hyprland from "gi://AstalHyprland";
import PlayerWidget, {
  isPlayablePlayer,
} from "./components/sub-components/PlayerWidget";
import NetworkWidget from "./barStates/NetworkWidget";
import CompactBar from "./barStates/CompactBar";
import ExpandedBar from "./barStates/ExpandedBar";
import SearchBar from "./barStates/SearchBar";

const mpris = AstalMpris.get_default();
const hyprland = Hyprland.get_default();

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
  // Always-expanded mode pins the expanded state against every collapse
  // path (hover leave, popover close). Turning the setting off passes
  // here because the watcher below runs after the value changed.
  if (
    name === "expanded" &&
    (globalSettings.peek().bar.expanded.value as boolean)
  ) {
    return;
  }
  activeStates.get(name)?.timer?.cancel();
  activeStates.delete(name);

  timeout(100, () => setBarState(resolveVisibleState()));
}

// ---------------------------------------------------------------------
// Bar visibility — per-monitor override on top of settings-driven
// auto-visibility. Key absent = auto (bar.lock decides), true/false =
// explicit override from the hover strip or a toggle request. The
// override lives here rather than in window.show()/hide() calls because
// the bar window's `visible` is a binding — an external show/hide would
// be stomped by its next re-evaluation.
// ---------------------------------------------------------------------

export const [barShown, setBarShown] = createState<Record<string, boolean>>({});

export function revealBar(monitorName: string) {
  setBarShown({ ...barShown.peek(), [monitorName]: true });
}

export function concealBar(monitorName: string) {
  const next = { ...barShown.peek() };
  delete next[monitorName];
  setBarShown(next);
}

export function toggleBarShown(monitorName: string) {
  const current = barShown.peek()[monitorName] ?? barAutoVisible(monitorName);
  setBarShown({ ...barShown.peek(), [monitorName]: !current });
}

// Client moves/resizes don't re-emit the clients list - tick (debounced)
// on the raw IPC event stream so the room check re-evaluates.
const [hyprlandTick, setHyprlandTick] = createState(0);
let hyprlandTickTimer: Timer | null = null;
hyprland.connect("event", () => {
  if (hyprlandTickTimer) return;
  hyprlandTickTimer = timeout(100, () => {
    hyprlandTickTimer = null;
    setHyprlandTick(hyprlandTick.peek() + 1);
  });
});

function barBlocked(monitorName: string, barHeight: number): boolean {
  const monitor = hyprland.get_monitors().find((m) => m.name === monitorName);
  const workspace = monitor?.activeWorkspace;
  if (!monitor || !workspace) return false;

  const onTop = globalSettings.peek().bar.orientation.value as boolean;
  const bandStart = onTop ? monitor.y : monitor.y + monitor.height - barHeight;
  const bandEnd = bandStart + barHeight;

  // Query geometry straight from Hyprland - the cached client objects
  // lag behind floating window moves and resizes.
  let clients: any[] = [];
  try {
    clients = JSON.parse(hyprland.message("j/clients"));
  } catch {
    return false;
  }

  return clients.some((client) => {
    if (!client.mapped || client.workspace?.id !== workspace.id) return false;
    const top = client.at?.[1] ?? 0;
    const bottom = top + (client.size?.[1] ?? 0);
    return bottom > bandStart && top < bandEnd;
  });
}

// An unlocked bar overlays instead of reserving space, so window geometry
// is independent of bar visibility and a geometric room check is stable.
export function barAutoVisible(monitorName: string, barHeight = 40): boolean {
  const { lock, smartHide } = globalSettings.peek().bar;
  if (lock.value as boolean) return true;
  if (!(smartHide.value as boolean)) return false;
  return !barBlocked(monitorName, barHeight);
}

let lastBarLock = globalSettings.peek().bar.lock.value as boolean;
let lastBarExpanded = globalSettings.peek().bar.expanded.value as boolean;
if (lastBarExpanded) activateState("expanded");

globalSettings.subscribe(() => {
  const lock = globalSettings.peek().bar.lock.value as boolean;
  if (lock !== lastBarLock) {
    lastBarLock = lock;
    // Re-locking pins every bar visible again; stale overrides would keep
    // a bar hidden with no hover strip left to reveal it.
    if (lock) setBarShown({});
  }

  const expanded = globalSettings.peek().bar.expanded.value as boolean;
  if (expanded !== lastBarExpanded) {
    lastBarExpanded = expanded;
    if (expanded) activateState("expanded");
    else deactivateState("expanded");
  }
});

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
    // A tab closing clears the title - don't pulse the bar for a
    // player that no longer has anything to show.
    if (!isPlayablePlayer(player)) return;
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

  const barOnTop = globalSettings((s) => s.bar.orientation.value as boolean);

  // ---------------------------------------------------------------------
  // Spring physics width animation — lives outside animateWidth so it
  // persists (and keeps momentum) across repeated calls.
  // ---------------------------------------------------------------------
  let widthVelocity = 0;
  let springTimer: Timer | null = null;

  function animateWidth(
    target: number,
    stiffness = 250, // higher = snappier
    damping = 20, // lower = more bounce
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
  const barPaddings = {} as Record<BarStateName, number>;

  // Compact and expanded hold live content (workspaces, clock, tray) whose
  // natural width changes at runtime — measure those at transition time.
  // Every other page binds its own widthRequest to currentWidth, so a live
  // measure would feed the current width back into itself; they keep the
  // width cached at registration.
  const DYNAMIC_STATES: BarStateName[] = ["compact", "expanded"];

  function widthFor(state: BarStateName): number | undefined {
    const widget = barWidgets[state];
    if (!DYNAMIC_STATES.includes(state) || !widget) return barWidths[state];
    const [, natural] = widget.measure(Gtk.Orientation.HORIZONTAL, -1);
    return natural + (barPaddings[state] ?? 0);
  }

  // Workspaces appearing/disappearing and client class changes alter the
  // compact/expanded content width while the bar is resting — follow them.
  // Debounced so GTK gets an idle cycle to relayout before the measure.
  let widthRefreshTimer: Timer | null = null;
  function queueWidthRefresh() {
    widthRefreshTimer?.cancel();
    widthRefreshTimer = timeout(150, () => {
      widthRefreshTimer = null;
      const state = barState.peek();
      if (!DYNAMIC_STATES.includes(state)) return;
      const target = widthFor(state);
      if (target === undefined) return;
      if (Math.abs(target - currentWidth.peek()) > 1) animateWidth(target);
    });
  }

  // Auto-animate width on every bar-state change — single source of truth.
  // barState is now driven by the priority resolver above; this block
  // doesn't need to know or care why it changed.
  barState.subscribe(() => {
    const state = barState.peek();

    // Re-parent the shared Information widget before measuring, so the
    // target state is measured with its actual content in place.
    if (state === "compact") moveInformationTo(compactInfoSlot);
    else if (state === "expanded") moveInformationTo(expandedInfoSlot);

    const target = widthFor(state);
    if (target === undefined) return;

    const current = currentWidth.peek();
    const growing = target > current;

    if (growing) {
      animateWidth(target);
      timeout(100, () => setStackVisibleChild(state));
    } else {
      setStackVisibleChild(state);
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
    barPaddings[name] = padding;
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

  const workspaces = (<Workspaces />) as Gtk.Widget;
  const information = (<Information />) as Gtk.Widget;
  const utilities = (<Utilities />) as Gtk.Widget;
  const workspacesCompact = (<WorkspacesCompact />) as Gtk.Widget;
  const battery = (<Battery />) as Gtk.Widget;
  const volume = (<Volume />) as Gtk.Widget;

  // Single shared Information instance — reparented between slots rather
  // than duplicated. GTK widgets can only have one parent, and Information
  // carries its own bindings/state we don't want two independent copies of.

  const compactInfoSlot = new Gtk.Box();
  const expandedInfoSlot = new Gtk.Box();

  function moveInformationTo(slot: Gtk.Box) {
    const parent = information.get_parent();
    if (parent === slot) return;
    if (parent) (parent as Gtk.Box).remove(information);
    slot.append(information);
  }

  moveInformationTo(compactInfoSlot); // initial state

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
            widget: CompactBar({
              components: [workspacesCompact, compactInfoSlot, battery, volume],
            }),
            padding: 40,
          }),
          "compact",
        );
        self.add_named(
          registerBarWidget({
            name: "expanded",
            widget: ExpandedBar({
              start: workspaces,
              center: expandedInfoSlot,
              end: utilities,
            }),
            padding: 60,
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

        setCurrentWidth(widthFor("compact") ?? barWidths.compact);

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

  function currentBarHeight(): number {
    const [, natural] = barStack.measure(Gtk.Orientation.VERTICAL, -1);
    return Math.max(natural, 30);
  }

  let leftHoverTimer: Timer | null = null;
  let rightHoverTimer: Timer | null = null;

  return (
    <window
      gdkmonitor={monitor}
      name={`bar-${monitorName}`}
      namespace="bar"
      class="Bar"
      exclusivity={globalSettings(({ bar }) =>
        (bar.lock.value as boolean)
          ? Astal.Exclusivity.EXCLUSIVE
          : Astal.Exclusivity.IGNORE,
      )}
      keymode={Astal.Keymode.NONE}
      anchor={createComputed(() =>
        barOnTop()
          ? Astal.WindowAnchor.TOP |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT
          : Astal.WindowAnchor.BOTTOM |
            Astal.WindowAnchor.LEFT |
            Astal.WindowAnchor.RIGHT,
      )}
      visible={createComputed(() => {
        if (fullscreenClient()) return false;
        // The search popover lives inside this window - an auto-hidden
        // bar would open the launcher on an invisible surface.
        if (barState() === "search") return true;
        const override = barShown()[monitorName];
        if (override !== undefined) return override;

        // Register the reactive dependencies barAutoVisible peeks at.
        globalSettings();
        hyprlandTick();
        return barAutoVisible(monitorName, currentBarHeight());
      })}
      layer={Astal.Layer.TOP}
      $={(self) => {
        setup(self);
        (self as any).monitorName = monitorName;

        const unsubWorkspaces = createBinding(hyprland, "workspaces").subscribe(
          queueWidthRefresh,
        );
        const unsubClients = createBinding(hyprland, "clients").subscribe(
          queueWidthRefresh,
        );
        self.connect("destroy", () => {
          unsubWorkspaces();
          unsubClients();
          widthRefreshTimer?.cancel();
        });
      }}
    >
      <centerbox>
        <box
          $type="start"
          valign={globalSettings((s) =>
            (s.bar.orientation.value as boolean)
              ? Gtk.Align.START
              : Gtk.Align.END,
          )}
          halign={Gtk.Align.START}
          widthRequest={globalSettings(
            (s) => s.leftPanel.hotZoneSize.value as number,
          )}
          heightRequest={globalSettings(
            (s) => s.leftPanel.hotZoneSize.value as number,
          )}
          css={hotZonePreview((preview) =>
            preview ? "background-color: rgba(255, 85, 85, 0.4);" : "",
          )}
        >
          <Gtk.EventControllerMotion
            onEnter={() => {
              if (!(globalSettings.peek().leftPanel.hotZone.value as boolean))
                return;
              if (!globalSettings.peek().leftPanel.lock) return;

              leftHoverTimer?.cancel();
              leftHoverTimer = timeout(500, () => {
                leftHoverTimer = null;
                const leftPanel = app.get_window(
                  `left-panel-${monitorName}`,
                ) as Gtk.Window;
                if (leftPanel) leftPanel.show();
              });
            }}
            onLeave={() => {
              leftHoverTimer?.cancel();
              leftHoverTimer = null;
            }}
          />
        </box>
        <box
          class={createComputed(() => {
            const state = barState();
            const onTop = barOnTop();
            return `bar ${state} ${onTop ? "top" : "bottom"}`;
          })}
          $type="center"
          widthRequest={createComputed(() =>
            (globalSettings().bar.fullWidth.value as boolean)
              ? -1
              : currentWidth(),
          )}
          $={(self) => {
            const windowInstance = new Window();
            (self as any).barWindow = windowInstance;
            let leaveTimer: Timer | null = null;
            const motion = new Gtk.EventControllerMotion();
            const tryCollapseExpanded = () => {
              if (
                !windowInstance.isHovered() &&
                !windowInstance.popupIsOpen()
              ) {
                deactivateState("expanded");
              }
            };

            motion.connect("enter", () => {
              if (leaveTimer !== null) {
                leaveTimer.cancel();
                leaveTimer = null;
              }
              windowInstance.setIsHovered(true);
              // No manual "am I allowed to expand right now" guard needed —
              // if search or a volume/brightness pulse is active, they
              // outrank "expanded" in the resolver and stay visible
              // regardless of this call.
              activateState("expanded");
            });

            motion.connect("leave", () => {
              windowInstance.setIsHovered(false);
              if (leaveTimer !== null) {
                leaveTimer.cancel();
                leaveTimer = null;
              }

              leaveTimer = timeout(250, () => {
                leaveTimer = null;
                tryCollapseExpanded();
                if (
                  barState.peek() !== "search" &&
                  !(globalSettings.peek().bar.lock.value as boolean) &&
                  !windowInstance.isHovered() &&
                  !windowInstance.popupIsOpen()
                ) {
                  concealBar(monitorName);
                }
              });
            });
            self.add_controller(motion);

            // Watchdog: a reveal that never gets a pill enter/leave cycle
            // (edge reveal, keybind, pointer crossing too fast for GTK to
            // fire enter/leave) would keep its override forever. GTK hover
            // state is unreliable for the same reason, so ask Hyprland
            // where the cursor actually is.
            const pointerOnBar = (): boolean => {
              try {
                const [xRaw, yRaw] = hyprland.message("cursorpos").split(",");
                const x = parseInt(xRaw, 10);
                const y = parseInt(yRaw, 10);
                const gdkMonitor = hyprland
                  .get_monitors()
                  .find((m) => m.name === monitorName);
                if (!gdkMonitor || Number.isNaN(x) || Number.isNaN(y))
                  return true;

                const height = currentBarHeight();
                if (x < gdkMonitor.x || x > gdkMonitor.x + gdkMonitor.width)
                  return false;
                return (globalSettings.peek().bar.orientation.value as boolean)
                  ? y <= gdkMonitor.y + height
                  : y >= gdkMonitor.y + gdkMonitor.height - height;
              } catch {
                return true; // can't tell - don't conceal blindly
              }
            };

            let idleTimer: Timer | null = null;
            const scheduleIdleCheck = () => {
              idleTimer?.cancel();
              idleTimer = timeout(1500, () => {
                idleTimer = null;
                if (globalSettings.peek().bar.lock.value as boolean) return;
                if (barShown.peek()[monitorName] !== true) return;
                if (
                  barState.peek() === "search" ||
                  windowInstance.popupIsOpen() ||
                  pointerOnBar()
                ) {
                  scheduleIdleCheck();
                  return;
                }
                windowInstance.setIsHovered(false);
                concealBar(monitorName);
              });
            };
            barShown.subscribe(() => {
              if (barShown.peek()[monitorName] === true) {
                scheduleIdleCheck();
              } else {
                idleTimer?.cancel();
                idleTimer = null;
              }
            });
          }}
          hexpand={globalSettings(({ bar }) => bar.fullWidth.value as boolean)}
        >
          {barStack}
        </box>
        <box
          $type="end"
          valign={globalSettings((s) =>
            (s.bar.orientation.value as boolean)
              ? Gtk.Align.START
              : Gtk.Align.END,
          )}
          halign={Gtk.Align.END}
          widthRequest={globalSettings(
            (s) => s.rightPanel.hotZoneSize.value as number,
          )}
          heightRequest={globalSettings(
            (s) => s.rightPanel.hotZoneSize.value as number,
          )}
          css={hotZonePreview((preview) =>
            preview ? "background-color: rgba(255, 85, 85, 0.4);" : "",
          )}
        >
          <Gtk.EventControllerMotion
            onEnter={() => {
              if (!(globalSettings.peek().rightPanel.hotZone.value as boolean))
                return;
              if (!globalSettings.peek().rightPanel.lock) return;

              rightHoverTimer?.cancel();
              rightHoverTimer = timeout(500, () => {
                rightHoverTimer = null;
                const rightPanel = app.get_window(
                  `right-panel-${monitorName}`,
                ) as Gtk.Window;
                if (rightPanel) rightPanel.show();
              });
            }}
            onLeave={() => {
              rightHoverTimer?.cancel();
              rightHoverTimer = null;
            }}
          />
        </box>
      </centerbox>
    </window>
  );
};
