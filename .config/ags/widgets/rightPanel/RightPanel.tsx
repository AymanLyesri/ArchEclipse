import App from "ags/gtk4/app";
import Astal from "gi://Astal?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import {
  globalMargin,
  globalTransition,
  rightPanelExclusivity,
  rightPanelLock,
  rightPanelVisibility,
  setRightPanelVisibility,
  rightPanelWidgets,
  setRightPanelWidgets,
  rightPanelWidth,
  widgetLimit,
  setRightPanelWidth,
  setRightPanelExclusivity,
  setRightPanelLock,
} from "../../variables";
import { createBinding, For } from "ags";
import { Eventbox } from "../Custom/Eventbox";
import { getMonitorName } from "../../utils/monitor";
import { hideWindow, WindowActions } from "../../utils/window";
import { rightPanelWidgetSelectors } from "../../constants/widget.constants";

const WidgetActions = () => {
  return (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      class="widget-actions"
      spacing={5}
    >
      {rightPanelWidgetSelectors.map((selector) => {
        const isActive = rightPanelWidgets
          .get()
          .some((w) => w.name === selector.name);
        return (
          <togglebutton
            class="widget-selector"
            label={selector.icon}
            onToggled={({ active }) => {
              if (active) {
                if (rightPanelWidgets.get().length >= widgetLimit) return;
                setRightPanelWidgets([...rightPanelWidgets.get(), selector]);
              } else {
                const newWidgets = rightPanelWidgets
                  .get()
                  .filter((w) => w.name !== selector.name);
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
  <box class="panel-actions" orientation={Gtk.Orientation.VERTICAL}>
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
    <box halign={Gtk.Align.END}>
      {/* <Eventbox
        onHoverLost={() => {
          if (!rightPanelLock.get()) setRightPanelVisibility(false);
        }}
      >
        <box css="min-width: 5px;" />
      </Eventbox> */}
      <box
        class="main-content"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
      >
        <For each={rightPanelWidgets}>
          {(widget) => {
            const selector = rightPanelWidgetSelectors.find(
              (w) => w.name === widget.name
            );
            if (selector?.widget) {
              try {
                return selector.widget() as JSX.Element;
              } catch (error) {
                console.error(`Error rendering widget:`, error);
                return (<box />) as JSX.Element;
              }
            }
            return (<box />) as JSX.Element;
          }}
        </For>
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
      namespace="right-panel"
      application={App}
      class={rightPanelExclusivity((exclusivity) =>
        exclusivity ? "right-panel exclusive" : "right-panel normal"
      )}
      anchor={
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={rightPanelExclusivity((exclusivity) =>
        exclusivity ? Astal.Exclusivity.EXCLUSIVE : Astal.Exclusivity.NORMAL
      )}
      layer={rightPanelExclusivity((exclusivity) =>
        exclusivity ? Astal.Layer.BOTTOM : Astal.Layer.TOP
      )}
      margin={rightPanelExclusivity((exclusivity) =>
        exclusivity ? 0 : globalMargin
      )}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={rightPanelVisibility}
      // onKeyPressEvent={(self, event) => {
      //   if (event.get_keyval()[1] === Gdk.KEY_Escape) {
      //     setRightPanelVisibility(false);
      //     hideWindow(
      //       `right-panel-${getMonitorName(monitor.get_display(), monitor)}`
      //     );
      //     return true;
      //   }
      // }}
      widthRequest={rightPanelWidth((w) => {
        print("Right Panel Width:", w);
        return w;
      })}
    >
      <Panel />
    </window>
  );
};

export function RightPanelVisibility() {
  return (
    <revealer
      revealChild={rightPanelLock}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={globalTransition}
    >
      <togglebutton
        active={rightPanelVisibility}
        label={rightPanelVisibility((v) => (v ? "" : ""))}
        onToggled={({ active }) => setRightPanelVisibility(active)}
        class="panel-trigger icon"
      />
    </revealer>
  );
}
