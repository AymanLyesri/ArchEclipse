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
import { timeout } from "ags/time";
const hyprland = Hyprland.get_default();

const hyprCustomDir: string = "$HOME/.config/hypr/configs/custom";

// Add User to input group for key stroke visualizer
function addUserToInputGroup() {
  // check if user is in input group, if not add user to input group
  execAsync(
    `bash -c "groups $USER | grep -q '\\binput\\b' && echo 'yes' || echo $USER"`,
  )
    .then((result) => {
      if (result.trim() !== "yes") {
        notify({
          summary: "Key Stroke Visualizer",
          body: `Adding ${result.trim()} to 'input' group for keystroke detection.\n You may be prompted for your password.`,
        });
        execAsync(`pkexec usermod -aG input ${result.trim()}`)
          .then(() => {
            notify({
              summary: "Key Stroke Visualizer",
              body: "Will be Logging out to apply changes. in 5 seconds...",
            });
            timeout(5000, () => {
              hyprland.message_async("dispatch exit", () => {});
            });
          })
          .catch((err) => notify({ summary: "Error", body: err.toString() }));
      }
    })
    .catch((err) => notify({ summary: "Error", body: err.toString() }));
}

// File Manager options with display names and commands
const fileManagerOptions = [
  { id: "nautilus", name: "Nautilus (GNOME)", command: "nautilus" },
  { id: "thunar", name: "Thunar (XFCE)", command: "thunar" },
  { id: "dolphin", name: "Dolphin (KDE)", command: "dolphin" },
  { id: "nemo", name: "Nemo (Cinnamon)", command: "nemo" },
  { id: "pcmanfm", name: "PCManFM", command: "pcmanfm" },
  { id: "ranger", name: "Ranger (Terminal)", command: "foot ranger" },
];

// Detect installed file managers
const [installedFileManagers, setInstalledFileManagers] = createState<
  typeof fileManagerOptions
>([]);

const detectFileManagers = async () => {
  const installed: typeof fileManagerOptions = [];
  for (const fm of fileManagerOptions) {
    try {
      const result = await execAsync(
        `bash -c "command -v ${
          fm.command.split(" ")[0]
        } >/dev/null 2>&1 && echo 'yes' || echo 'no'"`,
      );
      if (result.trim() === "yes") {
        installed.push(fm);
      }
    } catch {
      // Command not found
    }
  }
  setInstalledFileManagers(installed);
};

function moveItem<T>(array: T[], from: number, to: number): T[] {
  const copy = [...array];
  const [item] = copy.splice(from, 1);
  copy.splice(to, 0, item);
  return copy;
}

// File Manager Selector Component
const FileManagerSelector = () => {
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <label
        class={"subcategory-label"}
        label={"File Manager"}
        halign={Gtk.Align.START}
      />
      <box class="setting" spacing={10}>
        <For each={installedFileManagers}>
          {(fm) => (
            <togglebutton
              hexpand
              class="widget"
              label={fm.id}
              tooltipMarkup={`<b>${fm.name}</b>\nCommand: ${fm.command}`}
              active={globalSettings((s) => s.fileManager === fm.id)}
              onToggled={({ active }) => {
                if (active) {
                  setGlobalSetting("fileManager", fm.id);
                  notify({
                    summary: "File Manager",
                    body: `Changed to ${fm.name}`,
                  });
                }
              }}
            />
          )}
        </For>
      </box>
    </box>
  );
};

const applyHyprlandSettings = (
  settings: NestedSettings,
  prefix: string = "",
) => {
  Object.entries(settings).forEach(([key, value]) => {
    const fullKey = prefix ? `${prefix}.${key}` : key;
    if (typeof value === "object" && value !== null && !("type" in value)) {
      // nested
      applyHyprlandSettings(value as NestedSettings, fullKey);
    } else {
      // leaf setting
      const setting = value as AGSSetting;
      print("Applying Hyprland setting:", fullKey, "=", setting.value);
      const hyprKey = fullKey.replace(/\./g, ":");
      applyHyprlandSetting(hyprKey, setting.value);
    }
  });
};

const resetButton = () => {
  const resetSettings = () => {
    //global settings
    setGlobalSettings(defaultSettings);

    // hyprland settings
    applyHyprlandSettings(defaultSettings.hyprland);
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
      <box class="setting" spacing={10}>
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
                          w.name === widget.name ? { ...w, enabled: true } : w,
                        ),
                    );
                  } else {
                    // Disable the widget
                    setGlobalSetting(
                      "bar.layout",
                      globalSettings
                        .peek()
                        .bar.layout.map((w) =>
                          w.name === widget.name ? { ...w, enabled: false } : w,
                        ),
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
                      (w) => w.name === widget.name,
                    );

                    if (fromIndex === -1) {
                      // Enabling by dragging
                      if (widgets.length >= 3) return true;
                      const newLayout = [...widgets];
                      newLayout.splice(
                        toIndex === -1 ? widgets.length : toIndex,
                        0,
                        widget,
                      );
                      setGlobalSetting("bar.layout", newLayout);
                      return true;
                    } else {
                      // Reordering
                      if (toIndex === -1 || fromIndex === toIndex) return true;
                      setGlobalSetting(
                        "bar.layout",
                        moveItem(widgets, fromIndex, toIndex),
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

const Setting = ({
  keyChanged,
  setting,
  callBack,
  choices,
}: {
  keyChanged: string;
  setting: AGSSetting;
  callBack?: (newValue?: any) => void;
  choices?: { label: string; value: any }[];
}) => {
  const Title = () => <label hexpand xalign={0} label={setting.name} />;

  const SliderWidget = () => {
    const infoLabel = (
      <label
        hexpand={true}
        label={String(
          setting.type === "int"
            ? Math.round(setting.value ?? 0)
            : (setting.value ?? 0).toFixed(2),
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
            setting.type === "int" ? Math.round(value) : value.toFixed(2),
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
      <box spacing={5}>
        <Title />
        <box hexpand halign={Gtk.Align.END} spacing={5}>
          {Slider}
          {infoLabel}
        </box>
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
      <box spacing={5}>
        <Title />
        <box hexpand halign={Gtk.Align.END} spacing={5}>
          {Switch}
          {infoLabel}
        </box>
      </box>
    );
  };

  const SelectWidget = () => {
    return (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
        <Title />
        <box spacing={5}>
          {choices &&
            choices.map((choice) => (
              <togglebutton
                hexpand
                label={choice.label}
                active={globalSettings((s) => {
                  // get current value from AGSSetting from settings
                  const keys = keyChanged.split(".");
                  let current: any = s;
                  for (const key of keys) {
                    current = current[key];
                  }
                  return current.value === choice.value;
                })}
                onToggled={({ active }) => {
                  if (active) {
                    setGlobalSetting(keyChanged + ".value", choice.value);
                    if (callBack) callBack(choice.value);
                  }
                }}
              />
            ))}
        </box>
      </box>
    );
  };

  const Widget = () => {
    switch (setting.type) {
      case "int":
        return SliderWidget();
      case "float":
        return SliderWidget();
      case "bool":
        return SwitchWidget();
      case "select":
        return SelectWidget();
      default:
        return (
          <label halign={Gtk.Align.END} label={"Unsupported setting type"} />
        );
    }
  };

  return (
    <box class="setting" spacing={5}>
      <Widget />
    </box>
  );
};

interface NestedSettings {
  [key: string]: AGSSetting | NestedSettings;
}

const applyHyprlandSetting = (fullKey: string, value: any) => {
  execAsync(
    `bash -c "echo -e '${fullKey} = ${value}' > ${hyprCustomDir}/${fullKey}.conf && hyprctl keyword ${fullKey} ${value}"`,
  ).catch((err) => notify(err));
};

const createHyprlandSettings = (
  prefix: string,
  settings: NestedSettings,
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
        <Setting
          keyChanged={settingKey}
          setting={setting}
          callBack={(newValue) => {
            print("Applying Hyprland setting:", fullKey, "=", newValue);
            const key = fullKey.replace(/\./g, ":");
            print("Hyprland key:", key);
            applyHyprlandSetting(key, newValue);
          }}
        />,
      );
    }
  });

  return result;
};

export default () => {
  const hyprlandSettings = createHyprlandSettings(
    "",
    globalSettings.peek().hyprland,
  );

  return (
    <scrolledwindow
      vexpand
      $={() =>
        // Initialize detection
        detectFileManagers()
      }
    >
      <box orientation={Gtk.Orientation.VERTICAL} spacing={16} class="settings">
        <box
          class={"category"}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={16}
        >
          <label label="AGS -- Global" halign={Gtk.Align.START} />

          <BarLayoutSetting />
          <Setting
            keyChanged="bar.orientation"
            setting={globalSettings.peek().bar.orientation}
            callBack={refreshCss}
          />
          <Setting
            keyChanged="ui.opacity"
            setting={globalSettings.peek().ui.opacity}
            callBack={refreshCss}
          />
          <Setting
            keyChanged="ui.scale"
            setting={globalSettings.peek().ui.scale}
            callBack={refreshCss}
          />
          <Setting
            keyChanged="ui.fontSize"
            setting={globalSettings.peek().ui.fontSize}
            callBack={refreshCss}
          />
        </box>
        <box
          class={"category"}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={16}
        >
          <label label="AGS -- KeyStrokeVisualizer" halign={Gtk.Align.START} />
          <Setting
            keyChanged="keyStrokeVisualizer.visibility"
            setting={globalSettings.peek().keyStrokeVisualizer.visibility}
            callBack={(visibility) => {
              if (visibility) addUserToInputGroup();
            }}
          />
          <Setting
            keyChanged="keyStrokeVisualizer.anchor"
            setting={globalSettings.peek().keyStrokeVisualizer.anchor}
            choices={[
              {
                label: "Bottom Left",
                value: ["bottom", "left"],
              },
              { label: "Bottom", value: ["bottom"] },
              {
                label: "Bottom Right",
                value: ["bottom", "right"],
              },
            ]}
          />
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
          <Setting
            keyChanged="autoWorkspaceSwitching"
            setting={globalSettings.peek().autoWorkspaceSwitching}
          />
          <FileManagerSelector />
        </box>
        {resetButton()}
      </box>
    </scrolledwindow>
  );
};
