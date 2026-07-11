import App from "ags/gtk4/app";
import { createComputed, createState, With } from "ags";
import Workspaces, { WorkspacesCompact } from "./components/Workspaces";
import Information from "./components/Information";
import Utilities from "./components/Utilities";
import {
  emptyWorkspace,
  focusedClient,
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

export type BarStateName =
  | "compact"
  | "expanded"
  | "recording"
  | "volume"
  | "brightness";

export const [barState, setBarState] = createState<BarStateName>("compact");

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;
  const [currentWidth, setCurrentWidth] = createState(0);

  const layout = globalSettings.peek().bar.layout;

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

  /**
   * Registers a widget under a bar-state name and caches its measured
   * natural width (plus an explicit padding fudge-factor, replacing the
   * old unexplained `*= 1.5` / `*= 5` multipliers).
   */
  function registerBarWidget(
    name: BarStateName,
    widget: Gtk.Widget,
    padding: number = 250,
  ) {
    barWidgets[name] = widget;
    const [, natural] = widget.measure(Gtk.Orientation.HORIZONTAL, -1);
    barWidths[name] = natural + padding;
    return widget;
  }

  const expandedBar = (
    <centerbox hexpand>
      {layout
        .filter((widget) => widget.enabled)
        .map((widget: WidgetSelector, key) => {
          switch (widget.name) {
            case "workspaces":
              return (
                <box $type="start">
                  <Workspaces />
                </box>
              );
            case "information":
              return (
                <box $type="center">
                  <Information />
                </box>
              );
            case "utilities":
              return (
                <box $type="end">
                  <Utilities />
                </box>
              );
            default:
              return <box />;
          }
        })}
    </centerbox>
  ) as Gtk.Widget;

  const compactBar = (
    <box spacing={5} halign={Gtk.Align.CENTER} hexpand>
      <WorkspacesCompact />
      <Information />
      <Battery />
      <Volume />
    </box>
  ) as Gtk.Widget;

  // ---------------------------------------------------------------------
  // Transient-state helper — shows a bar page (volume/brightness/etc),
  // then decays back to compact after `holdMs` of no further changes.
  // Replaces the two near-identical animate -> setBarState -> setTimeout
  // blocks that used to live inline per-signal.
  // ---------------------------------------------------------------------
  let transientHideTimeout: ReturnType<typeof setTimeout> | null = null;

  function showTransientState(name: BarStateName, holdMs = 2000) {
    animateWidth(barWidths[name]);
    timeout(100, () => setBarState(name));

    if (transientHideTimeout) {
      clearTimeout(transientHideTimeout);
    }

    transientHideTimeout = setTimeout(() => {
      animateWidth(barWidths.compact);
      timeout(100, () => setBarState("compact"));
    }, holdMs);
  }

  isRecording.subscribe(() => {
    const recording = isRecording.peek();

    if (recording) {
      if (transientHideTimeout) {
        clearTimeout(transientHideTimeout);
        transientHideTimeout = null;
      }
      animateWidth(barWidths.recording);
      timeout(100, () => setBarState("recording"));
    } else if (barState.peek() === "recording") {
      animateWidth(barWidths.compact);
      timeout(100, () => setBarState("compact"));
    }
  });
  /**
   * Wires a GObject signal to showTransientState(), with its own
   * first-render guard and "last seen value" dedupe — each call gets
   * independent state, so multiple watchers no longer stomp on each
   * other's `firstRender`/`lastValue` the way the old inline copies did.
   */
  function watchTransient<T>(
    connectTo: { connect: (signal: string, cb: () => void) => void },
    signal: string,
    getValue: () => T,
    stateName: BarStateName,
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

      showTransientState(stateName);
    });
  }

  // Using a setup hook on the stack is the most reliable way to register named children in GTK4
  const barStack = (
    <stack
      transitionType={Gtk.StackTransitionType.CROSSFADE}
      transitionDuration={250}
      hhomogeneous={false} // Prevents the expanded width from stretching
      visibleChildName={barState}
      $={(self) => {
        self.add_named(registerBarWidget("compact", compactBar), "compact");
        self.add_named(
          registerBarWidget("expanded", expandedBar, 500),
          "expanded",
        );

        const volumeWidget = Volume({ widthRequest: currentWidth });
        self.add_named(registerBarWidget("volume", volumeWidget), "volume");

        const brightnessWidget = BrightnessWidget({
          widthRequest: currentWidth,
        });
        self.add_named(
          registerBarWidget("brightness", brightnessWidget),
          "brightness",
        );

        const recordingWidget = Recording({ widthRequest: currentWidth });
        self.add_named(
          registerBarWidget("recording", recordingWidget),
          "recording",
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
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.RIGHT
      }
      marginTop={globalSettings(({ bar }) => {
        return bar.orientation.value ? globalMargin : 0;
      })}
      marginBottom={globalSettings(({ bar }) => {
        return !bar.orientation.value ? globalMargin : 0;
      })}
      marginRight={globalMargin}
      marginLeft={globalMargin}
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
            let hideTimeout: Timer | null = null;
            let compactTimeout: Timer | null = null;
            const motion = new Gtk.EventControllerMotion();

            motion.connect("enter", () => {
              if (barState.peek() != "compact") return;
              if (hideTimeout !== null) {
                {
                  barStack;
                }
                hideTimeout.cancel();
                hideTimeout = null;
              }

              if (compactTimeout !== null) {
                compactTimeout.cancel();
                compactTimeout = null;
              }
              animateWidth(barWidths.expanded);

              timeout(100, () => {
                setBarState("expanded");
              });
            });
            motion.connect("leave", () => {
              if (barState.peek() != "expanded") return;
              if (compactTimeout !== null) {
                compactTimeout.cancel();
                compactTimeout = null;
              }

              compactTimeout = timeout(100, () => {
                compactTimeout = null;
                if (!windowInstance.popupIsOpen()) {
                  setBarState("compact");

                  timeout(100, () => {
                    animateWidth(barWidths.compact);
                  });
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
