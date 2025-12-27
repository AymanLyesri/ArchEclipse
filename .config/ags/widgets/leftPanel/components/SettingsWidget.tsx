import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Hyprland from "gi://AstalHyprland";
import {
  autoWorkspaceSwitching,
  setAutoWorkspaceSwitching,
  barLayout,
  setBarLayout,
  globalFontSize,
  setGlobalFontSize,
  globalIconSize,
  setGlobalIconSize,
  globalMargin,
  globalOpacity,
  setGlobalOpacity,
  globalScale,
  setGlobalScale,
  globalSettings,
  setGlobalSettings,
  leftPanelWidth,
} from "../../../variables";
import { createBinding, createState, createComputed, Accessor } from "ags";
import { execAsync } from "ags/process";
import { getSetting, setSetting } from "../../../utils/settings";
import { notify } from "../../../utils/notification";
import {
  AGSSetting,
  HyprlandSetting,
} from "../../../interfaces/settings.interface";
import { hideWindow } from "../../../utils/window";
import { barWidgetSelectors } from "../../../constants/widget.constants";
import { defaultSettings } from "../../../constants/settings.constants";
const hyprland = Hyprland.get_default();

const hyprCustomDir: string = "$HOME/.config/hypr/configs/custom";

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

const resetButton = () => {
  const resetSettings = () => {
    //hyprland settings
    setSetting(
      "hyprland",
      defaultSettings.hyprland,
      globalSettings,
      setGlobalSettings
    );
    // ags settings
    setGlobalOpacity(defaultSettings.globalOpacity);
    setGlobalIconSize(defaultSettings.globalIconSize);
    setGlobalScale(defaultSettings.globalScale);
    setGlobalFontSize(defaultSettings.globalFontSize);
    setAutoWorkspaceSwitching(defaultSettings.autoWorkspaceSwitching);
    setBarLayout(defaultSettings.bar.layout);
  };
  return (
    <button
      class="reset-button"
      label="Reset to Default"
      halign={Gtk.Align.END}
      onClicked={() => {
        resetSettings();
      }}
    />
  );
};

const BarLayoutSetting = () => {
  return (
    <box spacing={5} orientation={Gtk.Orientation.VERTICAL}>
      <label
        class={"subcategory-label"}
        label={"bar Layout"}
        halign={Gtk.Align.START}
      />
      <box class="setting" spacing={10} hexpand>
        {barWidgetSelectors.map((widget) => {
          return (
            <togglebutton
              hexpand
              active={barLayout((layout) =>
                layout.some((w) => w.name === widget.name)
              )}
              class="widget"
              label={widget.name}
              onToggled={({ active }) => {
                if (active) {
                  if (barLayout.peek().length >= 3) return;
                  setBarLayout([...barLayout.peek(), widget]);
                } else {
                  const newWidgets = barLayout
                    .peek()
                    .filter((w) => w.name !== widget.name);
                  setBarLayout(newWidgets);
                  console.table(newWidgets);
                }
              }}
            ></togglebutton>
          );
        })}
      </box>
    </box>
  );
};

const Setting = (get: Accessor<AGSSetting>, set: any) => {
  const title = <label halign={Gtk.Align.START} label={get.peek().name} />;

  const sliderWidget = () => {
    const infoLabel = (
      <label
        hexpand={true}
        xalign={1}
        label={get(
          (object) =>
            `${Math.round(
              ((object.value - object.min) / (object.max - object.min)) * 100
            )}%`
        )}
      />
    ) as Gtk.Label;

    const Slider = (
      <slider
        widthRequest={leftPanelWidth((width) => width / 2)}
        class="slider"
        drawValue={false}
        min={get.peek().min}
        max={get.peek().max}
        value={get((setting) => setting.value)}
        onValueChanged={(self) => {
          let value = self.get_value();
          infoLabel.label = `${Math.round(
            ((value - get.peek().min) / (get.peek().max - get.peek().min)) * 100
          )}%`;
          switch (get.peek().type) {
            case "int":
              value = Math.round(value);
              break;
            case "float":
              value = parseFloat(value.toFixed(2));
              break;
            default:
              break;
          }

          set({
            name: get.peek().name,
            value: normalizeValue(value, get.peek().type),
            type: get.peek().type,
            min: get.peek().min,
            max: get.peek().max,
          });
        }}
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
        label={get((object) => (object.value ? "On" : "Off"))}
      />
    );

    const Switch = (
      <switch
        active={createComputed(() => get.peek().value)}
        onNotifyActive={(self) => {
          const active = self.active;
          set({
            name: get.peek().name,
            value: active,
            type: get.peek().type,
            min: get.peek().min,
            max: get.peek().max,
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
    <box class="setting" hexpand={true} spacing={5}>
      {title}
      {get.peek().type === "bool" ? switchWidget() : sliderWidget()}
    </box>
  );
};

interface NestedSettings {
  [key: string]: HyprlandSetting | NestedSettings;
}

const createCategory = (key: string, value: NestedSettings) => {
  const settings: any[] = [];
  Object.entries(value).forEach(([childKey, childValue]) => {
    if (typeof childValue === "object" && childValue !== null) {
      const firstKey = Object.keys(childValue)[0];
      if (
        firstKey &&
        typeof (childValue as NestedSettings)[firstKey] === "object" &&
        (childValue as NestedSettings)[firstKey] !== null
      ) {
        // nested category
        settings.push(
          createCategory(`${key}.${childKey}`, childValue as NestedSettings)
        );
      } else {
        // setting
        const keys = `hyprland.${key}.${childKey}`;
        const keyArray = keys.split(".");
        const lastKey = keyArray.at(-1);
        if (!lastKey) return;
        const setting = childValue as HyprlandSetting;
        const get = createComputed(() => ({
          name: lastKey.charAt(0).toUpperCase() + lastKey.slice(1),
          value: getSetting(keys + ".value", globalSettings.peek()),
          type: setting.type,
          min: setting.min,
          max: setting.max,
        }));
        const set = (newSetting: AGSSetting) => {
          setSetting(
            keys + ".value",
            newSetting.value,
            globalSettings,
            setGlobalSettings
          );
          const configString = buildConfigString(
            keyArray.slice(1),
            newSetting.value
          );
          const hyprKey = keyArray.slice(1).join(":");
          execAsync(
            `bash -c "echo -e '${configString}' >${
              hyprCustomDir + "/" + keyArray.at(-2) + "." + keyArray.at(-1)
            }.conf && hyprctl keyword ${hyprKey} ${newSetting.value}"`
          ).catch((err) => notify(err));
        };
        settings.push(Setting(get, set));
      }
    }
  });
  return (
    <box class={"category"} orientation={Gtk.Orientation.VERTICAL} spacing={16}>
      <label
        label={key.charAt(0).toUpperCase() + key.slice(1)}
        halign={Gtk.Align.START}
      />
      {settings}
    </box>
  );
};

export default () => {
  const hyprlandCategories = Object.entries(globalSettings.peek().hyprland).map(
    ([key, value]) => createCategory(key, value as NestedSettings)
  );

  return (
    <scrolledwindow vexpand>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={16} class="settings">
        <box
          class={"category"}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={16}
        >
          <label label="AGS" halign={Gtk.Align.START} />
          {BarLayoutSetting()}
          {Setting(globalOpacity, setGlobalOpacity)}
          {Setting(globalIconSize, setGlobalIconSize)}
          {Setting(globalScale, setGlobalScale)}
          {Setting(globalFontSize, setGlobalFontSize)}
        </box>
        {hyprlandCategories}
        <box
          class={"category"}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={16}
        >
          <label label="Custom" halign={Gtk.Align.START} />
          {Setting(autoWorkspaceSwitching, setAutoWorkspaceSwitching)}
        </box>
        {resetButton()}
      </box>
    </scrolledwindow>
  );
};
