import App from "ags/gtk4/app";
import Astal from "gi://Astal?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
import {
  globalMargin,
  globalSettings,
  globalTransition,
  setGlobalSetting,
} from "../../variables";
import { createBinding, createState, Node, With } from "ags";
import { Eventbox } from "../Custom/Eventbox";
import { getMonitorName } from "../../utils/monitor";
import { hideWindow, WindowActions, Window } from "../../utils/window";
import { leftPanelWidgetSelectors } from "../../constants/widget.constants";
import { WidgetSelector } from "../../interfaces/widgetSelector.interface";
import app from "ags/gtk4/app";
import { timeout, Timer } from "ags/time";

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
            active={globalSettings(
              ({ leftPanel }) => leftPanel.widget.name === widgetSelector.name,
            )}
            onToggled={({ active }) => {
              if (active) {
                setGlobalSetting("leftPanel.widget", widgetSelector);
              }
            }}
            tooltipMarkup={`Click to select\n<b>${widgetSelector.name}</b>`}
          />
        );
      })}
    </box>
  );
};

const Actions = () => (
  <box
    class="panel-actions"
    halign={Gtk.Align.START}
    orientation={Gtk.Orientation.VERTICAL}
  >
    <WidgetActions />
    <WindowActions
      windowWidth={globalSettings(({ leftPanel }) => leftPanel.width)}
      windowSettingKey="leftPanel"
      windowExclusivity={globalSettings(
        ({ leftPanel }) => leftPanel.exclusivity,
      )}
      windowLock={globalSettings(({ leftPanel }) => leftPanel.lock)}
      minPanelWidth={400}
    />
  </box>
);

function Panel() {
  return (
    <box>
      <Actions />
      <box
        hexpand
        class="main-content"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        widthRequest={globalSettings(({ leftPanel }) => leftPanel.width)}
      >
        <With value={globalSettings(({ leftPanel }) => leftPanel.widget)}>
          {(widget: WidgetSelector) => {
            const selector = leftPanelWidgetSelectors.find(
              (ws) => ws.name === widget.name,
            );
            if (selector?.widget) {
              try {
                return selector.widget({}) as JSX.Element;
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

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor);
  return (
    <window
      gdkmonitor={monitor}
      name={`left-panel-${monitorName}`}
      namespace="left-panel"
      application={App}
      class={globalSettings(({ leftPanel }) =>
        leftPanel.exclusivity ? "left-panel exclusive" : "left-panel normal",
      )}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={globalSettings(({ leftPanel }) =>
        leftPanel.exclusivity
          ? Astal.Exclusivity.EXCLUSIVE
          : Astal.Exclusivity.NORMAL,
      )}
      layer={Astal.Layer.TOP}
      keymode={Astal.Keymode.ON_DEMAND}
      marginTop={5}
      marginBottom={5}
      visible={false}
      $={(self) => {
        setup(self);
        let hideTimeout: Timer | null = null;
        const windowInstance = new Window();
        (self as any).leftPanelWindow = windowInstance;

        const motion = new Gtk.EventControllerMotion();

        motion.connect("leave", () => {
          if (globalSettings.peek().leftPanel.lock) return;

          hideTimeout = timeout(100, () => {
            hideTimeout = null;
            if (
              !globalSettings.peek().leftPanel.lock &&
              !windowInstance.popupIsOpen()
            ) {
              app.get_window(`left-panel-${monitorName}`)?.hide();
            }
          });
        });

        motion.connect("enter", () => {
          if (hideTimeout !== null) {
            hideTimeout.cancel();
            hideTimeout = null;
          }
        });

        self.add_controller(motion);
      }}
    >
      <Gtk.EventControllerKey
        onKeyPressed={({ widget }, keyval: number) => {
          if (keyval === Gdk.KEY_Escape) {
            app.get_window(`left-panel-${monitorName}`)?.hide();
            widget.hide();
            return true;
          }
        }}
      />
      <Panel />
    </window>
  );
};

export function LeftPanelVisibility() {
  return (
    <revealer
      revealChild={globalSettings(({ leftPanel }) => leftPanel.lock)}
      transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
      transitionDuration={globalTransition}
    >
      <togglebutton
        active={false}
        label={""}
        onToggled={(self) => {
          const leftPanel = app.get_window(
            `left-panel-${(self.get_root() as any).monitorName}`,
          ) as Gtk.Window;
          if (self.active) {
            leftPanel.show();
            self.label = "";
          } else {
            leftPanel.hide();
            self.label = "";
          }
        }}
        class="panel-trigger"
        tooltipText={"SUPER + L"}
      />
    </revealer>
  );
}
