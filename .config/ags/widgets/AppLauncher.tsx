import { bind, exec, execAsync, Variable } from "astal";
import Apps from "gi://AstalApps";

import { readJson, readJSONFile } from "../utils/json";
import { arithmetic, containsOperator } from "../utils/arithmetic";
import {
  containsProtocolOrTLD,
  formatToURL,
  getDomainFromURL,
} from "../utils/url";
import { App, Astal, Gdk, Gtk } from "astal/gtk3";
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
const hyprland = Hyprland.get_default();

const MAX_ITEMS = 10;

// Store per-monitor state
const monitorStates = new Map<string, {
  Results: Variable<LauncherApp[]>;
  debounceTimer: any;
  args: string[];
}>();

const getMonitorState = (monitorName: string) => {
  if (!monitorStates.has(monitorName)) {
    monitorStates.set(monitorName, {
      Results: Variable<LauncherApp[]>([]),
      debounceTimer: null,
      args: [],
    });
  }
  return monitorStates.get(monitorName)!;
};
const QuickApps = (monitorName: string, Results: Variable<LauncherApp[]>) => {
  const apps = (
    <revealer
      transition_type={Gtk.RevealerTransitionType.SLIDE_DOWN}
      transition_duration={globalTransition}
      revealChild={bind(Results).as((results) => results.length === 0)}
      child={
        <scrollable
          heightRequest={quickApps.length * 40}
          child={
            <box className="quick-apps" spacing={5} vertical>
              {quickApps.map((app, index) => (
                <button
                  hexpand
                  className="quick-app"
                  onClicked={() => {
                    app.app_launch();
                    hideWindow(`app-launcher-${monitorName}`);
                  }}
                  child={
                    <box spacing={5}>
                      <label className="icon" label={app.app_icon} />
                      <label label={app.app_name} />
                    </box>
                  }
                ></button>
              ))}
            </box>
          }
        ></scrollable>
      }
    ></revealer>
  );

  return <box className="quick-launcher" spacing={5} child={apps}></box>;
};

const helpCommands = {
  "Press <Escape>": "to reset input",
  "... ...": "open with argument",
  "translate .. > ..": "translate .. > (en,fr,es,de,pt,ru,ar...)",
  "... .com OR https://...": "open link",
  "..*/+-..": "arithmetics",
  "emoji ...": "search emojis",
};

const Help = (
  <box className="help" spacing={5} vertical>
    {Object.entries(helpCommands).map(([command, explanation]) => (
      <box hexpand homogeneous>
        <label
          className="command"
          label={command}
          halign={Gtk.Align.END}
          hexpand
        />
        <label className="separator" label="=>>" halign={Gtk.Align.CENTER} />
        <label
          className="explanation"
          label={explanation}
          halign={Gtk.Align.START}
          hexpand
        />
      </box>
    ))}
  </box>
);

const createEntry = (monitorName: string, Results: Variable<LauncherApp[]>, state: { debounceTimer: any; args: string[] }, launchApp: (app: LauncherApp) => void) => (
  <entry
    hexpand={true}
    placeholder_text="Search for an app, emoji, translate, url, or do some math..."
    onChanged={async ({ text }) => {
      if (state.debounceTimer) {
        clearTimeout(state.debounceTimer);
      }

      state.debounceTimer = setTimeout(async () => {
        try {
          if (!text || text.trim() === "") {
            Results.set([]);
            return;
          }
          state.args = text.split(" ");

          if (state.args[0].includes(">")) {
            const filteredCommands = customApps.filter((app) =>
              app.app_name
                .toLowerCase()
                .includes(text.replace(">", "").trim().toLowerCase())
            );
            Results.set(filteredCommands);
          } else if (state.args[0].includes("translate")) {
            const language = text.includes(">")
              ? text.split(">")[1].trim()
              : "en";
            const translation = await execAsync(
              `bash ./scripts/translate.sh '${text
                .split(">")[0]
                .replace("translate", "")
                .trim()}' '${language}'`
            );
            Results.set([
              {
                app_name: translation,
                app_launch: () => execAsync(`wl-copy ${translation}`),
              },
            ]);
          } // Handle emojis
          else if (state.args[0].includes("emoji")) {
            const emojis: [] = readJSONFile("./assets/emojis/emojis.json");
            const filteredEmojis = emojis.filter(
              (emoji: { app_tags: string; app_name: string }) =>
                emoji.app_tags
                  .toLowerCase()
                  .includes(text.replace("emoji", "").trim())
            );
            Results.set(
              filteredEmojis.map((emoji: { app_name: string }) => ({
                app_name: emoji.app_name,
                app_icon: emoji.app_name,
                app_type: "emoji",
                app_launch: () => execAsync(`wl-copy ${emoji.app_name}`),
              }))
            );
          }
          // handle URL
          else if (containsProtocolOrTLD(state.args[0])) {
            Results.set([
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
          else if (containsOperator(state.args[0])) {
            Results.set([
              {
                app_name: arithmetic(text),
                app_launch: () => execAsync(`wl-copy ${arithmetic(text)}`),
              },
            ]);
          }
          // Handle apps
          else {
            Results.set(
              apps
                .fuzzy_query(state.args.shift()!)
                .slice(0, MAX_ITEMS)
                .map((app) => ({
                  app_name: app.name,
                  app_icon: app.iconName,
                  app_type: "app",
                  app_arg: state.args.join(" "),
                  app_launch: () =>
                    !state.args.join("")
                      ? app.launch()
                      : hyprland.message_async(
                          `dispatch exec ${app.executable} ${state.args.join(" ")}`,
                          () => {}
                        ),
                }))
            );
            if (Results.get().length === 0) {
              Results.set([
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
      }, 100); // 100ms delay
    }}
    onActivate={() => {
      if (Results.get().length > 0) {
        launchApp(Results.get()[0]);
      }
    }}
  />
);

const createEmptyEntry = (entry: any, Results: Variable<LauncherApp[]>) => () => {
  entry.set_text("");
  Results.set([]);
};

const createLaunchApp = (monitorName: string, emptyEntry: () => void) => (app: LauncherApp) => {
  app.app_launch();
  hideWindow(`app-launcher-${monitorName}`);
  emptyEntry();
};

const createOrganizeResults = (launchApp: (app: LauncherApp) => void, Results: Variable<LauncherApp[]>) => (results: LauncherApp[]) => {
  const buttonContent = (element: LauncherApp) => (
    <box
      spacing={10}
      halign={element.app_type === "emoji" ? Gtk.Align.CENTER : Gtk.Align.START}
    >
      {element.app_type === "app" ? <icon icon={element.app_icon} /> : <box />}
      <label label={element.app_name} />
      <label className="argument" label={element.app_arg || ""} />
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
      <button
        hexpand={true}
        className={className}
        child={buttonContent(element)}
        onClicked={() => {
          launchApp(element);
        }}
      />
    );
  };

  if (results.length === 0) return <box />;

  const rows = (
    <box className="results" vertical={true} spacing={5}>
      {results.map((result, i) => (
        <AppButton element={result} className={i === 0 ? "checked" : ""} />
      ))}
    </box>
  );

  const maxHeight = 500;
  return (
    <scrollable
      heightRequest={bind(Results).as((results) =>
        results.length * 45 > maxHeight ? maxHeight : results.length * 45
      )}
      child={rows}
    />
  );
};

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;
  const state = getMonitorState(monitorName);
  const { Results } = state;
  
  // Create scoped functions for this monitor
  // We need to create a recursive reference, so we use a wrapper
  let launchAppRef: (app: LauncherApp) => void;
  let entryRef: any;
  
  const emptyEntry = () => {
    if (entryRef) {
      entryRef.set_text("");
      Results.set([]);
    }
  };
  
  launchAppRef = (app: LauncherApp) => {
    app.app_launch();
    hideWindow(`app-launcher-${monitorName}`);
    emptyEntry();
  };
  
  const organizeResults = createOrganizeResults(launchAppRef, Results);
  const ResultsDisplay = <box child={bind(Results).as(organizeResults)} />;
  
  // Create Entry inline to ensure unique instance per monitor
  const Entry = (
    <entry
      hexpand={true}
      placeholder_text="Search for an app, emoji, translate, url, or do some math..."
      setup={(self) => { entryRef = self; }}
      onChanged={async ({ text }) => {
        if (state.debounceTimer) {
          clearTimeout(state.debounceTimer);
        }

        state.debounceTimer = setTimeout(async () => {
          try {
            if (!text || text.trim() === "") {
              Results.set([]);
              return;
            }
            state.args = text.split(" ");

            if (state.args[0].includes(">")) {
              const filteredCommands = customApps.filter((app) =>
                app.app_name
                  .toLowerCase()
                  .includes(text.replace(">", "").trim().toLowerCase())
              );
              Results.set(filteredCommands);
            } else if (state.args[0].includes("translate")) {
              const language = text.includes(">")
                ? text.split(">")[1].trim()
                : "en";
              const translation = await execAsync(
                `bash ./scripts/translate.sh '${text
                  .split(">")[0]
                  .replace("translate", "")
                  .trim()}' '${language}'`
              );
              Results.set([
                {
                  app_name: translation,
                  app_launch: () => execAsync(`wl-copy ${translation}`),
                },
              ]);
            } else if (state.args[0].includes("emoji")) {
              const emojis: [] = readJSONFile("./assets/emojis/emojis.json");
              const filteredEmojis = emojis.filter(
                (emoji: { app_tags: string; app_name: string }) =>
                  emoji.app_tags
                    .toLowerCase()
                    .includes(text.replace("emoji", "").trim())
              );
              Results.set(
                filteredEmojis.map((emoji: { app_name: string }) => ({
                  app_name: emoji.app_name,
                  app_icon: emoji.app_name,
                  app_type: "emoji",
                  app_launch: () => execAsync(`wl-copy ${emoji.app_name}`),
                }))
              );
            } else if (containsProtocolOrTLD(state.args[0])) {
              Results.set([
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
            } else if (containsOperator(state.args[0])) {
              Results.set([
                {
                  app_name: arithmetic(text),
                  app_launch: () => execAsync(`wl-copy ${arithmetic(text)}`),
                },
              ]);
            } else {
              Results.set(
                apps
                  .fuzzy_query(state.args.shift()!)
                  .slice(0, MAX_ITEMS)
                  .map((app) => ({
                    app_name: app.name,
                    app_icon: app.iconName,
                    app_type: "app",
                    app_arg: state.args.join(" "),
                    app_launch: () =>
                      !state.args.join("")
                        ? app.launch()
                        : hyprland.message_async(
                            `dispatch exec ${app.executable} ${state.args.join(" ")}`,
                            () => {}
                          ),
                  }))
              );
              if (Results.get().length === 0) {
                Results.set([
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
        }, 100);
      }}
      onActivate={() => {
        if (Results.get().length > 0) {
          launchAppRef(Results.get()[0]);
        }
      }}
    />
  );
  
  return (
    <window
      gdkmonitor={monitor}
      name={`app-launcher-${monitorName}`}
      namespace="app-launcher"
      application={App}
      anchor={emptyWorkspace.as((empty) =>
        empty ? undefined : Astal.WindowAnchor.TOP | Astal.WindowAnchor.LEFT
      )}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      keymode={Astal.Keymode.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      margin={globalMargin} // top right bottom left
      visible={false}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          hideWindow(`app-launcher-${monitorName}`);
          return true;
        }
      }}
      child={
        <eventbox>
          <box vertical={true} className="app-launcher" spacing={5}>
            {Entry}
            {ResultsDisplay}
            {QuickApps(monitorName, Results)}
            {Help}
          </box>
        </eventbox>
      }
    ></window>
  );
};
