import Brightness from "../../../services/brightness";
const brightness = Brightness.get_default();
import CustomRevealer from "../../CustomRevealer";
import { createBinding, createComputed } from "ags";
import { execAsync } from "ags/process";

import Wp from "gi://AstalWp";

import Battery from "gi://AstalBattery";
const battery = Battery.get_default();

import Tray from "gi://AstalTray";
import Gtk from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";
import {
  barLock,
  setBarLock,
  barOrientation,
  setBarOrientation,
  DND,
  setDND,
  globalTheme,
  setGlobalTheme,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { For } from "ags";

function Theme() {
  return (
    <togglebutton
      active={globalTheme}
      onToggled={({ active }) => setGlobalTheme(active)}
      label={globalTheme((theme) => (theme ? "" : ""))}
      class="theme icon"
    />
  );
}

function BrightnessWidget() {
  const screen = createBinding(brightness, "screen");
  const slider = (
    <slider
      widthRequest={100}
      class="slider"
      drawValue={false}
      onValueChanged={(self) => (brightness.screen = self.get_value())}
      value={screen((v: number) => (isNaN(v) || v < 0 ? 0 : v > 1 ? 1 : v))}
    />
  );

  const label = (
    <label
      class="trigger"
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

  return (
    <CustomRevealer
      trigger={label}
      child={slider}
      visible={createComputed(() => brightness.screen != 0)}
    />
  );
}

function Volume() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;
  const volumeIcon = createBinding(speaker, "volumeIcon");
  const volume = createBinding(speaker, "volume");

  const icon = <icon class="trigger" icon={volumeIcon} />;

  const slider = (
    <slider
      // step={0.1} // Gtk.Scale doesn't have step prop directly in JSX usually, handled by adjustment or set_increment
      class="slider"
      widthRequest={100}
      onValueChanged={(self) => (speaker.volume = self.get_value())}
      value={volume((v: number) => (isNaN(v) || v < 0 ? 0 : v > 1 ? 1 : v))}
    />
  );

  return (
    <CustomRevealer
      trigger={icon}
      child={slider}
      on_primary_click={() => {
        execAsync(`pavucontrol`).catch((err) =>
          notify({ summary: "pavu", body: err })
        );
      }}
    />
  );
}

function BatteryWidget() {
  const percentage = createBinding(battery, "percentage");
  const charging = createBinding(battery, "charging");

  // if (battery.percentage <= 0) return <box />;

  const label = (
    <label
      class={createComputed(() => {
        const isCharging = charging.get();
        const value = percentage.get();
        if (isCharging) {
          return "trigger charging";
        } else {
          return value * 100 <= 15 ? "trigger low" : "trigger";
        }
      })}
      label={createComputed(() => {
        const isCharging = charging.get();
        const p = percentage.get() * 100;
        switch (true) {
          case isCharging:
            return "⚡";
          case p > 85:
            return "";
          case p > 75:
            return "";
          case p > 50:
            return "";
          case p > 25:
            return "";
          case p > 10:
            return "";
          case p > 0:
            return "";
          default:
            return "";
        }
      })}
    />
  );

  const info = (
    <label label={percentage((p: number) => `${Math.round(p * 100)}%`)} />
  );

  const levelbar = (
    <levelbar
      widthRequest={100}
      value={percentage((v: number) => (isNaN(v) || v < 0 ? 0 : v > 1 ? 1 : v))}
    />
  );

  const box = (
    <box class={"details"} spacing={5}>
      {info}
      {levelbar}
    </box>
  );

  return (
    <CustomRevealer
      trigger={label}
      child={box}
      custom_class="battery"
      visible={createComputed(() => battery.percentage > 0)}
      revealChild={createComputed(() => {
        const v = percentage.get();
        const isCharging = charging.get();
        return (v < 0.1 && !isCharging) || (v >= 0.95 && isCharging);
      })}
    />
  );
}

// TrayItem component for individual tray items
function TrayItem({ item }: { item: any }) {
  const gicon = createBinding(item, "gicon");
  const tooltipMarkup = createBinding(item, "tooltipMarkup");

  // Create and show menu
  const showMenu = (widget: Gtk.Widget) => {
    const menuModel = item.menuModel;
    const actionGroup = item.actionGroup;

    if (menuModel) {
      const menu = Gtk.Menu.new_from_model(menuModel);
      if (actionGroup) {
        menu.insert_action_group("dbusmenu", actionGroup);
      }
      menu.attach_to_widget(widget, null);
      menu.popup_at_widget(widget, Gdk.Gravity.SOUTH, Gdk.Gravity.NORTH, null);
    }
  };

  return (
    <button
      class="systemtray-button"
      tooltipMarkup={tooltipMarkup}
      onClicked={(self) => {
        // Primary click: activate or show menu
        if (item.isMenu) {
          showMenu(self);
        } else {
          item.activate(0, 0);
        }
      }}
      onButtonPressEvent={(self, event) => {
        const [, button] = event.get_button();
        // Secondary click (right-click): always show menu
        if (button === 3) {
          showMenu(self);
          return true;
        }
        // Middle click: secondary activate
        if (button === 2) {
          item.secondary_activate(0, 0);
          return true;
        }
        return false;
      }}
    >
      <icon gicon={gicon} class="systemtray-icon" />
    </button>
  );
}

function SysTray() {
  const tray = Tray.get_default();
  const items = createBinding(tray, "items");

  return (
    <box class="system-tray">
      <For each={items}>{(item) => <TrayItem item={item} />}</For>
    </box>
  );
}

function PinBar() {
  return (
    <togglebutton
      active={barLock}
      onToggled={({ active }) => {
        setBarLock(active);
      }}
      class="panel-lock icon"
      label={barLock((lock) => (lock ? "" : ""))}
    />
  );
}

function DndToggle() {
  return (
    <togglebutton
      active={DND}
      onToggled={({ active }) => {
        setDND(active);
      }}
      class="dnd-toggle icon"
      label={DND((dnd) => (dnd ? "" : ""))}
    />
  );
}

function BarOrientation() {
  return (
    // <button
    //   onClicked={() => setBarOrientation(!barOrientation.get())}
    //   class="bar-orientation icon"
    //   label={barOrientation((orientation) => (orientation ? "" : ""))}
    // />
    <togglebutton
      active={barOrientation}
      onToggled={({ active }) => {
        setBarOrientation(active);
      }}
      class="bar-orientation icon"
      label={barOrientation((orientation) => (orientation ? "" : ""))}
    />
  );
}

export default ({
  monitorName,
  halign,
}: {
  monitorName: string;
  halign: Gtk.Align;
}) => {
  return (
    <box class="bar-right" spacing={5} halign={halign} hexpand>
      <BatteryWidget />
      {/* <BrightnessWidget /> */}
      <Volume />
      <SysTray />
      <Theme />
      <PinBar />
      <DndToggle />
      <BarOrientation />
    </box>
  );
};
