import { Accessor, createState } from "ags";
import Apps from "gi://AstalApps";

import { writeJSONFile } from "../../utils/json";
import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import Hyprland from "gi://AstalHyprland";
import Pango from "gi://Pango";
import { For } from "gnim";

import { globalMargin } from "../../variables";
import KeyBind from "../KeyBind";
import { customApps } from "../../constants/app.constants";
import { notify } from "../../utils/notification";
import {
  getClipboardResults,
  parseClipboardQuery,
} from "./utilities/Clipboard";
import { getEmojiResults, parseEmojiQuery } from "./utilities/Emojies";
import {
  getTranslateResults,
  parseTranslateQuery,
} from "./utilities/Translate";
import {
  getConversionResults,
  isConversionQuery,
} from "./utilities/Conversion";
import {
  getArithmeticResults,
  isArithmeticQuery,
} from "./utilities/Arithmetic";
import { getUrlResults, isUrlQuery } from "./utilities/Url";
import { getNoteResults, parseNoteQuery } from "./utilities/Note";

const apps = new Apps.Apps();
const hyprland = Hyprland.get_default();

import { getMonitorName } from "../../utils/monitor";
import { LauncherApp } from "../../interfaces/app.interface";
import { Gdk } from "ags/gtk4";
import GLib from "gi://GLib";
import QuickApps from "./QuickApps";
import AppHistory, { normalizeHistory } from "./AppHistory";

const LAUNCHER_HISTORY_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/app-history.json`;
const MAX_ITEMS = 10;

const [Results, setResults] = createState<LauncherApp[]>([]);

const [history, setHistory] = createState<string[]>([]);

const getInstalledAppByName = (appName: string): Apps.Application | null => {
  return (
    apps
      .fuzzy_query(appName)
      .find((candidate: Apps.Application) => candidate.name === appName) || null
  );
};

const persistHistory = (nextHistory: string[]) => {
  writeJSONFile(LAUNCHER_HISTORY_PATH, nextHistory);
};

const touchHistory = (appName: string) => {
  const nextHistory = normalizeHistory([
    appName,
    ...history.peek().filter((name) => name !== appName),
  ]);

  setHistory(nextHistory);
  persistHistory(nextHistory);
};

const launchAndRecord = (application: Apps.Application) => {
  application.launch();
  touchHistory(application.name);
};

let parentWindowRef: Gtk.Window | null = null;

let entryWidget: Gtk.TextView | null = null;

export const AppButton = ({
  element,
  className,
  onLaunch,
}: {
  element: LauncherApp;
  className?: string;
  onLaunch: (app: LauncherApp) => void;
}) => {
  const buttonContent = (appElement: LauncherApp) => (
    <box
      spacing={10}
      hexpand
      tooltipMarkup={`${appElement.app_name}\n<b>${appElement.app_description}</b>`}
    >
      <image
        visible={appElement.app_type === "app"}
        iconName={appElement.app_icon}
      />

      <box orientation={Gtk.Orientation.VERTICAL} spacing={5} hexpand>
        <box>
          <label
            xalign={0}
            label={appElement.app_name}
            ellipsize={Pango.EllipsizeMode.END}
          />

          <label
            class="argument"
            hexpand
            xalign={0}
            label={appElement.app_arg || ""}
          />
        </box>

        <label
          visible={!!appElement.app_description}
          class="description"
          xalign={0}
          ellipsize={Pango.EllipsizeMode.END}
          label={appElement.app_description || ""}
        />
      </box>
    </box>
  );

  return (
    <box class="app-row" spacing={5} hexpand>
      <Gtk.Button
        hexpand={true}
        class={className}
        onClicked={() => {
          onLaunch(element);
        }}
      >
        {buttonContent(element)}
      </Gtk.Button>

      <box
        class="app-actions"
        spacing={6}
        visible={Boolean(element.app_actions?.length)}
      >
        {element.app_actions?.map((action) => (
          <Gtk.Button
            class={`${action.className || ""}`.trim()}
            tooltipText={action.tooltip || action.label}
            onClicked={() => action.onClick()}
          >
            <label label={action.label} />
          </Gtk.Button>
        ))}
      </box>
    </box>
  );
};

const Help = ({ results }: { results: Accessor<LauncherApp[]> }) => {
  const helpTips: {
    command: string;
    description: string;
    keybind?: string[];
  }[] = [
    {
      command: "cb ...",
      description: "clipboard history (text/html/image)",
      keybind: ["SUPER", "SHIFT", "v"],
    },
    {
      command: "note ...",
      description: "add/list/edit/remove notes",
      keybind: ["SUPER", "SHIFT", "n"],
    },
    {
      command: "emoji ...",
      description: "search emojis",
      keybind: ["SUPER", "."],
    },
    {
      command: "... ...",
      description: "open with argument",
    },
    {
      command: "translate .. > ..",
      description: "translate into (en,fr,es,de,pt,ru,ar...)",
    },
    {
      command: "... .com OR https://...",
      description: "open link",
    },
    {
      command: "..*/+-..",
      description: "arithmetics",
    },
    {
      command: "100c to f / 10kg in lb",
      description: "unit conversion (temp/weight/length/volume/speed)",
    },
  ];

  return (
    <box
      visible={results((entries) => entries.length <= 0)}
      class={"help"}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
    >
      {helpTips.map(({ command, description, keybind }) => (
        <box spacing={10}>
          <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
            <label label={command} class="command" hexpand wrap xalign={0} />
            <label
              label={description}
              class="description"
              hexpand
              wrap
              xalign={0}
            />
          </box>
          {keybind && <KeyBind bindings={keybind} />}
        </box>
      ))}
    </box>
  );
};

const ResultsList = ({
  results,
  onLaunch,
}: {
  results: Accessor<LauncherApp[]>;
  onLaunch: (app: LauncherApp) => void;
}) => {
  return (
    <box orientation={Gtk.Orientation.VERTICAL}>
      <Help results={results} />
      <box
        visible={results((entries) => entries.length > 0)}
        class="results"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
      >
        <For each={results}>
          {(result, index) => (
            <AppButton
              element={result}
              className={index.peek() === 0 ? "checked" : ""}
              onLaunch={onLaunch}
            />
          )}
        </For>
      </box>
    </box>
  );
};

const EmptyEntry = () => {
  if (entryWidget) {
    entryWidget.buffer.text = "";
  }
  setResults([]);
};

const launchApp = (app: LauncherApp) => {
  app.app_launch();
  const shouldCloseOnLaunch = app.app_close_on_launch ?? true;

  if (!shouldCloseOnLaunch) {
    return;
  }

  // hideWindow(`app-launcher-${monitorName.get()}`);
  if (parentWindowRef) {
    parentWindowRef.hide();
  }
  EmptyEntry();
};

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  let debounceTimer: any;
  let args: string[];

  const getInputText = () => entryWidget?.buffer.text || "";

  const setInputText = (value: string) => {
    if (!entryWidget) return;
    entryWidget.buffer.text = value;
    const iter = entryWidget.buffer.get_end_iter();
    entryWidget.buffer.place_cursor(iter);
    entryWidget.grab_focus();
  };

  const handleEntryChanged = (text: string) => {
    if (debounceTimer) {
      clearTimeout(debounceTimer);
    }

    debounceTimer = setTimeout(async () => {
      try {
        if (!text || text.trim() === "") {
          setResults([]);
          return;
        }

        const clipboardQuery = parseClipboardQuery(text);
        if (clipboardQuery !== null) {
          setResults(getClipboardResults(clipboardQuery, MAX_ITEMS));
          return;
        }

        const noteQuery = parseNoteQuery(text);
        if (noteQuery !== null) {
          setResults(
            getNoteResults(noteQuery, MAX_ITEMS, {
              prefillEntry: (value: string) => {
                setInputText(value);
              },
            }),
          );
          return;
        }

        if (isConversionQuery(text)) {
          setResults(await getConversionResults(text));
          return;
        }

        args = text.trim().split(/\s+/);
        const translateQuery = parseTranslateQuery(text);
        const emojiQuery = parseEmojiQuery(text);

        if (args[0].includes(">")) {
          const filteredCommands = customApps.filter((customApp) =>
            customApp.app_name
              .toLowerCase()
              .includes(text.replace(">", "").trim().toLowerCase()),
          );
          setResults(filteredCommands);
        } else if (translateQuery) {
          setResults(
            await getTranslateResults(
              translateQuery.sourceText,
              translateQuery.language,
            ),
          );
        } else if (emojiQuery !== null) {
          setResults(getEmojiResults(emojiQuery));
        } else if (isArithmeticQuery(text)) {
          setResults(getArithmeticResults(text));
        } else if (isUrlQuery(text)) {
          setResults(getUrlResults(text));
        } else {
          setResults(
            apps
              .fuzzy_query(args.shift()!)
              .slice(0, MAX_ITEMS)
              .map((application: Apps.Application) => ({
                app_name: application.name,
                app_icon: application.iconName,
                app_description: application.description,
                app_type: "app",
                app_arg: args.join(" "),
                app_launch: () => launchAndRecord(application),
              })),
          );

          if (Results.get().length === 0) {
            setResults([
              {
                app_name: `Try ${text} in terminal`,
                app_icon: "󰋖",
                app_launch: () =>
                  hyprland.message_async(
                    `dispatch exec kitty 'bash -c "${text}"'`,
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
    }, 100);
  };

  return (
    <Astal.Window
      gdkmonitor={monitor}
      name={`app-launcher-${getMonitorName(monitor)}`}
      namespace="app-launcher"
      application={app}
      // exclusivity={Astal.Exclusivity.IGNORE}
      keymode={Astal.Keymode.EXCLUSIVE}
      layer={Astal.Layer.TOP}
      margin={globalMargin} // top right bottom left
      visible={false}
      anchor={Astal.WindowAnchor.TOP}
      $={(self) => {
        parentWindowRef = self;
        setup(self);

        (self as any).entry = entryWidget; // expose entry widget for external access (e.g. from notifications)

        // add monitor name to window
        (self as any).monitorName = getMonitorName(monitor);

        // focus on visible
        self.connect("notify::visible", () => {
          if (self.visible && entryWidget) {
            entryWidget.grab_focus();
            self.add_css_class("app-launcher-visible");
          } else {
            self.remove_css_class("app-launcher-visible");
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
        <box
          class={"main"}
          hexpand
          orientation={Gtk.Orientation.VERTICAL}
          spacing={10}
        >
          <Gtk.TextView
            hexpand={true}
            wrapMode={Gtk.WrapMode.WORD_CHAR}
            topMargin={8}
            bottomMargin={8}
            leftMargin={10}
            rightMargin={10}
            tooltipMarkup={
              "Search apps and utilities\n<b>Enter</b> launch first result\n<b>Shift+Enter</b> new line"
            }
            $={(self) => {
              entryWidget = self;
              self.buffer.connect("changed", () => {
                handleEntryChanged(getInputText());
              });
              return self;
            }}
          >
            <Gtk.EventControllerKey
              onKeyPressed={(
                _,
                keyval: number,
                _keycode: number,
                state: number,
              ) => {
                const isEnter =
                  keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter;
                if (!isEnter) return false;

                const isShiftPressed =
                  (state & Gdk.ModifierType.SHIFT_MASK) !== 0;
                if (isShiftPressed) return false;

                if (Results.get().length > 0) {
                  launchApp(Results.get()[0]);
                }
                return true;
              }}
            />
          </Gtk.TextView>
          <scrolledwindow hexpand vexpand>
            <ResultsList results={Results} onLaunch={launchApp} />
          </scrolledwindow>
        </box>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
          <QuickApps
            onAfterLaunch={() => {
              if (parentWindowRef) {
                parentWindowRef.hide();
              }
            }}
          />
          <AppHistory
            history={history}
            setHistory={setHistory}
            persistHistory={persistHistory}
            getInstalledAppByName={getInstalledAppByName}
            launchAndRecord={launchAndRecord}
            onLaunch={launchApp}
          />
        </box>
      </box>
    </Astal.Window>
  );
};
