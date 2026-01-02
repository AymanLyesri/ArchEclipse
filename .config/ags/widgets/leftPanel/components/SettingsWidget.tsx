import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Hyprland from "gi://AstalHyprland";
import GObject from "ags/gobject";
import { createBinding, createState, createComputed, Accessor, For } from "ags";
import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import { AGSSetting } from "../../../interfaces/settings.interface";
import { hideWindow } from "../../../utils/window";
import { barWidgetSelectors } from "../../../constants/widget.constants";
import { defaultSettings } from "../../../constants/settings.constants";
import {
  globalSettings,
  setGlobalSetting,
  setGlobalSettings,
} from "../../../variables";
import { WidgetSelector } from "../../../interfaces/widgetSelector.interface";
import { refreshCss } from "../../../utils/scss";
const hyprland = Hyprland.get_default();

const hyprCustomDir: string = "$HOME/.config/hypr/configs/custom";

function moveItem<T>(array: T[], from: number, to: number): T[] {
  const copy = [...array];
  const [item] = copy.splice(from, 1);
  copy.splice(to, 0, item);
  return copy;
}
// const applyHyprlandSettings = (
//   settings: NestedSettings,
//   prefix: string = ""
// ) => {
//   Object.entries(settings).forEach(([key, value]) => {
//     const fullKey = prefix ? `${prefix}.${key}` : key;
//     if (typeof value === "object" && value !== null && !("type" in value)) {
//       // nested
//       applyHyprlandSettings(value as NestedSettings, fullKey);
//     } else {
//       // leaf setting
//       const setting = value as AGSSetting;
//       const keyArray = fullKey.split(".");
//       const configString = buildConfigString(keyArray, setting.value);
//       const hyprKey = keyArray.join(":");
//       execAsync(
//         `bash -c "echo -e '${configString}' >${
//           hyprCustomDir + "/" + keyArray.at(-2) + "." + keyArray.at(-1)
//         }.conf && hyprctl keyword ${hyprKey} ${setting.value}"`
//       ).catch((err) => notify(err));
//     }
//   });
// };

// const applyHyprlandSettings = (settings: NestedSettings) => {
//   Object.entries(settings).forEach(([key, value]) => {
//     if (typeof value === "object" && value !== null && !("type" in value)) {
//       // nested
//       applyHyprlandSettings(value as NestedSettings);
//     } else {
//       // leaf setting

//       const key = fullKey.replace(/\./g, ":");
//       const setting = value as AGSSetting;
//       const fullKey = key;
//       applyHyprlandSetting(key, setting.value);
//     }
//   });
// };

const resetButton = () => {
  const resetSettings = () => {
    //hyprland settings
    const newSettings = { ...globalSettings.peek() };
    newSettings.hyprland = defaultSettings.hyprland;
    setGlobalSettings(newSettings);

    // ags settings
    // setGlobalOpacity(defaultSettings.globalOpacity);
    // setGlobalScale(defaultSettings.globalScale);
    // setGlobalFontSize(defaultSettings.globalFontSize);
    // setAutoWorkspaceSwitching(defaultSettings.autoWorkspaceSwitching);
    // setBarLayout(defaultSettings.bar.layout);
    // setBarOrientation(defaultSettings.bar.orientation);
    setGlobalSetting("ui.opacity", defaultSettings.ui.opacity);
    setGlobalSetting("ui.scale", defaultSettings.ui.scale);
    setGlobalSetting("ui.fontSize", defaultSettings.ui.fontSize);
    setGlobalSetting(
      "autoWorkspaceSwitching",
      defaultSettings.autoWorkspaceSwitching
    );
    setGlobalSetting("bar.layout", defaultSettings.bar.layout);
    setGlobalSetting("bar.orientation", defaultSettings.bar.orientation);
    // apply hyprland settings
    // applyHyprlandSettings(defaultSettings.hyprland);
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
        <For each={globalSettings(({ bar }) => bar.layout)}>
          {(widget: WidgetSelector) => {
            return (
              <togglebutton
                hexpand
                active={widget.enabled}
                class="widget drag"
                label={widget.name}
                tooltipMarkup={`<b>Hold To Drag</b>\n${widget.name}`}
                onToggled={({ active }) => {
                  if (active) {
                    // Enable the widget
                    setGlobalSetting(
                      "bar.layout",
                      globalSettings
                        .peek()
                        .bar.layout.map((w) =>
                          w.name === widget.name ? { ...w, enabled: true } : w
                        )
                    );
                  } else {
                    // Disable the widget
                    setGlobalSetting(
                      "bar.layout",
                      globalSettings
                        .peek()
                        .bar.layout.map((w) =>
                          w.name === widget.name ? { ...w, enabled: false } : w
                        )
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
                  });

                  dragSource.connect("prepare", () => {
                    print("DRAG SOURCE PREPARE");
                    const index = globalSettings
                      .peek()
                      .bar.layout.findIndex((w) => w.name === widget.name);

                    const value = new GObject.Value();
                    value.init(GObject.TYPE_INT);
                    value.set_int(index);

                    return Gdk.ContentProvider.new_for_value(value);
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

                    const widgets = globalSettings.peek().bar.layout;
                    const toIndex = widgets.findIndex(
                      (w) => w.name === widget.name
                    );

                    if (fromIndex === -1) {
                      // Enabling by dragging
                      if (widgets.length >= 3) return true;
                      const newLayout = [...widgets];
                      newLayout.splice(
                        toIndex === -1 ? widgets.length : toIndex,
                        0,
                        widget
                      );
                      setGlobalSetting("bar.layout", newLayout);
                      return true;
                    } else {
                      // Reordering
                      if (toIndex === -1 || fromIndex === toIndex) return true;
                      setGlobalSetting(
                        "bar.layout",
                        moveItem(widgets, fromIndex, toIndex)
                      );
                      return true;
                    }
                  });

                  self.add_controller(dropTarget);
                }}
              ></togglebutton>
            );
          }}
        </For>
      </box>
    </box>
  );
};
const Setting = (
  keyChanged: string,
  setting: AGSSetting,
  callBack?: (newValue?: any) => void
) => {
  const title = <label halign={Gtk.Align.START} label={setting.name} />;

  const SliderWidget = () => {
    const infoLabel = (
      <label
        hexpand={true}
        label={String(
          setting.type === "int"
            ? Math.round(setting.value ?? 0)
            : (setting.value ?? 0).toFixed(2)
        )}
      />
    ) as Gtk.Label;

    const Slider = (
      <slider
        widthRequest={globalSettings(({ leftPanel }) => leftPanel.width / 2)}
        class="slider"
        drawValue={false}
        min={setting.min}
        max={setting.max}
        value={setting.value ?? 0}
        onValueChanged={(self) => {
          let value = self.get_value();
          infoLabel.label = String(
            setting.type === "int" ? Math.round(value) : value.toFixed(2)
          );
          switch (setting.type) {
            case "int":
              value = Math.round(value);
              break;
            case "float":
              value = parseFloat(value.toFixed(2));
              break;
            default:
              break;
          }

          setGlobalSetting(keyChanged + ".value", value);
          if (callBack) callBack(value);
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

  const SwitchWidget = () => {
    const infoLabel = (
      <label hexpand={true} label={setting.value ? "On" : "Off"} />
    ) as Gtk.Label;

    const Switch = (
      <switch
        active={setting.value}
        onNotifyActive={(self) => {
          const active = self.active;
          setGlobalSetting(keyChanged + ".value", active);
          infoLabel.label = active ? "On" : "Off";
          if (callBack) callBack(active);
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

      {setting.type === "bool" ? <SwitchWidget /> : <SliderWidget />}
    </box>
  );
};

interface NestedSettings {
  [key: string]: AGSSetting | NestedSettings;
}

const applyHyprlandSetting = (fullKey: string, value: any) => {
  execAsync(
    `bash -c "echo -e '${fullKey} = ${value}' > ${hyprCustomDir}/${fullKey}.conf && hyprctl keyword ${fullKey} ${value}"`
  ).catch((err) => notify(err));
};

const createHyprlandSettings = (
  prefix: string,
  settings: NestedSettings
): JSX.Element[] => {
  const result: JSX.Element[] = [];

  Object.entries(settings).forEach(([key, value]) => {
    const fullKey = prefix ? `${prefix}.${key}` : key;

    if (typeof value === "object" && value !== null && !("type" in value)) {
      // Nested category
      result.push(...createHyprlandSettings(fullKey, value as NestedSettings));
    } else {
      // Leaf setting
      const setting = value as AGSSetting;
      const settingKey = `hyprland.${fullKey}`;

      result.push(
        Setting(settingKey, setting, (newValue) => {
          // replace . with :
          print("Applying Hyprland setting:", fullKey, "=", newValue);
          const key = fullKey.replace(/\./g, ":");
          print("Hyprland key:", key);
          applyHyprlandSetting(key, newValue);
        })
      );
    }
  });

  return result;
};

export default () => {
  const hyprlandSettings = createHyprlandSettings(
    "",
    globalSettings.peek().hyprland
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
          <BarLayoutSetting />
          {Setting(
            "bar.orientation",
            globalSettings.peek().bar.orientation,
            refreshCss
          )}
          {Setting("ui.opacity", globalSettings.peek().ui.opacity, refreshCss)}
          {Setting("ui.scale", globalSettings.peek().ui.scale, refreshCss)}
          {Setting(
            "ui.fontSize",
            globalSettings.peek().ui.fontSize,
            refreshCss
          )}
        </box>
        <box
          class={"category"}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={16}
        >
          <label label="Hyprland" halign={Gtk.Align.START} />
          {hyprlandSettings}
        </box>
        <box
          class={"category"}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={16}
        >
          <label label="Custom" halign={Gtk.Align.START} />
          {Setting(
            "autoWorkspaceSwitching",
            globalSettings.peek().autoWorkspaceSwitching
          )}
        </box>
        {resetButton()}
      </box>
    </scrolledwindow>
  );
};
