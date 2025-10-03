import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import {
  globalMargin,
  globalTransition,
  rightPanelExclusivity,
  rightPanelLock,
  rightPanelVisibility,
  rightPanelWidgets,
  rightPanelWidth,
  widgetLimit,
} from "../../variables";
import { bind } from "astal";
import ToggleButton from "../toggleButton";
import { getMonitorName } from "../../utils/monitor";
import { hideWindow, WindowActions } from "../../utils/window";
import { rightPanelWidgetSelectors } from "../../constants/widget.constants";

const WidgetActions = () => {
  return (
    <box
      vertical={true}
      vexpand={true}
      className={"widget-actions"}
      spacing={5}
    >
      {rightPanelWidgetSelectors.map((selector) => {
        const isActive = rightPanelWidgets
          .get()
          .some((w) => w.name === selector.name);
        return (
          <ToggleButton
            className={"widget-selector"}
            label={selector.icon}
            state={isActive}
            onToggled={(self, on) => {
              if (on) {
                if (rightPanelWidgets.get().length >= widgetLimit) return;
                rightPanelWidgets.set([...rightPanelWidgets.get(), selector]);
              } else {
                const newWidgets = rightPanelWidgets
                  .get()
                  .filter((w) => w.name !== selector.name);
                rightPanelWidgets.set(newWidgets);
              }
            }}
          />
        );
      })}
    </box>
  );
};

const Actions = () => (
  <box className={"panel-actions"} vertical={true}>
    <WidgetActions />
    <WindowActions
      windowWidth={rightPanelWidth}
      windowExclusivity={rightPanelExclusivity}
      windowLock={rightPanelLock}
      windowVisibility={rightPanelVisibility}
    />
  </box>
);

function Panel() {
  return (
    <box>
      <eventbox
        onHoverLost={() => {
          if (!rightPanelLock.get()) rightPanelVisibility.set(false);
        }}
        child={<box css={"min-width:5px"} />}
      ></eventbox>
      <box
        className={"main-content"}
        vertical={true}
        spacing={10}
        widthRequest={bind(rightPanelWidth)}
      >
        {bind(rightPanelWidgets).as((widgets) => {
          return widgets
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
      className={bind(rightPanelExclusivity).as((exclusivity) =>
        exclusivity ? "right-panel exclusive" : "right-panel normal"
      )}
      anchor={
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={bind(rightPanelExclusivity).as((exclusivity) =>
        exclusivity ? Astal.Exclusivity.EXCLUSIVE : Astal.Exclusivity.NORMAL
      )}
      layer={bind(rightPanelExclusivity).as((exclusivity) =>
        exclusivity ? Astal.Layer.BOTTOM : Astal.Layer.TOP
      )}
      margin={bind(rightPanelExclusivity).as((exclusivity) =>
        exclusivity ? 0 : globalMargin
      )}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={bind(rightPanelVisibility)}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          rightPanelVisibility.set(false);
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
      revealChild={bind(rightPanelLock).as((lock) => lock)}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={globalTransition}
      child={
        <ToggleButton
          state={bind(rightPanelVisibility)}
          label={bind(rightPanelVisibility).as((v) => (v ? "" : ""))}
          onToggled={(self, on) => rightPanelVisibility.set(on)}
          className="panel-trigger icon"
        />
      }
    />
  );
}
