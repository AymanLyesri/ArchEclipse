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
import {
  barLock,
  setBarLock,
  barOrientation,
  setBarOrientation,
  DND,
  setDND,
  globalTheme,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { switchGlobalTheme } from "../../../utils/theme";

function Theme() {
  return (
    <togglebutton
      onToggled={(self: any, on: boolean) => switchGlobalTheme()}
      label={createComputed(() => (globalTheme() ? "" : ""))}
      class="theme icon"
    />
  );
}

function BrightnessWidget() {
  const screen = createBinding(brightness, "screen");
  const slider = (
    <scale
      widthRequest={100}
      class="slider"
      drawValue={false}
      onValueChanged={(self) => (brightness.screen = self.get_value())}
      value={createComputed(() => screen())}
    />
  );

  const label = (
    <label
      class="trigger"
      label={createComputed(() => {
        const v = screen();
        // `${Math.round(v * 100)}%`; // This line does nothing
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

  const icon = (
    <icon class="trigger" icon={createComputed(() => volumeIcon())} />
  );

  const slider = (
    <scale
      // step={0.1} // Gtk.Scale doesn't have step prop directly in JSX usually, handled by adjustment or set_increment
      class="slider"
      widthRequest={100}
      onValueChanged={(self) => (speaker.volume = self.get_value())}
      value={createComputed(() => volume())}
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
        const isCharging = charging();
        const value = percentage();
        if (isCharging) {
          return "trigger charging";
        } else {
          return value * 100 <= 15 ? "trigger low" : "trigger";
        }
      })}
      label={createComputed(() => {
        const isCharging = charging();
        const p = percentage() * 100;
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
    <label label={createComputed(() => `${Math.round(percentage() * 100)}%`)} />
  );

  const levelbar = (
    <levelbar widthRequest={100} value={createComputed(() => percentage())} />
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
        const v = percentage();
        const isCharging = charging();
        return (v < 0.1 && !isCharging) || (v >= 0.95 && isCharging);
      })}
    />
  );
}

function SysTray() {
  const tray = Tray.get_default();
  const itemsBinding = createBinding(tray, "items");

  const items = createComputed(() =>
    itemsBinding().map((item) => {
      const tooltipMarkup = createBinding(item, "tooltipMarkup");
      const actionGroup = createBinding(item, "actionGroup");
      const menuModel = createBinding(item, "menuModel");
      const gicon = createBinding(item, "gicon");

      return (
        <menubutton
          margin={0}
          // cursor="pointer" // Gtk widgets don't have cursor prop
          usePopover={false}
          tooltipMarkup={createComputed(() => tooltipMarkup())}
          actionGroup={createComputed(() => ["dbusmenu", actionGroup()])}
          menuModel={createComputed(() => menuModel())}
          child={
            <icon
              gicon={createComputed(() => gicon())}
              class="systemtray-icon"
            />
          }
        />
      );
    })
  );

  return <box class="system-tray">{items}</box>;
}

function PinBar() {
  return (
    <togglebutton
      active={barLock}
      onToggled={(self: any, on: boolean) => {
        setBarLock(on);
        self.label = on ? "" : "";
      }}
      class="panel-lock icon"
      label={createComputed(() => (barLock() ? "" : ""))}
    />
  );
}

function DndToggle() {
  return togglebutton({
    state: DND,
    onToggled: (self: any, on: boolean) => {
      setDND(on);
      self.label = DND ? "" : "";
    },
    className: "dnd-toggle icon",
    label: createComputed(() => (DND ? "" : "")),
  });
}

function BarOrientation() {
  return (
    <button
      onClicked={() => setBarOrientation(!barOrientation())}
      class="bar-orientation icon"
      label={createComputed(() => (barOrientation() ? "" : ""))}
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
      <BrightnessWidget />
      <Volume />
      <SysTray />
      <Theme />
      <PinBar />
      <DndToggle />
      <BarOrientation />
    </box>
  );
};
