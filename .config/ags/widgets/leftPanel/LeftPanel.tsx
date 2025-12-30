import App from "ags/gtk4/app";
import Astal from "gi://Astal?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import {
  globalMargin,
  globalTransition,
  leftPanelExclusivity,
  leftPanelLock,
  leftPanelVisibility,
  setLeftPanelVisibility,
  leftPanelWidget,
  setLeftPanelWidget,
  leftPanelWidth,
  setLeftPanelWidth,
  setLeftPanelExclusivity,
  setLeftPanelLock,
} from "../../variables";
import { createBinding, createState, Node, With } from "ags";
import { Eventbox } from "../Custom/Eventbox";
import { getMonitorName } from "../../utils/monitor";
import { hideWindow, WindowActions, Window } from "../../utils/window";
import { leftPanelWidgetSelectors } from "../../constants/widget.constants";

const WidgetActions = () => {
  return (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      class="widget-actions"
      spacing={10}
    >
      {leftPanelWidgetSelectors.map((widgetSelector) => {
        return (
          <togglebutton
            class="widget-selector"
            label={widgetSelector.icon}
            active={leftPanelWidget((w) => w.name === widgetSelector.name)}
            onToggled={({ active }) => {
              if (active) {
                setLeftPanelWidget(widgetSelector);
              }
            }}
            tooltipMarkup={`Click to select\n<b>${widgetSelector.name}</b>`}
          />
        );
      })}
    </box>
  );
};

const Actions = ({ monitorName }: { monitorName: string }) => (
  <box
    class="panel-actions"
    halign={Gtk.Align.START}
    orientation={Gtk.Orientation.VERTICAL}
  >
    <WidgetActions />
    <WindowActions
      windowName={monitorName}
      windowWidth={leftPanelWidth}
      setWindowWidth={setLeftPanelWidth}
      windowExclusivity={leftPanelExclusivity}
      setWindowExclusivity={setLeftPanelExclusivity}
      windowLock={leftPanelLock}
      setWindowLock={setLeftPanelLock}
      windowVisibility={leftPanelVisibility}
      setWindowVisibility={setLeftPanelVisibility}
      maxPanelWidth={1500}
      minPanelWidth={300}
    />
  </box>
);

function Panel({ monitorName }: { monitorName: string }) {
  return (
    <box>
      <Actions monitorName={monitorName} />
      <box
        hexpand
        class="main-content"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        widthRequest={leftPanelWidth}
      >
        <With value={leftPanelWidget}>
          {(widget) => {
            const selector = leftPanelWidgetSelectors.find(
              (ws) => ws.name === widget.name
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
        </With>
      </box>
    </box>
  );
}

export default (monitor: Gdk.Monitor) => {
  const monitorName = `left-panel-${getMonitorName(
    monitor.get_display(),
    monitor
  )}`;
  return (
    <window
      gdkmonitor={monitor}
      name={monitorName}
      namespace="left-panel"
      application={App}
      class={leftPanelExclusivity((exclusivity) =>
        exclusivity ? "left-panel exclusive" : "left-panel normal"
      )}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={leftPanelExclusivity((exclusivity) =>
        exclusivity ? Astal.Exclusivity.EXCLUSIVE : Astal.Exclusivity.NORMAL
      )}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.ON_DEMAND}
      marginTop={5}
      marginLeft={globalMargin}
      marginBottom={5}
      visible={leftPanelVisibility}
      $={(self) => {
        let hideTimeout: NodeJS.Timeout | null = null;
        const windowInstance = new Window();
        (self as any).leftPanelWindow = windowInstance;

        const motion = new Gtk.EventControllerMotion();

        motion.connect("leave", () => {
          if (leftPanelLock.get()) return;

          hideTimeout = setTimeout(() => {
            hideTimeout = null;
            if (!leftPanelLock.get() && !windowInstance.popupIsOpen()) {
              setLeftPanelVisibility(false);
            }
          }, 500);
        });

        motion.connect("enter", () => {
          if (hideTimeout !== null) {
            clearTimeout(hideTimeout);
            hideTimeout = null;
          }
        });

        self.add_controller(motion);
      }}
    >
      <Gtk.EventControllerKey
        onKeyPressed={({ widget }, keyval: number) => {
          if (keyval === Gdk.KEY_Escape) {
            setLeftPanelVisibility(false);
            widget.hide();
            return true;
          }
        }}
      />
      <Panel monitorName={monitorName} />
    </window>
  );
};

export function LeftPanelVisibility() {
  return (
    <revealer
      revealChild={leftPanelLock}
      transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
      transitionDuration={globalTransition}
    >
      <togglebutton
        active={leftPanelVisibility}
        label={leftPanelVisibility((v) => (v ? "" : ""))}
        onToggled={({ active }) => setLeftPanelVisibility(active)}
        class="panel-trigger"
        tooltipText={"SUPER + L"}
      />
    </revealer>
  );
}
