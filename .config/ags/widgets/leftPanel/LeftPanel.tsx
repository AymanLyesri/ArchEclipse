import App from "ags/gtk3/app";
import Gtk from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import { getMonitorName } from "../../utils/monitor";
import { createBinding, createComputed } from "ags";
import {
  globalMargin,
  globalTransition,
  leftPanelExclusivity,
  setLeftPanelExclusivity,
  leftPanelLock,
  setLeftPanelLock,
  leftPanelVisibility,
  setLeftPanelVisibility,
  leftPanelWidget,
  setLeftPanelWidget,
  leftPanelWidth,
  setLeftPanelWidth,
} from "../../variables";

import { hideWindow, WindowActions } from "../../utils/window";
import ToggleButton from "../toggleButton";
import { leftPanelWidgetSelectors } from "../../constants/widget.constants";

const WidgetActions = () => (
  <box className={"widget-actions"} vertical={true} spacing={10}>
    {leftPanelWidgetSelectors.map((widgetSelector) => (
      <ToggleButton
        state={createComputed(
          () => leftPanelWidget().name === widgetSelector.name
        )}
        label={widgetSelector.icon}
        onToggled={() => setLeftPanelWidget(widgetSelector)}
      />
    ))}
  </box>
);

const Actions = () => (
  <box className={"panel-actions"} vertical={true}>
    <WidgetActions />
    <WindowActions
      windowWidth={leftPanelWidth}
      setWindowWidth={setLeftPanelWidth}
      windowExclusivity={leftPanelExclusivity}
      setWindowExclusivity={setLeftPanelExclusivity}
      windowLock={leftPanelLock}
      setWindowLock={setLeftPanelLock}
      windowVisibility={leftPanelVisibility}
      setWindowVisibility={setLeftPanelVisibility}
    />
  </box>
);

function Panel() {
  return (
    <box>
      <Actions />
      <box
        className={"main-content"}
        widthRequest={leftPanelWidth}
        child={createComputed(
          () =>
            leftPanelWidgetSelectors
              .find((ws) => ws.name === leftPanelWidget().name)
              ?.widget() || <box />
        )}
      ></box>
      <eventbox
        onHoverLost={() => {
          if (!leftPanelLock()) setLeftPanelVisibility(false);
        }}
        child={<box css={"min-width:5px"} />}
      ></eventbox>
    </box>
  );
}

export default (monitor: Gdk.Monitor) => {
  return (
    <window
      gdkmonitor={monitor}
      name={`left-panel-${getMonitorName(monitor.get_display(), monitor)}`}
      namespace={"left-panel"}
      application={App}
      className={createComputed(() =>
        leftPanelExclusivity() ? "left-panel exclusive" : "left-panel normal"
      )}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={createComputed(() =>
        leftPanelExclusivity()
          ? Astal.Exclusivity.EXCLUSIVE
          : Astal.Exclusivity.NORMAL
      )}
      layer={createComputed(() =>
        leftPanelExclusivity() ? Astal.Layer.BOTTOM : Astal.Layer.TOP
      )}
      margin={createComputed(() => (leftPanelExclusivity() ? 0 : globalMargin))}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={leftPanelVisibility}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          setLeftPanelVisibility(false);
          hideWindow(
            `left-panel-${getMonitorName(monitor.get_display(), monitor)}`
          );
          return true;
        }
      }}
      child={<Panel />}
    />
  );
};

export function LeftPanelVisibility() {
  return (
    <revealer
      revealChild={leftPanelLock}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={globalTransition}
      child={
        <ToggleButton
          state={leftPanelVisibility}
          label={createComputed(() => (leftPanelVisibility() ? "" : ""))}
          onToggled={(self: any, on: boolean) => setLeftPanelVisibility(on)}
          className="panel-trigger icon"
        />
      }
    />
  );
}
