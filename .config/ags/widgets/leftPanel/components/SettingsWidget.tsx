import App from "ags/gtk4/app";
import { Gtk } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Astal } from "ags/gtk4";
import Hyprland from "gi://AstalHyprland";
import GObject from "ags/gobject";
import Pango from "gi://Pango";
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
import { hyprThemeConfPath } from "../../../constants/path.constants";
const hyprland = Hyprland.get_default();

const hyprCustomDir: string = "$HOME/.config/hypr/config/custom";

// Wallpaper mode / primary choices (shared with the wallpaper switcher)
export const wallpaperModeChoices = [
  { label: "Per Workspace", value: "workspace" },
  { label: "Global", value: "global" },
];

export const wallpaperPrimaryChoices = [
  { label: "Workspace 1", value: "workspace1" },
  { label: "Custom", value: "custom" },
];

// Re-resolve and apply the wallpaper that should be shown now (any type) on
// every connected monitor. Used for mode/primary and Wallpaper Engine launch
// options (fps/volume/mute/...), which need a fresh engine to take effect.
export const applyCurrentWallpapers = () => {
  execAsync([
    "bash",
    "-c",
    `for m in $(hyprctl monitors -j | jq -r '.[].name'); do "$HOME/.config/hypr/wallpaper-daemon/apply-current.sh" "$m"; done`,
  ]).catch((err) => notify({ summary: "Error", body: String(err) }));
};

// Send a live command to running Wallpaper Engine processes (no restart). Used
// for scaling/clamp/speed/property tweaks.
// Send a live control command to the running engine(s). The ctl script exits
// non-zero (and prints a reason) when no engine is reachable or it rejects the
// command, so a dead/orphaned socket no longer fails silently — we surface it.
export const controlWE = (args: string): Promise<boolean> =>
  execAsync([
    "bash",
    "-c",
    `"$HOME/.config/hypr/wallpaper-daemon/wallpaperengine-ctl.sh" ${args}`,
  ])
    .then(() => true)
    .catch(() => {
      notify({
        summary: "Wallpaper Engine",
        body: `Couldn't apply "${args}" live — the engine isn't reachable. It will apply on the next reload.`,
      });
      return false;
    });

// Restart running engines (for changes that can't be applied live, e.g. the
// audio capture device).
export const restartWE = () =>
  execAsync([
    "bash",
    "-c",
    `"$HOME/.config/hypr/wallpaper-daemon/wallpaperengine-restart.sh"`,
  ]).catch(() => {});

// Try to apply a change live; if the running engine can't (socket dead, or the
// command isn't supported by that build), fall back to a full restart so the
// change always takes effect — no manual switch-back-and-forth needed.
export const controlWEOrRestart = (args: string): Promise<void> =>
  execAsync([
    "bash",
    "-c",
    `"$HOME/.config/hypr/wallpaper-daemon/wallpaperengine-ctl.sh" ${args}`,
  ])
    .then(() => undefined)
    .catch(() => restartWE().then(() => undefined));

// Wallpaper Engine option choices (shared with the wallpaper switcher)
export const weScalingChoices = [
  { label: "Default", value: "default" },
  { label: "Fill", value: "fill" },
  { label: "Fit", value: "fit" },
  { label: "Stretch", value: "stretch" },
];

export const weClampChoices = [
  { label: "Clamp", value: "clamp" },
  { label: "Border", value: "border" },
  { label: "Repeat", value: "repeat" },
];

const setThemeFlagInConf = (
  flag: "autocolor" | "autovariant",
  enabled: boolean,
) => {
  execAsync([
    "bash",
    "-c",
    `if [[ -f "${hyprThemeConfPath}" ]]; then
      sed -i 's/^${flag}=.*/${flag}=${enabled ? "true" : "false"}/' "${hyprThemeConfPath}"
      grep -q '^${flag}=' "${hyprThemeConfPath}" || printf '%s\n' '${flag}=${enabled ? "true" : "false"}' >> "${hyprThemeConfPath}"
    else
      printf '%s\n' '${flag}=${enabled ? "true" : "false"}' > "${hyprThemeConfPath}"
    fi`,
  ]).catch((err) => notify({ summary: "Error", body: err.toString() }));
};

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
              hyprland.dispatch("hl.dsp.exit()", "");
            });
          })
          .catch((err) => notify({ summary: "Error", body: err.toString() }));
      }
    })
    .catch((err) => notify({ summary: "Error", body: err.toString() }));
}

// Audio OUTPUT devices for reactive Wallpaper Engine wallpapers (detected at
// runtime). value = monitor source name, label = friendly description.
const [audioSources, setAudioSources] = createState<
  { value: string; label: string }[]
>([]);

const detectAudioSources = async () => {
  try {
    const out = await execAsync([
      "bash",
      "-c",
      `"$HOME/.config/hypr/wallpaper-daemon/wallpaperengine-audio-devices.sh"`,
    ]);
    setAudioSources(
      out
        .split("\n")
        .filter(Boolean)
        .map((line) => {
          const [value, label] = line.split("\t");
          return { value, label: label || value };
        }),
    );
  } catch {
    setAudioSources([]);
  }
};

// Dropdown to pick the audio capture source (empty = system default output).
const AudioDeviceSelector = () => (
  <box
    orientation={Gtk.Orientation.VERTICAL}
    spacing={5}
    $={() => detectAudioSources()}
  >
    <label
      class="subcategory-label"
      label="Audio Device (reactive wallpapers)"
      halign={Gtk.Align.START}
    />
    <menubutton class="category-selector" halign={Gtk.Align.START}>
      <label
        ellipsize={Pango.EllipsizeMode.END}
        maxWidthChars={28}
        label={globalSettings(({ wallpaperEngine }) => {
          const v = wallpaperEngine.audioDevice.value;
          if (!v) return "System Default";
          const found = audioSources.peek().find((s) => s.value === v);
          if (found) return found.label;
          // Friendlier fallback for a raw PulseAudio node name (the full path is
          // huge and used to force the whole settings panel wider than it should be).
          return v.replace(/^alsa_(output|input)\./, "").replace(/\.monitor$/, "");
        })}
      />
      <popover>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={5} class="popover">
          <button
            class="category"
            label="System Default"
            onClicked={() => {
              setGlobalSetting("wallpaperEngine.audioDevice.value", "");
              controlWEOrRestart(`set audiodevice default`);
            }}
          />
          <For each={audioSources}>
            {(src) => (
              <button
                class="category"
                label={src.label}
                onClicked={() => {
                  setGlobalSetting(
                    "wallpaperEngine.audioDevice.value",
                    src.value,
                  );
                  controlWEOrRestart(`set audiodevice ${src.value}`);
                }}
              />
            )}
          </For>
        </box>
      </popover>
    </menubutton>
  </box>
);

// File Manager options with display names and commands
const fileManagerOptions = [
  { id: "nautilus", name: "Nautilus (GNOME)", command: "nautilus" },
  { id: "thunar", name: "Thunar (XFCE)", command: "thunar" },
  { id: "dolphin", name: "Dolphin (KDE)", command: "dolphin" },
  { id: "nemo", name: "Nemo (Cinnamon)", command: "nemo" },
  { id: "pcmanfm", name: "PCManFM", command: "pcmanfm" },
  { id: "ranger", name: "Ranger (Terminal)", command: "kitty ranger" },
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
  if (
    from < 0 ||
    to < 0 ||
    from >= array.length ||
    to >= array.length ||
    from === to
  ) {
    return [...array];
  }

  const copy = [...array];
  const [item] = copy.splice(from, 1);
  if (item === undefined) return [...array];
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

const applyButton = () => {
  return (
    <button
      class="apply-button"
      label="Apply Hyprland Settings"
      halign={Gtk.Align.END}
      onClicked={() => {
        hyprland.dispatch("hl.dsp.exec_cmd('hyprctl reload')", "");
      }}
    />
  );
};

const resetButton = () => {
  const resetSettings = () => {
    //global settings
    setGlobalSettings(defaultSettings);
    setThemeFlagInConf(
      "autocolor",
      Boolean(defaultSettings.dynamicThemeColors.value),
    );
    setThemeFlagInConf(
      "autovariant",
      Boolean(defaultSettings.dynamicThemeVariants.value),
    );

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

export const Setting = ({
  keyChanged,
  setting,
  callBack,
  choices,
  compact = false,
}: {
  keyChanged: string;
  setting: AGSSetting;
  callBack?: (newValue?: any) => void;
  choices?: { label: string; value: any }[];
  compact?: boolean;
}) => {
  const Title = () => (
    <label hexpand={!compact} xalign={0} label={setting.name} />
  );

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
        widthRequest={
          compact
            ? 140
            : globalSettings(({ leftPanel }) => leftPanel.width / 2)
        }
        hexpand={!compact}
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

    if (compact) {
      return (
        <box spacing={5} halign={Gtk.Align.START} valign={Gtk.Align.CENTER}>
          <Title />
          {Slider}
          {infoLabel}
        </box>
      );
    }

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
      <label hexpand={false} label={setting.value ? "On" : "Off"} />
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

    if (compact) {
      return (
        <box spacing={5} halign={Gtk.Align.START} valign={Gtk.Align.CENTER}>
          <Title />
          {Switch}
          {infoLabel}
        </box>
      );
    }

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
      <box
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        halign={compact ? Gtk.Align.START : Gtk.Align.FILL}
      >
        <Title />
        {/* In the settings panel (non-compact) fill the panel width so the choice
            buttons share it; in the compact switcher keep them natural-width. */}
        <box spacing={5} hexpand={!compact}>
          {choices &&
            choices.map((choice) => (
              <togglebutton
                hexpand={!compact}
                label={choice.label}
                active={globalSettings((s) => {
                  // get current value from AGSSetting from settings
                  const keys = keyChanged.split(".");
                  let current: any = s;
                  for (const key of keys) {
                    current = current[key];
                  }
                  // compare current value with choice value (in case of array, compare arrays)
                  return (
                    current.value === choice.value ||
                    (Array.isArray(current.value) &&
                      Array.isArray(choice.value) &&
                      current.value.length === choice.value.length &&
                      current.value.every(
                        (val: any, index: number) =>
                          val === choice.value[index],
                      ))
                  );
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

  const TextWidget = () => {
    const isSecret = keyChanged.toLowerCase().includes("key") || keyChanged.toLowerCase().includes("user");
    // Hide by default if it's a secret (false for visibility property)
    const [revealText, setRevealText] = createState(!isSecret);
  
    let entryRef: Gtk.Entry | null = null;
  
    return (
      <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
        <Title />
        <box orientation={Gtk.Orientation.HORIZONTAL} spacing={5} hexpand>
          
          <entry
            hexpand
            text={setting.value ?? ""}
            placeholderText={`Enter ${setting.name}`}
            
            // For GTK4/AGS, passing the Boolean binding correctly is important
            visibility={revealText((v) => v)}
            // Pass the ASCII code of the "*" character (42) instead of a string so that GTK displays the mask correctly
            invisibleChar={42} 
            
            $={(self) => { 
              entryRef = self;
            }}
            
            onActivate={(self) => {
              const text = self.text;
              const sameValue = text === setting.value;
  
              if (!sameValue) {
                setGlobalSetting(keyChanged + ".value", text);
                notify({
                  summary: setting.name,
                  body: `Changed to ${isSecret ? "••••••••" : text}`,
                });
                if (callBack) callBack(text);
                self.set_css_classes([]);
                self.set_tooltip_markup("");
              }
            }}
            onChanged={(self: Gtk.Entry) => {
              const sameValue = self.text === setting.value;
              if (!sameValue) {
                self.set_css_classes(["unsaved"]);
                self.set_tooltip_markup(
                  `<b>Unsaved Changes</b>\nPress Enter to save changes`,
                );
              } else {
                self.set_css_classes([]);
                self.set_tooltip_markup("");
              }
            }}
          />
  
          {/* Show/Hide Button */}
          {isSecret && (
            <button
              tooltipText={revealText((v) => v ? "Hide Sensitive Data" : "Show Sensitive Data")}
              onClicked={() => setRevealText(!revealText.get())}
            >
              <label label={revealText((v) => v ? "󰈈" : "󰈉")} /> 
            </button>
          )}
  
          {/* Copy button via wl-copy */}
          <button
            tooltipText="Copy to Clipboard"
            onClicked={() => {
              if (entryRef) {
                const textToCopy = entryRef.text;
                execAsync(["wl-copy", textToCopy])
                  .then(() => {
                    notify({
                      summary: setting.name,
                      body: "Copied to clipboard!",
                    });
                  })
                  .catch((err) => {
                    console.error("wl-copy failed:", err);
                  });
              }
            }}
          >
            <label label="󰆏" />
          </button>
  
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
      case "string":
        return TextWidget();
      default:
        return (
          <label halign={Gtk.Align.END} label={"Unsupported setting type"} />
        );
    }
  };

  return (
    <box class="setting" spacing={5} tooltipMarkup={setting.tooltip ?? ""}>
      <Widget />
    </box>
  );
};

interface NestedSettings {
  [key: string]: AGSSetting | NestedSettings;
}

const toLuaValue = (value: any): string => {
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") return String(value);
  if (Array.isArray(value)) {
    const items = value.map((item) => toLuaValue(item)).join(", ");
    return `{ ${items} }`;
  }
  const escaped = String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  return `"${escaped}"`;
};

const toLuaKey = (key: string): string => {
  return /^[A-Za-z_][A-Za-z0-9_]*$/.test(key) ? key : `["${key}"]`;
};

const buildLuaConfig = (fullKey: string, value: any): string => {
  const parts = fullKey.split(":");
  let expr = toLuaValue(value);

  for (let i = parts.length - 1; i >= 0; i -= 1) {
    expr = `{ ${toLuaKey(parts[i])} = ${expr} }`;
  }

  return `hl.config(${expr})`;
};

const applyHyprlandSetting = (fullKey: string, value: any) => {
  const luaConfig = buildLuaConfig(fullKey, value);
  const configPath = `${hyprCustomDir}/${fullKey}.lua`;

  execAsync([
    "bash",
    "-c",
    `cat > "${configPath}" <<'EOF'\n${luaConfig}\nEOF\nhyprctl keyword ${fullKey} ${value}`,
  ]).catch((err) => notify(err));
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
    <box class="settings" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <scrolledwindow
        vexpand
        // Never scroll horizontally: constrain content to the panel width so the choice
        // FlowBoxes wrap to a second row instead of overflowing/clipping at the edge.
        hscrollbarPolicy={Gtk.PolicyType.NEVER}
        $={() =>
          // Initialize detection
          detectFileManagers()
        }
      >
        <box orientation={Gtk.Orientation.VERTICAL} spacing={16}>
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
            />
            <Setting
              keyChanged="alwaysOnWidget.visibility"
              setting={globalSettings.peek().alwaysOnWidget.visibility}
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
            <label label={"AGS -- Api Keys"} halign={Gtk.Align.START} />
            <box class={"sub-category"}>
              <Setting
                keyChanged="apiKeys.openrouter.key"
                setting={globalSettings.peek().apiKeys.openrouter.key}
              />
            </box>
            <box class={"sub-category"} spacing={5}>
              <Setting
                keyChanged="apiKeys.danbooru.user"
                setting={globalSettings.peek().apiKeys.danbooru.user}
              />
              <Setting
                keyChanged="apiKeys.danbooru.key"
                setting={globalSettings.peek().apiKeys.danbooru.key}
              />
            </box>
            <box class={"sub-category"} spacing={5}>
              <Setting
                keyChanged="apiKeys.gelbooru.user"
                setting={globalSettings.peek().apiKeys.gelbooru.user}
              />
              <Setting
                keyChanged="apiKeys.gelbooru.key"
                setting={globalSettings.peek().apiKeys.gelbooru.key}
              />
            </box>
            <box class={"sub-category"} spacing={5}>
              <Setting
                keyChanged="apiKeys.safebooru.user"
                setting={globalSettings.peek().apiKeys.safebooru.user}
              />
              <Setting
                keyChanged="apiKeys.safebooru.key"
                setting={globalSettings.peek().apiKeys.safebooru.key}
              />
            </box>
          </box>
          <box
            class={"category"}
            orientation={Gtk.Orientation.VERTICAL}
            spacing={16}
          >
            <label
              label="AGS -- KeyStrokeVisualizer"
              halign={Gtk.Align.START}
            />
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
            <label label="Wallpaper" halign={Gtk.Align.START} />
            <Setting
              keyChanged="wallpaper.mode"
              setting={globalSettings.peek().wallpaper.mode}
              choices={wallpaperModeChoices}
              callBack={applyCurrentWallpapers}
            />
            <Setting
              keyChanged="wallpaper.primarySource"
              setting={globalSettings.peek().wallpaper.primarySource}
              choices={wallpaperPrimaryChoices}
              callBack={applyCurrentWallpapers}
            />
            <Setting
              keyChanged="wallpaper.playbackSpeed"
              setting={globalSettings.peek().wallpaper.playbackSpeed}
              callBack={(v) => controlWE(`speed ${v}`)}
            />
          </box>
          <box
            class={"category"}
            orientation={Gtk.Orientation.VERTICAL}
            spacing={16}
          >
            <label label="Wallpaper Engine" halign={Gtk.Align.START} />
            <Setting
              keyChanged="wallpaperEngine.scaling"
              setting={globalSettings.peek().wallpaperEngine.scaling}
              choices={weScalingChoices}
              callBack={(v) => controlWE(`scaling ${v}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.clamping"
              setting={globalSettings.peek().wallpaperEngine.clamping}
              choices={weClampChoices}
              callBack={(v) => controlWE(`clamp ${v}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.fps"
              setting={globalSettings.peek().wallpaperEngine.fps}
              callBack={(v) => controlWE(`set fps ${v}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.renderScale"
              setting={globalSettings.peek().wallpaperEngine.renderScale}
              callBack={(v) => controlWEOrRestart(`set renderscale ${v}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.volume"
              setting={globalSettings.peek().wallpaperEngine.volume}
              callBack={(v) => controlWE(`volume ${v}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.mute"
              setting={globalSettings.peek().wallpaperEngine.mute}
              callBack={(v) => controlWE(`mute ${v ? 1 : 0}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.noAutomute"
              setting={globalSettings.peek().wallpaperEngine.noAutomute}
              callBack={(v) => controlWE(`set noautomute ${v ? 1 : 0}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.disableMouse"
              setting={globalSettings.peek().wallpaperEngine.disableMouse}
              callBack={(v) => controlWE(`set disablemouse ${v ? 1 : 0}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.disableParallax"
              setting={globalSettings.peek().wallpaperEngine.disableParallax}
              callBack={(v) => controlWE(`set disableparallax ${v ? 1 : 0}`)}
            />
            <Setting
              keyChanged="wallpaperEngine.noFullscreenPause"
              setting={globalSettings.peek().wallpaperEngine.noFullscreenPause}
              callBack={(v) => controlWE(`set nofullscreenpause ${v ? 1 : 0}`)}
            />
            <AudioDeviceSelector />
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
              keyChanged="dynamicThemeColors"
              setting={globalSettings.peek().dynamicThemeColors}
              callBack={(enabled) =>
                setThemeFlagInConf("autocolor", Boolean(enabled))
              }
            />
            <Setting
              keyChanged="dynamicThemeVariants"
              setting={globalSettings.peek().dynamicThemeVariants}
              callBack={(enabled) =>
                setThemeFlagInConf("autovariant", Boolean(enabled))
              }
            />
            {/* <Setting
            keyChanged="autoWorkspaceSwitching"
            setting={globalSettings.peek().autoWorkspaceSwitching}
          /> */}
            <FileManagerSelector />
          </box>
        </box>
      </scrolledwindow>
      <box spacing={5} halign={Gtk.Align.END}>
        {applyButton()}
        {resetButton()}
      </box>
    </box>
  );
};
