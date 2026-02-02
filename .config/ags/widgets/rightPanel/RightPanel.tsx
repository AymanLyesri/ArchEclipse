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
import { For } from "ags";
import { getMonitorName } from "../../utils/monitor";
import { hideWindow, WindowActions, Window } from "../../utils/window";
import { rightPanelWidgetSelectors } from "../../constants/widget.constants";
import GObject from "ags/gobject";
import { WidgetSelector } from "../../interfaces/widgetSelector.interface";
import app from "ags/gtk4/app";
import { timeout } from "ags/time";

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
      <For each={globalSettings(({ rightPanel }) => rightPanel.widgets)}>
        {(widget: WidgetSelector) => {
          return (
            <togglebutton
              class="widget-selector drag"
              label={widget.icon}
              active={widget.enabled}
              tooltipMarkup={`<b>Hold To Drag</b>\n${widget.name}`}
              onToggled={({ active }) => {
                const current = globalSettings.peek().rightPanel.widgets;
                if (active) {
                  // if (current.length >= widgetLimit) return;
                  // Enable the widget
                  setGlobalSetting(
                    "rightPanel.widgets",
                    current.map((w) =>
                      w.name === widget.name ? { ...w, enabled: true } : w,
                    ),
                  );
                }
                if (!active) {
                  setGlobalSetting(
                    "rightPanel.widgets",
                    current.map((w) =>
                      w.name === widget.name ? { ...w, enabled: false } : w,
                    ),
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
                  const windowInstance = (self.get_root() as any)
                    .rightPanelWindow;
                  if (windowInstance) {
                    windowInstance.setIsDragging(true);
                  }
                });

                dragSource.connect("prepare", () => {
                  print("DRAG SOURCE PREPARE");
                  const index = globalSettings
                    .peek()
                    .rightPanel.widgets.findIndex(
                      (w) => w.name === widget.name,
                    );

                  if (index === -1) return null;

                  const value = new GObject.Value();
                  value.init(GObject.TYPE_INT);
                  value.set_int(index);

                  return Gdk.ContentProvider.new_for_value(value);
                });

                dragSource.connect("drag-end", () => {
                  const windowInstance = (self.get_root() as any)
                    .rightPanelWindow;
                  if (windowInstance) {
                    timeout(100, () => {
                      windowInstance.setIsDragging(false);
                    });
                  }
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

                  const widgets = globalSettings.peek().rightPanel.widgets;
                  const toIndex = widgets.findIndex(
                    (w) => w.name === widget.name,
                  );

                  if (toIndex === -1 || fromIndex === toIndex) {
                    const windowInstance = (self.get_root() as any)
                      .rightPanelWindow;
                    if (windowInstance) {
                      timeout(100, () => {
                        windowInstance.setIsDragging(false);
                      });
                    }
                    return true;
                  }

                  setGlobalSetting(
                    "rightPanel.widgets",
                    moveItem(widgets, fromIndex, toIndex),
                  );

                  const windowInstance = (self.get_root() as any)
                    .rightPanelWindow;
                  if (windowInstance) {
                    timeout(100, () => {
                      windowInstance.setIsDragging(false);
                    });
                  }

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

const Actions = () => (
  <box
    class="panel-actions"
    halign={Gtk.Align.END}
    orientation={Gtk.Orientation.VERTICAL}
  >
    <WidgetActions />
    <WindowActions
      // windowName={"right-panel"}
      windowWidth={globalSettings(({ rightPanel }) => rightPanel.width)}
      windowSettingKey="rightPanel"
      windowExclusivity={globalSettings(
        ({ rightPanel }) => rightPanel.exclusivity,
      )}
      windowLock={globalSettings(({ rightPanel }) => rightPanel.lock)}
    />
  </box>
);

function Panel() {
  let oldWidgets: WidgetSelector[] = [];
  // const [newWidgetsIndex, setNewWidgetsIndex] = createState<number[]>([]);
  let newWidgetsIndex: number[] = [];
  /// Get enabled widgets with their components cause `widget()` its not saved in settings file
  const enabledWidgets = globalSettings(({ rightPanel }) => {
    const enabled = rightPanel.widgets.filter((w) => w.enabled);

    newWidgetsIndex = enabled
      .map((item, index) => (oldWidgets.includes(item) ? -1 : index))
      .filter((index) => index !== -1);

    oldWidgets = enabled;
    //add widget function from constants
    const widgetSelectors = rightPanelWidgetSelectors;
    return enabled
      .map((w) => {
        const selector = widgetSelectors.find(
          (selector) => selector.name === w.name,
        );
        if (selector) {
          return {
            ...w,
            widget: selector.widget,
          };
        }
        return null;
      })
      .filter((w) => w !== null) as typeof enabled;
  });

  return (
    <box>
      <box
        hexpand
        class="main-content"
        orientation={Gtk.Orientation.VERTICAL}
        widthRequest={globalSettings(({ rightPanel }) => rightPanel.width)} // ignore action section
      >
        <For each={enabledWidgets}>
          {(widget, index) => {
            try {
              return widget.widget({
                height: globalSettings(
                  ({ rightPanel }) => rightPanel.width - 20,
                ),
                className: newWidgetsIndex.includes(index.peek())
                  ? "new-widget"
                  : "",
              }) as JSX.Element;
            } catch (error) {
              console.error(`Error rendering widget:`, error);
              return (<box />) as JSX.Element;
            }
          }}
        </For>
      </box>
      <Actions />
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
      name={`right-panel-${monitorName}`}
      namespace="right-panel"
      application={App}
      class={globalSettings(({ rightPanel }) =>
        rightPanel.exclusivity ? "right-panel exclusive" : "right-panel normal",
      )}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.BOTTOM
      }
      exclusivity={globalSettings(({ rightPanel }) =>
        rightPanel.exclusivity
          ? Astal.Exclusivity.EXCLUSIVE
          : Astal.Exclusivity.NORMAL,
      )}
      layer={Astal.Layer.TOP}
      marginTop={5}
      marginBottom={5}
      keymode={Astal.Keymode.ON_DEMAND}
      visible={false}
      $={(self) => {
        setup(self);
        const windowInstance = new Window();
        (self as any).rightPanelWindow = windowInstance;
        (self as any).monitorName = monitorName;

        const motion = new Gtk.EventControllerMotion();

        motion.connect("leave", () => {
          if (globalSettings.peek().rightPanel.lock) return;

          const windowInstance = (self as any).rightPanelWindow;
          if (windowInstance && windowInstance.isDragging()) return;

          hideWindow(`right-panel-${monitorName}`);
        });

        self.add_controller(motion);
      }}
    >
      <Gtk.EventControllerKey
        onKeyPressed={({ widget }, keyval: number) => {
          if (keyval === Gdk.KEY_Escape) {
            hideWindow(`right-panel-${monitorName}`);
            widget.hide();
            return true;
          }
        }}
      />

      <Panel />
    </window>
  );
};

export function RightPanelVisibility() {
  return (
    <revealer
      revealChild={globalSettings(({ rightPanel }) => rightPanel.lock)}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      transitionDuration={globalTransition}
    >
      <togglebutton
        active={false}
        label={""}
        onToggled={(self) => {
          const rightPanel = app.get_window(
            `right-panel-${(self.get_root() as any).monitorName}`,
          ) as Gtk.Window;
          if (self.active) {
            rightPanel.show();
            self.label = "";
          } else {
            rightPanel.hide();
            self.label = "";
          }
        }}
        class="panel-trigger icon"
        tooltipText={"SUPER + R"}
      />
    </revealer>
  );
}
