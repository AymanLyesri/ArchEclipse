import App from "ags/gtk3/app";
import Gtk from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import {
  globalMargin,
  globalTransition,
  rightPanelExclusivity,
  setRightPanelExclusivity,
  rightPanelLock,
  setRightPanelLock,
  rightPanelVisibility,
  setRightPanelVisibility,
  rightPanelWidgets,
  setRightPanelWidgets,
  rightPanelWidth,
  setRightPanelWidth,
  widgetLimit,
} from "../../variables";
import { createBinding, createComputed } from "ags";
import { getMonitorName } from "../../utils/monitor";
import { hideWindow, WindowActions } from "../../utils/window";
import { rightPanelWidgetSelectors } from "../../constants/widget.constants";

const WidgetActions = () => {
  return (
    <box vertical={true} vexpand={true} class={"widget-actions"} spacing={5}>
      {rightPanelWidgetSelectors.map((selector) => {
        const isActive = createComputed(() =>
          rightPanelWidgets().some((w) => w.name === selector.name)
        );
        return (
          <togglebutton
            class={"widget-selector"}
            label={selector.icon}
            active={isActive}
            onToggled={(self: any, on: boolean) => {
              if (on) {
                if (rightPanelWidgets().length >= widgetLimit) return;
                setRightPanelWidgets([...rightPanelWidgets(), selector]);
              } else {
                const newWidgets = rightPanelWidgets().filter(
                  (w) => w.name !== selector.name
                );
                setRightPanelWidgets(newWidgets);
              }
            }}
          />
        );
      })}
    </box>
  );
};

const Actions = () => (
  <box class={"panel-actions"} vertical={true}>
    <WidgetActions />
    <WindowActions
      windowWidth={rightPanelWidth}
      setWindowWidth={setRightPanelWidth}
      windowExclusivity={rightPanelExclusivity}
      setWindowExclusivity={setRightPanelExclusivity}
      windowLock={rightPanelLock}
      setWindowLock={setRightPanelLock}
      windowVisibility={rightPanelVisibility}
      setWindowVisibility={setRightPanelVisibility}
    />
  </box>
);

function Panel() {
  return (
    <box>
      <eventbox
        onHoverLost={() => {
          if (!rightPanelLock()) setRightPanelVisibility(false);
        }}
        child={<box css={"min-width:5px"} />}
      ></eventbox>
      <box
        class={"main-content"}
        vertical={true}
        spacing={10}
        widthRequest={rightPanelWidth}
      >
        {createComputed(() => {
          return rightPanelWidgets()
            .map((widget) =>
              rightPanelWidgetSelectors.find((w) => w.name === widget.name)
            ) // Find and call the widget function
            .filter((widget) => widget && widget.widget) // Filter out invalid widgets
            .map((widget) => {
              try {
                return widget!.widget();
              } catch (error) {
                console.error(`Error rendering widget:`, error);
                return <box />; // Fallback component
              }
            });
        })}
      </box>
      <Actions />
    </box>
  );
}
export default (monitor: Gdk.Monitor) => {
  return (
    <window
      gdkmonitor={monitor}
      name={`right-panel-${getMonitorName(monitor.get_display(), monitor)}`}
      namespace={"right-panel"}
      application={App}
      class={createComputed(() =>
        rightPanelExclusivity() ? "right-panel exclusive" : "right-panel normal"
      )}
      anchor={
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={createComputed(() =>
        rightPanelExclusivity()
          ? Astal.Exclusivity.EXCLUSIVE
          : Astal.Exclusivity.NORMAL
      )}
      layer={createComputed(() =>
        rightPanelExclusivity() ? Astal.Layer.BOTTOM : Astal.Layer.TOP
      )}
      margin={createComputed(() =>
        rightPanelExclusivity() ? 0 : globalMargin
      )}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={rightPanelVisibility}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          setRightPanelVisibility(false);
          hideWindow(
            `right-panel-${getMonitorName(monitor.get_display(), monitor)}`
          );
          return true;
        }
      }}
      child={<Panel />}
    />
  );
};

export function RightPanelVisibility() {
  return (
    <revealer
      revealChild={rightPanelLock}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={globalTransition}
      child={
        <togglebutton
          active={rightPanelVisibility}
          label={createComputed(() => (rightPanelVisibility() ? "" : ""))}
          onToggled={(self: any, on: boolean) => setRightPanelVisibility(on)}
          class="panel-trigger icon"
        />
      }
    />
  );
}
