import Brightness from "../../../services/brightness";
const brightness = Brightness.get_default();
import CustomRevealer from "../../CustomRevealer";
import {
  Accessor,
  createBinding,
  createComputed,
  createState,
  With,
} from "ags";
import { execAsync } from "ags/process";

import Wp from "gi://AstalWp";

import Battery from "gi://AstalBattery";
const battery = Battery.get_default();

import Notifd from "gi://AstalNotifd";
const notifd = Notifd.get_default();

import Gtk from "gi://Gtk?version=4.0";
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
import AstalTray from "gi://AstalTray";

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
  return (
    <CustomRevealer
      trigger={
        <box class="trigger" spacing={5} children={[label, percentage]} />
      }
      child={slider}
      visible={screen((s) => s != 0)}
    />
  );
}

function Volume() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;
  const volumeIcon = createBinding(speaker, "volumeIcon");
  const volume = createBinding(speaker, "volume");

  const icon = <image pixelSize={11} iconName={volumeIcon} />;

  const slider = (
    <slider
      // step={0.1} // Gtk.Scale doesn't have step prop directly in JSX usually, handled by adjustment or set_increment
      class="slider"
      widthRequest={100}
      onValueChanged={(self) => (speaker.volume = self.get_value())}
      value={volume((v: number) => (isNaN(v) || v < 0 ? 0 : v > 1 ? 1 : v))}
    />
  );

  const percentage = (
    <label label={volume((v: number) => `${Math.round(v * 100)}%`)} />
  );

  return (
    <CustomRevealer
      trigger={
        <box class="trigger" spacing={5} children={[icon, percentage]} />
      }
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
  const _percentage = createBinding(battery, "percentage");
  const charging = createBinding(battery, "charging");

  const label = (
    <label
      label={createComputed(() => {
        const isCharging = charging.get();
        const p = _percentage.get() * 100;
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

  const percentage = (
    <label label={_percentage((p: number) => `${Math.round(p * 100)}%`)} />
  );

  const levelbar = (
    <levelbar
      widthRequest={100}
      value={_percentage((v: number) =>
        isNaN(v) || v < 0 ? 0 : v > 1 ? 1 : v
      )}
    />
  );

  const box = (
    <box class={"details"} spacing={5}>
      {levelbar}
    </box>
  );

  return (
    <CustomRevealer
      trigger={
        <box class="trigger" spacing={5} children={[label, percentage]} />
      }
      child={box}
      custom_class={createComputed([charging, _percentage], (c, p) => {
        const isCharging = c;
        const value = p * 100;
        if (isCharging) {
          return "battery charging";
        } else {
          return value <= 15 ? "battery low" : "battery";
        }
      })}
      visible={createComputed(() => battery.percentage > 0)}
      revealChild={_percentage((v) => {
        const isCharging = charging.get();
        return (v < 0.1 && !isCharging) || (v >= 0.95 && isCharging);
      })}
    />
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
              $={(self) => init(self, item)}
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
                <popover>
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
  const [hasPing, setHasPing] = createState(false);

  // Listen for new notifications when DND is on
  notifd.connect("notified", () => {
    if (DND.get()) {
      print("New notification while DND is on");
      setHasPing(true);
      // Reset ping after animation completes
      setTimeout(() => setHasPing(false), 600);
    }
  });

  // Reset ping when DND is turned off
  const dndActive = DND((dnd) => {
    if (!dnd) {
      setHasPing(false);
    }
    return dnd;
  });

  return (
    <togglebutton
      active={dndActive}
      onToggled={({ active }) => {
        setDND(active);
      }}
      // class="dnd-toggle icon"
      class={hasPing((ping) => (ping ? "dnd-toggle active" : "dnd-toggle"))}
    >
      <label label={DND((dnd) => (dnd ? "" : ""))}></label>
    </togglebutton>
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
      <Tray />
      <Theme />
      <PinBar />
      <DndToggle />
    </box>
  );
};
