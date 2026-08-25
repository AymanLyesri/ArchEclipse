import App from "ags/gtk4/app";
import { Astal } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Gtk } from "ags/gtk4";
import {
  globalSettings,
  globalTransition,
  setGlobalSetting,
} from "../../variables";
import { getMonitorName } from "../../utils/monitor";
import { WindowActions, Window, hideWindow } from "../../utils/window";
import { leftPanelWidgetSelectors } from "../../constants/widget.constants";
import app from "ags/gtk4/app";
import { timeout, Timer } from "ags/time";
import { createRoot } from "gnim";

function Panel() {
  const WidgetActions = () => (
    <box orientation={Gtk.Orientation.VERTICAL} class="widget-actions">
      {leftPanelWidgetSelectors.map((widgetSelector) => {
        return (
          <togglebutton
            class={`${widgetSelector.name}`}
            label={widgetSelector.icon}
            active={globalSettings(
              ({ leftPanel }) => leftPanel.widget.name === widgetSelector.name,
            )}
            onToggled={({ active }) => {
              if (active) {
                setGlobalSetting("leftPanel.widget", widgetSelector);
              }
            }}
            tooltipMarkup={`Click to open\n<b>${widgetSelector.name}</b>`}
            $={(self) => {
              // if its the donations widget, show a custom tooltip with
              if (widgetSelector.name === "Donations") {
                self.set_tooltip_markup(
                  "<b>Support this project if it helped you ❤️</b>\n\nClick to open\n<b>Donations</b>",
                );
              }
            }}
          />
        );
      })}
    </box>
  );

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

  const widgetCache = new Map<string, Gtk.Widget>();
  const addedWidgets = new Set<string>();

  const panelStack = new Gtk.Stack({
    transition_type: Gtk.StackTransitionType.SLIDE_LEFT_RIGHT,
    transition_duration: globalTransition,
    hexpand: true,
    vexpand: true,
  });

  const buildWidget = (name: string): Gtk.Widget | null => {
    // LAZY: widgets are created on first display instead of eagerly at
    // startup. Precreating all 8 panels (most disabled, window hidden)
    // dominated cold-start time (~700 ms of per-monitor init).
    if (widgetCache.has(name)) return widgetCache.get(name)!;

    const selector = leftPanelWidgetSelectors.find((s) => s.name === name);
    if (!selector) return null;

    try {
      // createRoot gives lazily-created widgets a proper reactive scope.
      // Without it, JSX created inside a settings-subscribe callback runs
      // "out of tracking context" and throws (bindings + onCleanup need
      // an owning scope). The dispose fn is intentionally dropped: these
      // panels live for the app's lifetime, same as eager creation did.
      const widget = createRoot((dispose) => (
        <box hexpand vexpand>
          {selector.widget?.({}) as JSX.Element}
        </box>
      )) as Gtk.Widget;
      widgetCache.set(name, widget);
      return widget;
    } catch (err) {
      console.error(`[LeftPanel] failed to create widget "${name}":`, err);
      return null;
    }
  };

  const showWidget = (name: string) => {
    const widget = buildWidget(name);

    if (!widget) return;

    if (!addedWidgets.has(name)) {
      panelStack.add_child(widget);
      addedWidgets.add(name);
    }

    panelStack.set_visible_child(widget);
  };

  return (
    <box>
      <Actions />
      <box
        hexpand
        class="main-content"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        widthRequest={globalSettings(({ leftPanel }) => leftPanel.width)}
        $={(self) => {
          const updateVisibleChild = () => {
            showWidget(globalSettings.peek().leftPanel.widget.name);
          };

          updateVisibleChild();

          const unsubscribe = globalSettings.subscribe(updateVisibleChild);
          self.connect("destroy", () => {
            if (unsubscribe) {
              unsubscribe();
            }
          });
        }}
      >
        {panelStack}
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

          hideTimeout = timeout(0, () => {
            hideTimeout = null;
            if (
              !globalSettings.peek().leftPanel.lock &&
              !windowInstance.popupIsOpen()
            ) {
              hideWindow(`left-panel-${monitorName}`);
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
            widget!.hide();
            return true;
          }
        }}
      />
      <Panel />
    </window>
  );
};
