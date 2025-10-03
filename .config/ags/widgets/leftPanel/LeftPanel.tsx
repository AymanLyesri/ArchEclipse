import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { getMonitorName } from "../../utils/monitor";
import { bind, Variable } from "astal";
import {
  globalMargin,
  globalTransition,
  leftPanelExclusivity,
  leftPanelLock,
  leftPanelVisibility,
  leftPanelWidget,
  leftPanelWidth,
} from "../../variables";

import { hideWindow, WindowActions } from "../../utils/window";
import ToggleButton from "../toggleButton";
import { leftPanelWidgetSelectors } from "../../constants/widget.constants";

const WidgetActions = () => (
  <box className={"widget-actions"} vertical={true} spacing={10}>
    {leftPanelWidgetSelectors.map((widgetSelector) => (
      <ToggleButton
        state={bind(leftPanelWidget).as((w) => w.name === widgetSelector.name)}
        label={widgetSelector.icon}
        onToggled={() => leftPanelWidget.set(widgetSelector)}
      />
    ))}
  </box>
);

const Actions = () => (
  <box className={"panel-actions"} vertical={true}>
    <WidgetActions />
    <WindowActions
      windowWidth={leftPanelWidth}
      windowExclusivity={leftPanelExclusivity}
      windowLock={leftPanelLock}
      windowVisibility={leftPanelVisibility}
    />
  </box>
);

function Panel() {
  return (
    <box>
      <Actions />
      <box
        className={"main-content"}
        widthRequest={bind(leftPanelWidth)}
        child={bind(leftPanelWidget).as(
          (widget) =>
            leftPanelWidgetSelectors
              .find((ws) => ws.name === widget.name)
              ?.widget() || <box />
        )}
      ></box>
      <eventbox
        onHoverLost={() => {
          if (!leftPanelLock.get()) leftPanelVisibility.set(false);
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
      className={bind(leftPanelExclusivity).as((exclusivity) =>
        exclusivity ? "left-panel exclusive" : "left-panel normal"
      )}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={bind(leftPanelExclusivity).as((exclusivity) =>
        exclusivity ? Astal.Exclusivity.EXCLUSIVE : Astal.Exclusivity.NORMAL
      )}
      layer={bind(leftPanelExclusivity).as((exclusivity) =>
        exclusivity ? Astal.Layer.BOTTOM : Astal.Layer.TOP
      )}
      margin={bind(leftPanelExclusivity).as((exclusivity) =>
        exclusivity ? 0 : globalMargin
      )}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={bind(leftPanelVisibility)}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          leftPanelVisibility.set(false);
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
      revealChild={bind(leftPanelLock).as((lock) => lock)}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={globalTransition}
      child={
        <ToggleButton
          state={bind(leftPanelVisibility)}
          label={bind(leftPanelVisibility).as((v) => (v ? "" : ""))}
          onToggled={(self, on) => leftPanelVisibility.set(on)}
          className="panel-trigger icon"
        />
      }
    />
  );
}
