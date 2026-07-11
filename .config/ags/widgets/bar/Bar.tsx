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
  isBarExpanded,
  setIsBarExpanded,
} from "../../variables";
import { getMonitorName } from "../../utils/monitor";
import { WidgetSelector } from "../../interfaces/widgetSelector.interface";
import { Astal } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Gtk } from "ags/gtk4";
import { RightPanelVisibility } from "../rightPanel/RightPanel";
import { LeftPanelVisibility } from "../leftPanel/LeftPanel";
import app from "ags/gtk4/app";
import { interval, timeout, Timer } from "ags/time";
import { Window } from "../../utils/window";
import Volume from "./components/sub-components/Volume";
import Battery from "./components/sub-components/Battery";

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

  // Spring state — lives outside animateWidth so it persists across calls
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

  const expandedBar = (
    <box spacing={25}>
      {layout
        .filter((widget) => widget.enabled)
        .map((widget: WidgetSelector, key) => {
          switch (widget.name) {
            case "workspaces":
              return <Workspaces />;
            case "information":
              return <Information />;
            case "utilities":
              return <Utilities />;
            default:
              return <box />;
          }
        })}
    </box>
  ) as Gtk.Widget;

  const compactBar = (
    <box spacing={5}>
      <WorkspacesCompact />
      <Information />
      <Battery />
      <Volume />
    </box>
  ) as Gtk.Widget;

  let compactWidth = 0;
  let expandedWidth = 0;

  timeout(250, () => {
    [, compactWidth] = compactBar.measure(Gtk.Orientation.HORIZONTAL, -1);
    compactWidth *= 1.5; // Add a small buffer to prevent clipping

    [, expandedWidth] = expandedBar.measure(Gtk.Orientation.HORIZONTAL, -1);
    expandedWidth *= 1.5; // Add a small buffer to prevent clipping

    setCurrentWidth(compactWidth);

    print(`Compact width: ${compactWidth}, Expanded width: ${expandedWidth}`);
  });

  // Using a setup hook on the stack is the most reliable way to register named children in GTK4
  const barStack = (
    <stack
      transitionType={Gtk.StackTransitionType.CROSSFADE}
      transitionDuration={250}
      hhomogeneous={false} // Prevents the expanded width from stretching
      visibleChildName={isBarExpanded((expanded) =>
        expanded ? "expanded" : "compact",
      )}
      $={(self) => {
        self.add_named(compactBar, "compact");
        self.add_named(expandedBar, "expanded");
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
              animateWidth(expandedWidth);

              timeout(100, () => {
                setIsBarExpanded(true);
              });
            });
            motion.connect("leave", () => {
              if (compactTimeout !== null) {
                compactTimeout.cancel();
                compactTimeout = null;
              }

              compactTimeout = timeout(100, () => {
                compactTimeout = null;
                if (!windowInstance.popupIsOpen()) {
                  setIsBarExpanded(false);

                  timeout(100, () => {
                    animateWidth(compactWidth);
                  });
                }
              });
            });
            self.add_controller(motion);
          }}
          hexpand={false}
        >
          {/* {barStack} */}
          <box halign={Gtk.Align.CENTER} hexpand>
            {barStack}
          </box>
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
