import { createState, createBinding, Accessor } from "ags";
import { execAsync } from "ags/process";
import Apps from "gi://AstalApps";

import { readJson, readJSONFile } from "../utils/json";
import { arithmetic, containsOperator } from "../utils/arithmetic";
import {
  containsProtocolOrTLD,
  formatToURL,
  getDomainFromURL,
} from "../utils/url";
import app from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";

import Astal from "gi://Astal?version=4.0";
import { notify } from "../utils/notification";
import {
  emptyWorkspace,
  globalMargin,
  globalSettings,
  globalTransition,
} from "../variables";

const apps = new Apps.Apps();

import Hyprland from "gi://AstalHyprland";
import { hideWindow } from "../utils/window";
import { getMonitorName } from "../utils/monitor";
import { LauncherApp } from "../interfaces/app.interface";
import { customApps } from "../constants/app.constants";
import { quickApps } from "../constants/app.constants";
import { For } from "gnim";
import Gdk from "gi://Gdk?version=4.0";
import { convert, isConversionQuery } from "../utils/convert";
const hyprland = Hyprland.get_default();

const MAX_ITEMS = 10;

const [Results, setResults] = createState<LauncherApp[]>([]);

let parentWindowRef: Gtk.Window | null = null;

const QuickApps = () => {
  const apps = (
    <Gtk.Revealer
      transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
      transitionDuration={globalTransition}
      revealChild={Results((results) => results.length === 0)}
    >
      <scrolledwindow heightRequest={quickApps.length * 40}>
        <box
          class="quick-apps"
          spacing={5}
          orientation={Gtk.Orientation.VERTICAL}
        >
          {quickApps.map((app, index) => (
            <Gtk.Button
              hexpand
              class="quick-app"
              onClicked={() => {
                app.app_launch();
                if (parentWindowRef) {
                  parentWindowRef.hide();
                }
              }}
            >
              <box spacing={5}>
                <label class="icon" label={app.app_icon} />
                <label label={app.app_name} />
              </box>
            </Gtk.Button>
          ))}
        </box>
      </scrolledwindow>
    </Gtk.Revealer>
  );

  return (
    <box class="quick-launcher" spacing={5}>
      {apps}
    </box>
  );
};

const helpCommands = {
  "Press <Escape>": "to reset input",
  "... ...": "open with argument",
  "translate .. > ..": "translate .. > (en,fr,es,de,pt,ru,ar...)",
  "... .com OR https://...": "open link",
  "..*/+-..": "arithmetics",
  "emoji ...": "search emojis",
  "100c to f / 10kg in lb": "unit conversion (temp/weight/length/volume/speed)",
};

const Help = (
  <menubutton class="help" tooltipText="Help" halign={Gtk.Align.END}>
    <label label="" />
    <popover>
      <box class="help-popover" spacing={5}>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          {Object.entries(helpCommands).map(([command, description]) => (
            <box spacing={10}>
              <label
                label={command}
                class="command"
                // ellipsize={Gtk.EllipsizeMode.END}
              />
              <label
                label={description}
                class="description"
                // ellipsize={Gtk.EllipsizeMode.END}
              />
            </box>
          ))}
        </box>
      </box>
    </popover>
  </menubutton>
);

let debounceTimer: any;
let args: string[];
let entryWidget: any;

const Entry = (
  <Gtk.Entry
    hexpand={true}
    placeholderText="Search for an app, emoji, translate, url, or do some math..."
    $={(self) => (entryWidget = self)}
    onChanged={async (self: any) => {
      const text = self.get_text();
      if (debounceTimer) {
        clearTimeout(debounceTimer);
      }

      debounceTimer = setTimeout(async () => {
        try {
          if (!text || text.trim() === "") {
            setResults([]);
            return;
          }

          // Check for conversion queries FIRST (before other commands)
          if (isConversionQuery(text)) {
            const conversions = await convert(text);
            setResults(
              conversions.map((conv) => ({
                app_name: `${conv.formatted}`,
                app_icon: "󰟛", // Conversion icon
                app_desc: `Converted from ${conv.original}`,
                app_launch: () => execAsync(`wl-copy "${conv.formatted}"`),
              }))
            );
            return; // Exit early after conversion
          }
          args = text.split(" ");

          if (args[0].includes(">")) {
            const filteredCommands = customApps.filter((app) =>
              app.app_name
                .toLowerCase()
                .includes(text.replace(">", "").trim().toLowerCase())
            );
            setResults(filteredCommands);
          } else if (args[0].includes("translate")) {
            const language = text.includes(">")
              ? text.split(">")[1].trim()
              : "en";
            const translation = await execAsync(
              `bash ./scripts/translate.sh '${text
                .split(">")[0]
                .replace("translate", "")
                .trim()}' '${language}'`
            );
            setResults([
              {
                app_name: translation,
                app_launch: () => execAsync(`wl-copy ${translation}`),
              },
            ]);
          } // Handle emojis
          else if (args[0].includes("emoji")) {
            const emojis: [] = readJSONFile("./assets/emojis/emojis.json");
            const filteredEmojis = emojis.filter(
              (emoji: { app_tags: string; app_name: string }) =>
                emoji.app_tags
                  .toLowerCase()
                  .includes(text.replace("emoji", "").trim())
            );
            setResults(
              filteredEmojis.map((emoji: { app_name: string }) => ({
                app_name: emoji.app_name,
                app_icon: emoji.app_name,
                app_type: "emoji",
                app_launch: () => execAsync(`wl-copy ${emoji.app_name}`),
              }))
            );
          }
          // handle URL
          else if (containsProtocolOrTLD(args[0])) {
            setResults([
              {
                app_name: getDomainFromURL(text),
                app_launch: () =>
                  execAsync(`xdg-open ${formatToURL(text)}`).then(() => {
                    const browser = execAsync(
                      `bash -c "xdg-settings get default-web-browser | sed 's/\.desktop$//'"`
                    );
                    notify({
                      summary: "URL",
                      body: `Opening ${text} in ${browser}`,
                    });
                  }),
              },
            ]);
          }
          // handle arithmetic
          else if (containsOperator(args[0])) {
            setResults([
              {
                app_name: arithmetic(text),
                app_launch: () => execAsync(`wl-copy ${arithmetic(text)}`),
              },
            ]);
          }
          // Handle apps
          else {
            setResults(
              apps
                .fuzzy_query(args.shift()!)
                .slice(0, MAX_ITEMS)
                .map((app: any) => ({
                  app_name: app.name,
                  app_icon: app.iconName,
                  app_type: "app",
                  app_arg: args.join(" "),
                  app_launch: () =>
                    !args.join("")
                      ? app.launch()
                      : hyprland.message_async(
                          `dispatch exec ${app.executable} ${args.join(" ")}`,
                          () => {}
                        ),
                }))
            );
            if (Results.get().length === 0) {
              setResults([
                {
                  app_name: `Try ${text}`,
                  app_icon: "󰋖",
                  app_launch: () =>
                    hyprland.message_async(`dispatch exec ${text}`, () => {}),
                },
              ]);
            }
          }
        } catch (err) {
          notify({
            summary: "Error",
            body: err instanceof Error ? err.message : String(err),
          });
        }
        print("Results:", Results.get().length);
      }, 100); // 100ms delay
    }}
    onActivate={() => {
      if (Results.get().length > 0) {
        launchApp(Results.get()[0]);
      }
    }}
  />
);

const EmptyEntry = () => {
  entryWidget.set_text("");
  setResults([]);
};

const launchApp = (app: LauncherApp) => {
  app.app_launch();
  // hideWindow(`app-launcher-${monitorName.get()}`);
  if (parentWindowRef) {
    parentWindowRef.hide();
  }
  EmptyEntry();
};

const ResultsDisplay = () => {
  const buttonContent = (element: LauncherApp) => (
    <box
      spacing={10}
      halign={element.app_type === "emoji" ? Gtk.Align.CENTER : Gtk.Align.START}
    >
      {element.app_type === "app" ? (
        <image iconName={element.app_icon} />
      ) : (
        <box />
      )}
      <label label={element.app_name} />
      <label class="argument" label={element.app_arg || ""} />
    </box>
  );

  const AppButton = ({
    element,
    className,
  }: {
    element: LauncherApp;
    className?: string;
  }) => {
    return (
      <Gtk.Button
        hexpand={true}
        class={className}
        onClicked={() => {
          launchApp(element);
        }}
      >
        {buttonContent(element)}
      </Gtk.Button>
    );
  };

  // if (Results.length === 0) return <box />;

  const rows = (
    <box
      visible={Results((results) => results.length > 0)}
      class="results"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
    >
      <For each={Results}>
        {(result, i) => (
          <AppButton
            element={result}
            className={i.get() === 0 ? "checked" : ""}
          />
        )}
      </For>
    </box>
  );

  const maxHeight = 500;
  return (
    <revealer
      revealChild={Results((results) => results.length > 0)}
      transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
      transitionDuration={globalTransition}
    >
      <scrolledwindow
        heightRequest={Results((results) =>
          results.length * 45 > maxHeight ? maxHeight : results.length * 45
        )}
      >
        {rows}
      </scrolledwindow>
    </revealer>
  );
};

export default (monitor: any) => (
  <Astal.Window
    gdkmonitor={monitor}
    name={`app-launcher-${getMonitorName(monitor.get_display(), monitor)}`}
    namespace="app-launcher"
    application={app}
    exclusivity={Astal.Exclusivity.EXCLUSIVE}
    keymode={Astal.Keymode.EXCLUSIVE}
    layer={Astal.Layer.TOP}
    margin={globalMargin} // top right bottom left
    visible={false}
    $={(self) => (parentWindowRef = self)}
    resizable={false}
  >
    <Gtk.EventControllerKey
      onKeyPressed={({ widget }, keyval: number) => {
        if (keyval === Gdk.KEY_Escape) {
          widget.hide();
          return true;
        }
      }}
    />
    <box
      orientation={Gtk.Orientation.VERTICAL}
      class="app-launcher"
      spacing={5}
    >
      <box spacing={5}>
        {Entry}
        {Help}
      </box>
      {ResultsDisplay()}
      {QuickApps()}
    </box>
  </Astal.Window>
);
