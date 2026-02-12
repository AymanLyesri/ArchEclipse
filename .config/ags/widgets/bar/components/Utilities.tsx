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
import { createSubprocess, execAsync } from "ags/process";

import Wp from "gi://AstalWp";

import Notifd from "gi://AstalNotifd";
const notifd = Notifd.get_default();

import Gtk from "gi://Gtk?version=4.0";
import {
  globalSettings,
  globalTheme,
  setGlobalSetting,
  setGlobalTheme,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { For } from "ags";
import AstalTray from "gi://AstalTray";
import AstalBattery from "gi://AstalBattery";
import AstalPowerProfiles from "gi://AstalPowerProfiles";
import CircularProgress from "../../CircularProgress";
import { createPoll } from "ags/time";

import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();

function BrightnessWidget() {
  const screen = createBinding(brightness, "screen");
  const slider = (
    <slider
      widthRequest={100}
      class="slider"
      drawValue={false}
      onValueChanged={(self) => (brightness.screen = self.get_value())}
      value={screen.peek()}
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
      tooltipText={screen((v) => `Brightness: ${Math.round(v * 100)}%`)}
      trigger={
        <box class="trigger" spacing={5} children={[label, percentage]} />
      }
      child={slider}
      visible={screen((s) => s != 0)}
    />
  );
}

function Battery() {
  const battery = AstalBattery.get_default();
  const powerprofiles = AstalPowerProfiles.get_default();

  const percent = createBinding(
    battery,
    "percentage",
  )((p) => `${Math.floor(p * 100)}%`);

  const setProfile = (profile: string) => {
    powerprofiles.set_active_profile(profile);
  };

  return (
    <menubutton
      visible={createBinding(battery, "isPresent")}
      tooltipMarkup={createComputed(() => {
        const profile = powerprofiles.active_profile;
        return `Battery: ${percent.peek()} \nProfile: ${profile}`;
      })}>
      <box spacing={5} class="battery">
        <image iconName={createBinding(battery, "iconName")} />
        <label label={percent} />
      </box>
      <popover
        $={(self) => {
          self.connect("notify::visible", () => {
            if (self.visible) self.add_css_class("popover-open");
            else if (self.get_child()) self.remove_css_class("popover-open");
          });
        }}>
        <box orientation={Gtk.Orientation.VERTICAL}>
          {powerprofiles.get_profiles().map(({ profile }) => (
            <button onClicked={() => setProfile(profile)}>
              <label label={profile} xalign={0} />
            </button>
          ))}
        </box>
      </popover>
    </menubutton>
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
      tooltipText={volume(
        (v) => `Volume: ${Math.round(v * 100)}%\nClick to open Volume Mixer`,
      )}
      trigger={
        <box class="trigger" spacing={5} children={[icon, percentage]} />
      }
      child={slider}
      on_primary_click={() => {
        execAsync(`pavucontrol`).catch((err) =>
          notify({ summary: "pavu", body: err }),
        );
      }}
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
              tooltipText={item.tooltip_text}>
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
                tooltipText="More icons">
                <image pixelSize={11} iconName="view-more-symbolic" />
                <popover
                  $={(self) => {
                    self.connect("notify::visible", () => {
                      if (self.visible) self.add_css_class("popover-open");
                      else if (self.get_child())
                        self.remove_css_class("popover-open");
                    });
                  }}>
                  <box
                    class="tray-popover"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={5}>
                    <For each={hiddenItems}>
                      {(item) => (
                        <menubutton
                          class="tray-icon"
                          $={(self) => init(self, item)}
                          tooltipText={item.tooltip_text}>
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

function Theme() {
  return (
    <togglebutton
      active={globalTheme}
      onToggled={({ active }) =>
        globalTheme.peek() !== active && setGlobalTheme(active)
      }
      label={globalTheme((theme) => (theme ? "" : ""))}
      class="theme icon"
      tooltipMarkup={globalTheme((theme) =>
        theme ? `Switch to Dark Theme` : `Switch to Light Theme`,
      )}
    />
  );
}

function PinBar() {
  return (
    <togglebutton
      active={globalSettings(({ bar }) => bar.lock)}
      onToggled={({ active }) => {
        setGlobalSetting("bar.lock", active);
      }}
      class="panel-lock icon"
      label={globalSettings(({ bar }) => (bar.lock ? "" : ""))}
      tooltipMarkup={globalSettings(({ bar }) =>
        bar.lock ? `Unlock Bar` : `Lock Bar`,
      )}
    />
  );
}

function DndToggle() {
  const [hasPing, setHasPing] = createState(false);

  // Listen for new notifications when DND is on
  notifd.connect("notified", () => {
    if (globalSettings.peek().notifications.dnd) {
      setHasPing(true);
      // Reset ping after animation completes
      setTimeout(() => setHasPing(false), 600);
    }
  });

  // Reset ping when DND is turned off
  const dndActive = globalSettings(({ notifications }) => {
    if (!notifications.dnd) {
      setHasPing(false);
    }
    return notifications.dnd;
  });

  return (
    <togglebutton
      active={dndActive}
      onToggled={({ active }) => {
        setGlobalSetting("notifications.dnd", active);
      }}
      // class="dnd-toggle icon"
      class={hasPing((ping) => (ping ? "dnd-toggle active" : "dnd-toggle"))}
      tooltipMarkup={globalSettings(({ notifications }) =>
        notifications.dnd ? "Disable Do Not Disturb" : "Enable Do Not Disturb",
      )}>
      <label
        label={globalSettings(({ notifications }) =>
          notifications.dnd ? "" : "",
        )}></label>
    </togglebutton>
  );
}

function ResourceMonitor() {
  const systemResource = createSubprocess(
    [0, 0, 0],
    "./assets/binaries/system-resources-loop-ags",
    (out) => {
      try {
        return JSON.parse(out);
      } catch (e) {
        return [0, 0, 0];
      }
    },
  );
  return (
    <box class="resource-monitor">
      <Gtk.GestureClick
        onPressed={() => {
          hyprland.dispatch("workspace", "5");
        }}
      />
      <With value={systemResource}>
        {(res) => (
          <box spacing={10}>
            <CircularProgress
              visible={res[0] != 0}
              tooltipText={`CPU Usage ${res[0]}%`}
              value={res[0] / 100}
              className="cpu-monitor"
            />
            <CircularProgress
              visible={res[1] != 0}
              tooltipText={`RAM Usage ${res[1]}%`}
              value={res[1] / 100}
              className="ram-monitor"
            />
            <CircularProgress
              visible={res[2] != 0}
              tooltipText={`GPU Usage ${res[2]}%`}
              value={res[2] / 100}
              className="gpu-monitor"
            />
          </box>
        )}
      </With>
    </box>
  );
}

export default ({ halign }: { halign?: Gtk.Align | Accessor<Gtk.Align> }) => {
  return (
    <box class="utilities" spacing={5} halign={halign} hexpand>
      <Battery />
      <BrightnessWidget />
      <Volume />
      <Tray />
      <ResourceMonitor />
      <Theme />
      <PinBar />
      <DndToggle />
    </box>
  );
};
