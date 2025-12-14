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
import { hideWindow, WindowActions, queueResize } from "../../utils/window";
import { rightPanelWidgetSelectors } from "../../constants/widget.constants";

const WidgetActions = () => {
  return (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      class="widget-actions"
      spacing={5}
    >
      {rightPanelWidgetSelectors.map((selector) => {
        return (
          <togglebutton
            class="widget-selector"
            label={selector.icon}
            active={rightPanelWidgets((widgets) =>
              widgets.some((w) => w.name === selector.name)
            )}
            onToggled={({ active }) => {
              const currentWidgets = rightPanelWidgets.get();
              const isCurrentlyActive = currentWidgets.some(
                (w) => w.name === selector.name
              );

              if (active && !isCurrentlyActive) {
                if (currentWidgets.length >= widgetLimit) {
                  return;
                }
                setRightPanelWidgets([...currentWidgets, selector]);
              } else if (!active && isCurrentlyActive) {
                const newWidgets = currentWidgets.filter(
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

const Actions = ({ monitorName }: { monitorName: string }) => (
  <box
    class="panel-actions"
    halign={Gtk.Align.END}
    orientation={Gtk.Orientation.VERTICAL}
  >
    <WidgetActions />
    <WindowActions
      windowName={monitorName}
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

function Panel({ monitorName }: { monitorName: string }) {
  const selectedWidgets = rightPanelWidgets((widgets) =>
    widgets.filter((widget) => {
      const selector = rightPanelWidgetSelectors.find(
        (w) => w.name === widget.name
      );
      return selector?.widget;
    })
  );

  return (
    <box>
      <box
        hexpand
        class="main-content"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
      >
        <For each={selectedWidgets}>
          {(widget) => {
            const selector = rightPanelWidgetSelectors.find(
              (w) => w.name === widget.name
            );
            try {
              return selector!.widget() as JSX.Element;
            } catch (error) {
              console.error(`Error rendering widget:`, error);
              return (<box />) as JSX.Element;
            }
          }}
        </For>
      </box>
      <Actions monitorName={monitorName} />
    </box>
  );
}
export default (monitor: Gdk.Monitor) => {
  const monitorName = `right-panel-${getMonitorName(
    monitor.get_display(),
    monitor
  )}`;
  return (
    <window
      gdkmonitor={monitor}
      name={monitorName}
      namespace="right-panel"
      application={App}
      class={rightPanelExclusivity((exclusivity) =>
        exclusivity ? "right-panel exclusive" : "right-panel normal"
      )}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.RIGHT |
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
      widthRequest={rightPanelWidth}
      $={(self) => {
        const motion = new Gtk.EventControllerMotion();
        motion.connect("leave", () => {
          if (!rightPanelLock.get()) setRightPanelVisibility(false);
        });
        self.add_controller(motion);
      }}
    >
      <Gtk.EventControllerKey
        onKeyPressed={({ widget }, keyval: number) => {
          if (keyval === Gdk.KEY_Escape) {
            setRightPanelVisibility(false);
            widget.hide();
            return true;
          }
        }}
      />
      <Panel monitorName={monitorName} />
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
