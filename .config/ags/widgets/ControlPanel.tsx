import app from "ags/gtk4/app";
import {
  globalSettings,
  globalTheme,
  setGlobalSetting,
  setGlobalTheme,
} from "../variables";
import { Accessor, createBinding, createState } from "ags";

import Notifd from "gi://AstalNotifd";
import { Gtk } from "ags/gtk4";
const notifd = Notifd.get_default();

import Wp from "gi://AstalWp";
import brightness from "../services/brightness";
import Brightness from "../services/brightness";

function CustomSlider(props: {
  value: Accessor<number>;
  onChange: (val: number) => void;
  iconWidget: Gtk.Widget;
  visible?: Accessor<boolean> | boolean;
}) {
  return (
    <box
      class="control-panel-slider"
      spacing={5}
      visible={props.visible ?? true}
    >
      {props.iconWidget}
      <slider
        class="slider"
        onValueChanged={(self) => props.onChange(self.get_value())}
        value={props.value}
        hexpand
      />
    </box>
  );
}

function Volume() {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;
  const volumeIcon = createBinding(speaker, "volumeIcon");
  const volume = createBinding(speaker, "volume");

  const icon = (
    <image class={"icon"} pixelSize={15} iconName={volumeIcon} />
  ) as Gtk.Widget;

  const slider = (
    <CustomSlider
      iconWidget={icon}
      value={volume((v: number) => (isNaN(v) || v < 0 ? 0 : v > 1 ? 1 : v))}
      onChange={(val: number) => (speaker.volume = val)}
    />
  );
  return slider;
}

function BrightnessWidget() {
  const brightness = Brightness.get_default();
  const screen = createBinding(brightness, "screen");

  const icon = (
    <label
      class={"icon"}
      css={"font-size: 15px;"}
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
  ) as Gtk.Widget;

  return (
    <CustomSlider
      iconWidget={icon}
      value={screen((v: number) => (isNaN(v) || v < 0 ? 0 : v > 1 ? 1 : v))}
      onChange={(val: number) => (brightness.screen = val)}
      visible={createBinding(brightness, "hasBacklight")}
    />
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
  let pingTimeout: ReturnType<typeof setTimeout> | null = null;

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
      $={(self) => {
        const handlerId = notifd.connect("notified", () => {
          if (globalSettings.peek().notifications.dnd) {
            setHasPing(true);

            if (pingTimeout) clearTimeout(pingTimeout);
            pingTimeout = setTimeout(() => setHasPing(false), 600);
          }
        });

        self.connect("destroy", () => {
          notifd.disconnect(handlerId);
          if (pingTimeout) clearTimeout(pingTimeout);
        });
      }}
      // class="dnd-toggle icon"
      class={hasPing((ping) => (ping ? "dnd-toggle active" : "dnd-toggle"))}
      tooltipMarkup={globalSettings(({ notifications }) =>
        notifications.dnd ? "Disable Do Not Disturb" : "Enable Do Not Disturb",
      )}
    >
      <label
        label={globalSettings(({ notifications }) =>
          notifications.dnd ? "" : "",
        )}
      ></label>
    </togglebutton>
  );
}

function WallpaperSwitcher() {
  return (
    <button
      class="wallpaper-switcher"
      label="󰸉"
      onClicked={(self) => {
        const window = app.get_window(
          `wallpaper-switcher-${(self.get_root() as any).monitorName}`,
        );
        if (window)
          window.is_visible()
            ? (window.visible = false)
            : (window.visible = true);
      }}
      tooltipMarkup={`Wallpaper Switcher\n<b>SUPER + W</b>`}
    />
  );
}

function AppLauncher() {
  return (
    <button
      // class="app-launcher"
      label=""
      onClicked={(self) => {
        const window = app.get_window(
          `app-launcher-${(self.get_root() as any).monitorName}`,
        );
        if (window)
          window.is_visible()
            ? (window.visible = false)
            : (window.visible = true);
      }}
      tooltipMarkup={`App Launcher\n<b>SUPER</b>`}
    />
  );
}

function UserPanel() {
  return (
    <button
      class="user-panel"
      label=""
      onClicked={(self) => {
        const window = app.get_window(
          `user-panel-${(self.get_root() as any).monitorName}`,
        );
        if (window)
          window.is_visible()
            ? (window.visible = false)
            : (window.visible = true);
      }}
      tooltipMarkup={`User Panel\n<b>SUPER + ESC</b>`}
    />
  );
}

export default () => {
  return (
    <box
      class="control-panel"
      spacing={15}
      orientation={Gtk.Orientation.VERTICAL}
    >
      <box class="sliders" spacing={10} orientation={Gtk.Orientation.VERTICAL}>
        <Volume />
        <BrightnessWidget />
      </box>
      <box spacing={5} halign={Gtk.Align.CENTER}>
        <Theme />
        <PinBar />
        <DndToggle />
        <UserPanel />
        <AppLauncher />
        <WallpaperSwitcher />
      </box>
    </box>
  );
};
