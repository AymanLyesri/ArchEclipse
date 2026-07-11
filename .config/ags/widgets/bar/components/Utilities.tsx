import Brightness from "../../../services/brightness";
import CustomRevealer from "../../CustomRevealer";
import { Accessor, createBinding, createComputed, With } from "ags";

import { Gtk } from "ags/gtk4";
import {
  globalSettings,
  globalTheme,
  globalTransition,
  setGlobalSetting,
  setGlobalTheme,
  systemResourcesData,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { For } from "ags";
import AstalTray from "gi://AstalTray";
import AstalBattery from "gi://AstalBattery";
import AstalPowerProfiles from "gi://AstalPowerProfiles";
import CircularProgress from "../../CircularProgress";
import { timeout, Timer } from "ags/time";
import SystemResources from "../../rightPanel/components/SystemResources";
import { connectPopoverEvents } from "../../../utils/window";

import Hyprland from "gi://AstalHyprland";
import ControlPanel from "../../ControlPanel";
import Volume from "./sub-components/Volume";
import Battery from "./sub-components/Battery";
const hyprland = Hyprland.get_default();

function BrightnessWidget() {
  const brightness = Brightness.get_default();
  const screen = createBinding(brightness, "screen");

  const label = (
    <label
      label={screen((v) => {
        switch (true) {
          case v > 0.75:
            return "󰃠";
          case v > 0.5:
            return "󰃟";
          case v > 0:
            return "󰃞";
          default:
            return "󰃞";
        }
      })}
    />
  );

  const percentage = (
    <label label={screen((v: number) => `${Math.round(v * 100)}%`)} />
  );

  const slider = (
    <slider
      widthRequest={100}
      class="slider"
      drawValue={false}
      onValueChanged={({ value }) => {
        if (value == screen.peek()) return;
        brightness.screen = value;
      }}
      value={screen}
    />
  );

  const trigger = (
    <box class="trigger" spacing={5} children={[label, percentage]} />
  );

  let hideTimeout: any = null;
  let isHovering = false;
  let lastScreen = brightness.screen;
  let firstRender = true;

  const revealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SWING_LEFT}
      $={(self) => {
        brightness.connect(`notify::screen`, () => {
          const currentScreen = brightness.screen;

          // Skip the initial notification on component mount
          if (firstRender) {
            firstRender = false;
            lastScreen = currentScreen;
            return;
          }

          // Ignore spurious notifications where value did not change
          if (currentScreen === lastScreen) {
            return;
          }

          lastScreen = currentScreen;
          self.reveal_child = true;

          if (hideTimeout) {
            clearTimeout(hideTimeout);
          }

          // Set new timeout to hide after 2 seconds of no brightness changes
          hideTimeout = setTimeout(() => {
            if (!isHovering) {
              self.reveal_child = false;
            }
          }, 2000);
        });
      }}
    >
      {slider}
    </revealer>
  );

  return (
    <box
      tooltipText={screen((v) => `Brightness: ${Math.round(v * 100)}%`)}
      class={"custom-revealer"}
      visible={createBinding(brightness, "hasBacklight")}
    >
      <Gtk.EventControllerMotion
        onEnter={() => {
          isHovering = true;
          if (hideTimeout) {
            clearTimeout(hideTimeout);
          }
          (revealer as Gtk.Revealer).reveal_child = true;
        }}
        onLeave={() => {
          isHovering = false;
          if (hideTimeout) {
            clearTimeout(hideTimeout);
          }
          hideTimeout = setTimeout(() => {
            (revealer as Gtk.Revealer).reveal_child = false;
          }, 2000);
        }}
      ></Gtk.EventControllerMotion>
      <box class={"content"}>
        {trigger}
        {revealer}
      </box>
    </box>
  );
}

function Tray() {
  const tray = AstalTray.get_default();
  const items = createBinding(tray, "items");
  const MAX_VISIBLE = 3;

  const init = (btn: Gtk.MenuButton, item: AstalTray.TrayItem) => {
    btn.menuModel = item.menuModel;
    btn.insert_action_group("dbusmenu", item.actionGroup);
    item.connect("notify::action-group", () => {
      btn.insert_action_group("dbusmenu", item.actionGroup);
    });
  };

  const visibleItems = items((itemList) => itemList.slice(0, MAX_VISIBLE));
  const hiddenItems = items((itemList) => itemList.slice(MAX_VISIBLE));
  const hasHidden = items((itemList) => itemList.length > MAX_VISIBLE);

  return (
    <box class="system-tray">
      <box spacing={2}>
        <For each={visibleItems}>
          {(item) => (
            <menubutton
              class="tray-icon"
              $={(self) => {
                init(self, item);
                connectPopoverEvents(self, "barWindow");
              }}
              tooltipText={item.tooltip_text}
            >
              <image pixelSize={11} gicon={createBinding(item, "gicon")} />
            </menubutton>
          )}
        </For>
      </box>
      <box spacing={2}>
        <With value={hasHidden}>
          {(hidden) =>
            hidden && (
              <menubutton
                class="tray-icon tray-overflow"
                tooltipText="More icons"
              >
                <image pixelSize={11} iconName="view-more-symbolic" />
                <popover
                  $={(self) => {
                    self.connect("notify::visible", () => {
                      if (self.visible) self.add_css_class("popover-open");
                      else if (self.get_child())
                        self.remove_css_class("popover-open");
                    });
                  }}
                >
                  <box
                    class="tray-popover"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={5}
                  >
                    <For each={hiddenItems}>
                      {(item) => (
                        <menubutton
                          class="tray-icon"
                          $={(self) => init(self, item)}
                          tooltipText={item.tooltip_text}
                        >
                          <box spacing={8}>
                            <image
                              pixelSize={11}
                              gicon={createBinding(item, "gicon")}
                            />
                            <label label={item.tooltip_text} xalign={0} />
                          </box>
                        </menubutton>
                      )}
                    </For>
                  </box>
                </popover>
              </menubutton>
            )
          }
        </With>
      </box>
    </box>
  );
}

function ResourceMonitor() {
  return (
    <button
      class="resource-monitor"
      $={(self) => {
        const popover = new Gtk.Popover({
          has_arrow: true,
          position: Gtk.PositionType.BOTTOM,
          autohide: false,
        });

        popover.set_child(
          SystemResources({
            className: "resource-monitor-popover",
            orientation: Gtk.Orientation.HORIZONTAL,
          }) as unknown as Gtk.Widget,
        );
        popover.set_parent(self);

        let hideTimeout: Timer;

        const monitorMotion = new Gtk.EventControllerMotion();
        monitorMotion.connect("enter", () => {
          if (hideTimeout) {
            hideTimeout.cancel();
          }
          popover.popup();
        });

        monitorMotion.connect("leave", () => {
          hideTimeout = timeout(80, () => {
            popover.popdown();
            hideTimeout.cancel();
          });
        });

        self.add_controller(monitorMotion);

        const popoverMotion = new Gtk.EventControllerMotion();
        popoverMotion.connect("enter", () => {
          if (hideTimeout) {
            hideTimeout.cancel();
          }
        });

        popoverMotion.connect("leave", () => {
          popover.popdown();
        });

        popover.add_controller(popoverMotion);
      }}
    >
      <Gtk.GestureClick
        onPressed={() => {
          hyprland.dispatch("workspace", "5");
        }}
      />
      <With value={systemResourcesData}>
        {(res) => (
          <box spacing={10}>
            <CircularProgress
              visible={res?.cpuLoad !== undefined}
              tooltipText={`CPU Usage ${res?.cpuLoad}%`}
              value={res?.cpuLoad ? res?.cpuLoad / 100 : 0}
              className="cpu-monitor"
              icon=""
            />
            <CircularProgress
              visible={
                res?.ramUsedGB !== undefined && res?.ramTotalGB !== undefined
              }
              tooltipText={`RAM Usage ${res?.ramUsedGB && res?.ramTotalGB ? Math.round((res.ramUsedGB / res.ramTotalGB) * 100) : 0}%`}
              value={
                res?.ramUsedGB && res?.ramTotalGB
                  ? res.ramUsedGB / res.ramTotalGB
                  : 0
              }
              className="ram-monitor"
              icon=""
            />
            <CircularProgress
              visible={res?.gpuLoad !== undefined}
              tooltipText={`GPU Usage ${res?.gpuLoad}%`}
              value={res?.gpuLoad ? res?.gpuLoad / 100 : 0}
              className="gpu-monitor"
              icon="󱤟"
            />
          </box>
        )}
      </With>
    </button>
  );
}

function ControlPanelButton() {
  return (
    <menubutton $={(self) => connectPopoverEvents(self, "barWindow")}>
      <label label="󱗼" />
      <popover>
        <ControlPanel />
      </popover>
    </menubutton>
  );
}

export default ({ halign }: { halign?: Gtk.Align | Accessor<Gtk.Align> }) => {
  return (
    <box class="utilities" spacing={5} halign={halign}>
      <Battery />
      <BrightnessWidget />
      <Volume />
      <Tray />
      <ResourceMonitor />
      <ControlPanelButton />
    </box>
  );
};
