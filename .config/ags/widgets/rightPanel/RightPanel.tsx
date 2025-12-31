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
import { createBinding, For, With } from "ags";
import { Eventbox } from "../Custom/Eventbox";
import { getMonitorName } from "../../utils/monitor";
import { hideWindow, WindowActions, queueResize } from "../../utils/window";
import { rightPanelWidgetSelectors } from "../../constants/widget.constants";
import GObject from "ags/gobject";

function moveItem<T>(array: T[], from: number, to: number): T[] {
  const copy = [...array];
  const [item] = copy.splice(from, 1);
  copy.splice(to, 0, item);
  return copy;
}

const WidgetActions = () => {
  return (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      class="widget-actions"
      spacing={5}
    >
      <For each={rightPanelWidgets}>
        {(widget) => {
          return (
            <togglebutton
              class="widget-selector drag"
              label={widget.icon}
              active={widget.enabled}
              tooltipMarkup={`<b>Hold To Drag</b>\n${widget.name}`}
              onToggled={({ active }) => {
                const current = rightPanelWidgets.get();
                if (active) {
                  // if (current.length >= widgetLimit) return;
                  // Enable the widget
                  setRightPanelWidgets(
                    current.map((w) =>
                      w.name === widget.name ? { ...w, enabled: true } : w
                    )
                  );
                }
                if (!active) {
                  setRightPanelWidgets(
                    current.map((w) =>
                      w.name === widget.name ? { ...w, enabled: false } : w
                    )
                  );
                }
              }}
              $={(self) => {
                /* ---------- Drag source ---------- */
                const dragSource = new Gtk.DragSource({
                  actions: Gdk.DragAction.MOVE,
                });

                dragSource.connect("drag-begin", (source) => {
                  source.set_icon(Gtk.WidgetPaintable.new(self), 0, 0);
                });

                dragSource.connect("prepare", () => {
                  print("DRAG SOURCE PREPARE");
                  const index = rightPanelWidgets
                    .get()
                    .findIndex((w) => w.name === widget.name);

                  if (index === -1) return null;

                  const value = new GObject.Value();
                  value.init(GObject.TYPE_INT);
                  value.set_int(index);

                  return Gdk.ContentProvider.new_for_value(value);
                });

                self.add_controller(dragSource);

                /* ---------- Drop target ---------- */
                const dropTarget = new Gtk.DropTarget({
                  actions: Gdk.DragAction.MOVE,
                });

                dropTarget.set_gtypes([GObject.TYPE_INT]);

                dropTarget.connect("drop", (_, value: number) => {
                  print("DROP TARGET DROP");
                  const fromIndex = value;

                  const widgets = rightPanelWidgets.get();
                  const toIndex = widgets.findIndex(
                    (w) => w.name === widget.name
                  );

                  if (toIndex === -1 || fromIndex === toIndex) return true;

                  setRightPanelWidgets(moveItem(widgets, fromIndex, toIndex));

                  return true;
                });

                self.add_controller(dropTarget);
              }}
            />
          );
        }}
      </For>
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
  /// Get enabled widgets with their components cause `widget()` its not saved in settings file
  const enabledWidgets = rightPanelWidgets((widgets) => {
    const enabled = widgets.filter((w) => w.enabled);
    //add widget function from constants
    const widgetSelectors = rightPanelWidgetSelectors;
    return enabled
      .map((w) => {
        const selector = widgetSelectors.find(
          (selector) => selector.name === w.name
        );
        if (selector) {
          return {
            ...w,
            widget: selector.widget,
          };
        }
        return null;
      })
      .filter((w) => w !== null) as typeof widgets;
  });

  return (
    <box>
      <box
        hexpand
        class="main-content"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        widthRequest={rightPanelWidth} // ignore action section
      >
        <For each={enabledWidgets}>
          {(widget) => {
            try {
              return widget.widget(undefined, rightPanelWidth) as JSX.Element;
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
      layer={Astal.Layer.TOP}
      marginTop={5}
      marginRight={globalMargin}
      marginBottom={5}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={rightPanelVisibility}
      $={(self) => {
        let hideTimeout: NodeJS.Timeout | null = null;

        const motion = new Gtk.EventControllerMotion();

        motion.connect("leave", () => {
          if (rightPanelLock.get()) return;

          hideTimeout = setTimeout(() => {
            hideTimeout = null;
            if (!rightPanelLock.get()) {
              setRightPanelVisibility(false);
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
        tooltipText={"SUPER + R"}
      />
    </revealer>
  );
}
