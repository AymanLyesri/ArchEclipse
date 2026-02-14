import { createState, createBinding, Accessor } from "ags";
import { execAsync } from "ags/process";
import Apps from "gi://AstalApps";

import { readJson, readJSONFile, writeJSONFile } from "../utils/json";
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
import Pango from "gi://Pango?version=1.0";
const hyprland = Hyprland.get_default();

const MAX_ITEMS = 10;

const [Results, setResults] = createState<LauncherApp[]>([]);

const [history, setHistory] = createState<string[]>([]);

let parentWindowRef: Gtk.Window | null = null;

const QuickApps = () => {
  return (
    <scrolledwindow hexpand vexpand>
      <box
        class="quick-apps results"
        spacing={5}
        orientation={Gtk.Orientation.VERTICAL}
        valign={Gtk.Align.START}
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
              <label widthRequest={24} label={app.app_icon} />
              <label label={app.app_name} />
            </box>
          </Gtk.Button>
        ))}
      </box>
    </scrolledwindow>
  );
};

let debounceTimer: any;
let args: string[];
let entryWidget: any;

const Entry = () => (
  <Gtk.Entry
    hexpand={true}
    placeholderText="Search for an app, emoji, translate, url, or do some math..."
    $={(self) => (entryWidget = self)}
    onChanged={(self: any) => {
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
              })),
            );
            return; // Exit early after conversion
          }
          args = text.split(" ");

          if (args[0].includes(">")) {
            const filteredCommands = customApps.filter((app) =>
              app.app_name
                .toLowerCase()
                .includes(text.replace(">", "").trim().toLowerCase()),
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
                .trim()}' '${language}'`,
            );
            setResults([
              {
                app_name: translation,
                app_launch: () => execAsync(`wl-copy ${translation}`),
              },
            ]);
          } // Handle emojis
          else if (args[0].includes("emoji")) {
            const emojis: [] = readJSONFile("./cache/emojis/emojis.json");
            const filteredEmojis = emojis.filter(
              (emoji: { app_tags: string; app_name: string }) =>
                emoji.app_tags
                  .toLowerCase()
                  .includes(text.replace("emoji", "").trim()),
            );
            setResults(
              filteredEmojis.map((emoji: { app_name: string }) => ({
                app_name: emoji.app_name,
                app_icon: emoji.app_name,
                app_type: "emoji",
                app_launch: () => execAsync(`wl-copy ${emoji.app_name}`),
              })),
            );
          }
          // handle arithmetic (check BEFORE URL to avoid "/" being detected as protocol)
          else if (containsOperator(args[0])) {
            setResults([
              {
                app_name: arithmetic(text),
                app_launch: () => execAsync(`wl-copy ${arithmetic(text)}`),
              },
            ]);
          }
          // handle URL
          else if (containsProtocolOrTLD(args[0])) {
            setResults([
              {
                app_name: getDomainFromURL(text),
                app_launch: () =>
                  execAsync(`xdg-open ${formatToURL(text)}`).then(() => {
                    const browser = execAsync(
                      `bash -c "xdg-settings get default-web-browser | sed 's/\.desktop$//'"`,
                    );
                    notify({
                      summary: "URL",
                      body: `Opening ${text} in ${browser}`,
                    });
                  }),
              },
            ]);
          }
          // Handle apps
          else {
            setResults(
              apps
                .fuzzy_query(args.shift()!)
                .slice(0, MAX_ITEMS)
                .map((app: Apps.Application) => ({
                  app_name: app.name,
                  app_icon: app.iconName,
                  app_description: app.description,
                  app_type: "app",
                  app_arg: args.join(" "),
                  app_launch: () => {
                    app.launch();
                    // Add to history and remove old duplicates, keep only latest 10
                    const newHistory = [
                      app.name,
                      ...history.peek().filter((name) => name !== app.name),
                    ].slice(0, 10);
                    setHistory(newHistory);
                    writeJSONFile("./cache/launcher/history.json", newHistory);
                  },
                })),
            );
            if (Results.get().length === 0) {
              setResults([
                {
                  app_name: `Try ${text} in terminal`,
                  app_icon: "󰋖",
                  app_launch: () =>
                    hyprland.message_async(
                      `dispatch exec foot 'bash -c "${text}"'`,
                      () => {},
                    ),
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

const Help = () => {
  const helpCommands = {
    "... ...": "open with argument",
    "translate .. > ..": "translate into (en,fr,es,de,pt,ru,ar...)",
    "... .com OR https://...": "open link",
    "..*/+-..": "arithmetics",
    "emoji ...": "search emojis",
    "100c to f / 10kg in lb":
      "unit conversion (temp/weight/length/volume/speed)",
  };
  return (
    <box
      visible={Results((results) => results.length <= 0)}
      class={"help"}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
    >
      {Object.entries(helpCommands).map(([command, description]) => (
        <box spacing={10}>
          <label label={command} class="command" hexpand xalign={0} />
          <label label={description} class="description" hexpand xalign={1} />
        </box>
      ))}
    </box>
  );
};

const ResultsDisplay = () => {
  const AppButton = ({
    element,
    className,
  }: {
    element: LauncherApp;
    className?: string;
  }) => {
    const buttonContent = (element: LauncherApp) => (
      <box spacing={10} hexpand>
        {/* ICON SLOT — always present */}

        <image
          visible={element.app_type === "app"}
          iconName={element.app_icon}
        />

        {/* MAIN LABEL — expands */}
        <label xalign={0} label={element.app_name} />

        {/* ARGUMENT — fixed alignment */}
        <label
          class="argument"
          hexpand
          xalign={0}
          label={element.app_arg || ""}
        />

        <label
          class="description"
          xalign={1}
          ellipsize={Pango.EllipsizeMode.END}
          label={element.app_description || ""}
        />
      </box>
    );
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
  const rows = (
    <box
      visible={Results((results) => results.length > 0)}
      class="results"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
    >
      <For each={Results}>
        {(result, i) => (
          <AppButton
            element={result}
            className={i.peek() === 0 ? "checked" : ""}
          />
        )}
      </For>
    </box>
  );
  return (
    <scrolledwindow hexpand vexpand heightRequest={500}>
      <box orientation={Gtk.Orientation.VERTICAL}>
        <Help />
        {rows}
      </box>
    </scrolledwindow>
  );
};

const History = () => {
  return (
    <scrolledwindow vexpand hexpand>
      <box
        valign={Gtk.Align.START}
        class={"history"}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
        $={(self) => {
          execAsync(`mkdir -p ./cache/launcher`).then(() => {
            const history = readJSONFile("./cache/launcher/history.json");
            if (Array.isArray(history)) setHistory(history);
          });
        }}
      >
        <label
          visible={history((h) => h.length == 0)}
          label={"Empty History"}
        ></label>
        <For each={history}>
          {(appName) => {
            const app = apps.fuzzy_query(appName)[0];

            if (app) {
              return (
                <button
                  onClicked={() => {
                    launchApp({
                      app_name: app.name,
                      app_icon: app.iconName,
                      app_launch: () => {
                        app.launch();
                        if (parentWindowRef) {
                          parentWindowRef.hide();
                        }
                      },
                    });
                  }}
                >
                  <box spacing={10}>
                    <image iconName={app.iconName} />
                    <label xalign={0} label={app.name} />
                  </box>
                </button>
              );
            } else {
              return <box />; // or some placeholder for missing app
            }
          }}
        </For>
      </box>
    </scrolledwindow>
  );
};

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => (
  <Astal.Window
    gdkmonitor={monitor}
    name={`app-launcher-${getMonitorName(monitor)}`}
    namespace="app-launcher"
    application={app}
    exclusivity={Astal.Exclusivity.EXCLUSIVE}
    keymode={Astal.Keymode.EXCLUSIVE}
    layer={Astal.Layer.TOP}
    margin={globalMargin} // top right bottom left
    visible={false}
    $={(self) => {
      parentWindowRef = self;
      setup(self);

      // focus on visible
      self.connect("notify::visible", () => {
        if (self.visible) {
          entryWidget.grab_focus();
        }
      });
    }}
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
    <box class="app-launcher" spacing={10}>
      <QuickApps />
      <box class={"main"} orientation={Gtk.Orientation.VERTICAL} spacing={10}>
        <ResultsDisplay />
        <Entry />
      </box>
      <History />
    </box>
  </Astal.Window>
);
