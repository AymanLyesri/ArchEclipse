import { App, Astal, Gdk, Gtk, Widget } from "astal/gtk3";
import hyprland from "gi://AstalHyprland";
import {
  autoWorkspaceSwitching,
  barLayout,
  globalFontSize,
  globalIconSize,
  globalMargin,
  globalOpacity,
  globalScale,
  globalSettings,
} from "../variables";
import { bind, execAsync, Variable } from "astal";
import { getSetting, setSetting } from "../utils/settings";
import { notify } from "../utils/notification";
import { AGSSetting, HyprlandSetting } from "../interfaces/settings.interface";
import { hideWindow } from "../utils/window";
import { getMonitorName } from "../utils/monitor";
import ToggleButton from "./toggleButton";
import { barWidgetSelectors } from "../constants/widget.constants";
const Hyprland = hyprland.get_default();

const hyprCustomDir: string = "$HOME/.config/hypr/configs/custom/";

function buildConfigString(keys: string[], value: any): string {
  if (keys.length === 1) return `${keys[0]}=${value}`;

  const currentKey = keys[0];
  const nestedConfig = buildConfigString(keys.slice(1), value);
  return `${currentKey} {\n\t${nestedConfig.replace(/\n/g, "\n\t")}\n}`;
}

const normalizeValue = (value: any, type: string) => {
  switch (type) {
    case "int":
      return Math.round(value);
    case "float":
      return parseFloat(value.toFixed(2));
    default:
      return value;
  }
};

const setBarLayout = () => {
  return (
    <box spacing={5} vertical>
      <label
        className={"subcategory-label"}
        label={"bar Layout"}
        halign={Gtk.Align.START}
      />
      <box className="setting" spacing={10} hexpand>
        {barWidgetSelectors.map((widget) => {
          return (
            <ToggleButton
              hexpand
              state={barLayout.get().some((w) => w.name === widget.name)}
              className="widget"
              label={widget.name}
              onToggled={(self, on) => {
                if (on) {
                  if (barLayout.get().length >= 3) return;
                  barLayout.set([...barLayout.get(), widget]);
                } else {
                  const newWidgets = barLayout
                    .get()
                    .filter((w) => w.name !== widget.name);
                  barLayout.set(newWidgets);
                }
              }}
            ></ToggleButton>
          );
        })}
      </box>
    </box>
  );
};

const agsSetting = (setting: Variable<AGSSetting>) => {
  const title = <label halign={Gtk.Align.START} label={setting.get().name} />;

  const sliderWidget = () => {
    const infoLabel = (
      <label
        hexpand={true}
        xalign={1}
        label={bind(setting).as(
          (setting) =>
            `${Math.round(
              ((setting.value - setting.min) / (setting.max - setting.min)) *
                100
            )}%`
        )}
      />
    );

    const Slider = (
      <slider
        halign={Gtk.Align.END}
        step={1}
        width_request={169}
        className="slider"
        min={setting.get().min}
        max={setting.get().max}
        value={setting.get().value}
        onValueChanged={({ value }) =>
          setting.set({
            name: setting.get().name,
            value: normalizeValue(value, setting.get().type),
            type: setting.get().type,
            min: setting.get().min,
            max: setting.get().max,
          })
        }
      />
    );

    return (
      <box hexpand={true} halign={Gtk.Align.END} spacing={5}>
        {Slider}
        {infoLabel}
      </box>
    );
  };

  const switchWidget = () => {
    const infoLabel = (
      <label
        hexpand={true}
        xalign={1}
        label={bind(setting).as((setting) => (setting.value ? "On" : "Off"))}
      />
    );

    const Switch = (
      <switch
        active={setting.get().value}
        onButtonPressEvent={({ active }) => {
          active = !active;
          setting.set({
            name: setting.get().name,
            value: active,
            type: setting.get().type,
            min: setting.get().min,
            max: setting.get().max,
          });
        }}
      />
    );

    return (
      <box hexpand={true} halign={Gtk.Align.END} spacing={5}>
        {Switch}
        {infoLabel}
      </box>
    );
  };

  return (
    <box className="setting" hexpand={true} spacing={5}>
      {title}
      {setting.get().type === "bool" ? switchWidget() : sliderWidget()}
    </box>
  );
};

const hyprlandSetting = (keys: string, setting: HyprlandSetting) => {
  const keyArray = keys.split(".");
  const lastKey = keyArray.at(-1);
  if (!lastKey) return;

  const title = (
    <label
      halign={Gtk.Align.START}
      label={lastKey.charAt(0).toUpperCase() + lastKey.slice(1)}
    />
  );

  const sliderWidget = () => {
    const infoLabel = (
      <label
        hexpand={true}
        xalign={1}
        label={`${Math.round(
          (setting.value / (setting.max - setting.min)) * 100
        )}%`}
      />
    );

    const setValue = ({ value }: { value: number }) => {
      infoLabel.label = `${Math.round(value * 100)}%`;
      switch (setting.type) {
        case "int":
          value = Math.round(value * (setting.max - setting.min));
          break;
        case "float":
          value = parseFloat(value.toFixed(2)) * (setting.max - setting.min);
          break;
        default:
          break;
      }

      setSetting(keys + ".value", value);
      const configString = buildConfigString(keyArray.slice(1), value);
      execAsync(
        `bash -c "echo -e '${configString}' >${
          hyprCustomDir + keyArray.at(-2) + "." + keyArray.at(-1)
        }.conf"`
      ).catch((err) => notify(err));
    };

    const Slider = (
      <slider
        halign={Gtk.Align.END}
        step={0.01}
        width_request={169}
        className="slider"
        value={bind(globalSettings).as(
          (s) => getSetting(keys + ".value") / (setting.max - setting.min)
        )}
        onValueChanged={setValue}
      />
    );

    return (
      <box hexpand={true} halign={Gtk.Align.END} spacing={5}>
        {Slider}
        {infoLabel}
      </box>
    );
  };

  const switchWidget = () => {
    const infoLabel = (
      <label
        hexpand={true}
        xalign={1}
        label={bind(globalSettings).as((s) =>
          getSetting(keys + ".value") ? "On" : "Off"
        )}
      />
    );

    const Switch = (
      <switch
        active={getSetting(keys + ".value")}
        onButtonPressEvent={({ active }) => {
          active = !active;
          setSetting(keys + ".value", active);
          const configString = buildConfigString(keyArray.slice(1), active);
          execAsync(
            `bash -c "echo -e '${configString}' >${
              hyprCustomDir + keyArray.at(-2) + "." + keyArray.at(-1)
            }.conf"`
          ).catch((err) => notify(err));
        }}
      />
    );

    return (
      <box hexpand={true} halign={Gtk.Align.END} spacing={5}>
        {Switch}
        {infoLabel}
      </box>
    );
  };

  return (
    <box className="setting">
      {title}
      {setting.type === "bool" ? switchWidget() : sliderWidget()}
    </box>
  );
};

interface NestedSettings {
  [key: string]: HyprlandSetting | NestedSettings;
}

const Settings = () => {
  const hyprlandSettings: any = [];

  const Category = (title: string) => (
    <label
      className={"subcategory-label"}
      label={title}
      halign={Gtk.Align.START}
    />
  );

  const processSetting = (
    key: string,
    value: NestedSettings | HyprlandSetting
  ) => {
    if (typeof value === "object" && value !== null) {
      // Add a category label for the current key
      hyprlandSettings.push(Category(key));

      // Iterate over the entries of the current value
      Object.entries(value).forEach(([childKey, childValue]) => {
        if (typeof childValue === "object" && childValue !== null) {
          const firstKey = Object.keys(childValue)[0];

          // Check if the childValue has nested settings
          if (
            firstKey &&
            typeof childValue[firstKey] === "object" &&
            childValue[firstKey] !== null
          ) {
            // Recursively process nested settings
            processSetting(`${key}.${childKey}`, childValue as NestedSettings);
          } else {
            // If no nested settings, treat it as a HyprlandSetting
            hyprlandSettings.push(
              hyprlandSetting(
                `hyprland.${key}.${childKey}`,
                childValue as HyprlandSetting
              )
            );
          }
        }
      });
    }
  };

  Object.entries(globalSettings.get().hyprland).forEach(([key, value]) => {
    processSetting(key, value);
  });

  return (
    <scrollable
      heightRequest={500}
      child={
        <box vertical={true} spacing={10} className="settings">
          <box className={"category"} vertical={true} spacing={5}>
            <label label="AGS" halign={Gtk.Align.START} />
            {setBarLayout()}
            {agsSetting(globalOpacity)}
            {agsSetting(globalIconSize)}
            {agsSetting(globalScale)}
            {agsSetting(globalFontSize)}
          </box>
          <box className={"category"} vertical={true} spacing={5}>
            <label label="Hyprland" halign={Gtk.Align.START} />
            {hyprlandSettings}
          </box>
          <box className={"category"} vertical={true} spacing={5}>
            <label label="Custom" halign={Gtk.Align.START} />
            {agsSetting(autoWorkspaceSwitching)}
          </box>
        </box>
      }
    />
  );
};

const WindowActions = ({ monitor }: { monitor: string }) => (
  <box hexpand={true} className="window-actions">
    <box
      hexpand={true}
      halign={Gtk.Align.START}
      child={
        <button
          halign={Gtk.Align.END}
          label=""
          onClicked={() => {
            hideWindow(`settings-${monitor}`);
          }}
        />
      }
    ></box>
    <button label="󰑐" onClicked={() => execAsync(`bash -c "hyprctl reload"`)} />
  </box>
);

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;
  return (
    <window
      gdkmonitor={monitor}
      name={`settings-${monitorName}`}
      namespace="settings"
      application={App}
      className=""
      anchor={Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.LEFT}
      visible={false}
      margin={globalMargin}
      keymode={Astal.Keymode.ON_DEMAND}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          hideWindow(`settings-${monitorName}`);
          return true;
        }
      }}
      child={
        <box vertical={true} className="settings-widget">
          <WindowActions monitor={monitorName} />
          <Settings />
        </box>
      }
    ></window>
  );
};
