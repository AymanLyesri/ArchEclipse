import { Accessor, createState } from "ags";
import Apps from "gi://AstalApps";

import { writeJSONFile } from "../../utils/json";
import { Gtk } from "ags/gtk4";
import Hyprland from "gi://AstalHyprland";
import Pango from "gi://Pango";
import { createBinding, For, With } from "gnim";

import KeyBind from "../KeyBind";
import { customApps } from "../../constants/app.constants";
import { notify } from "../../utils/notification";
import { getAppsResults, parseAppsQuery } from "./utilities/AppsList";
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

import Mpris from "gi://AstalMpris";
import Player from "../Player";
import { searchActivate, searchQuery } from "../bar/sub-components/SearchBar";
const mpris = Mpris.get_default();

const LAUNCHER_HISTORY_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/app-history.json`;
const MAX_ITEMS = 10;

export function AppButton({
  element,
  className,
  onLaunch,
}: {
  element: LauncherApp;
  className?: string;
  onLaunch: (app: LauncherApp) => void;
}) {
  if (element.app_type === "header") {
    return (
      <box class="app-header" spacing={5} hexpand>
        <label xalign={0} label={element.app_name} class="header-title" />
      </box>
    );
  }

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
}

/**
 * Launcher content. No longer a top-level Astal.Window — this is now
 * mounted inside a Gtk.Popover parented to the bar's search entry
 * (see SearchBar in Bar.tsx). Focus, show/hide, and click-outside are
 * all handled by the Popover (autohide) instead of manual GestureClick
 * + layer-shell keymode juggling.
 */
export default ({ onLaunched }: { onLaunched: () => void }) => {
  const [Results, setResults] = createState<LauncherApp[]>([]);
  const [history, setHistory] = createState<string[]>([]);

  function getInstalledAppByName(appName: string): Apps.Application | null {
    return (
      apps
        .fuzzy_query(appName)
        .find((candidate: Apps.Application) => candidate.name === appName) ||
      null
    );
  }

  function persistHistory(nextHistory: string[]) {
    writeJSONFile(LAUNCHER_HISTORY_PATH, nextHistory);
  }

  function touchHistory(appName: string) {
    const nextHistory = normalizeHistory([
      appName,
      ...history.peek().filter((name) => name !== appName),
    ]);

    setHistory(nextHistory);
    persistHistory(nextHistory);
  }

  function launchAndRecord(application: Apps.Application) {
    application.launch();
    touchHistory(application.name);
  }

  let debounceTimer: any;
  let args: string[];

  function launchApp(app: LauncherApp) {
    app.app_launch();
    const shouldCloseOnLaunch = app.app_close_on_launch ?? true;

    setResults([]);

    if (!shouldCloseOnLaunch) {
      return;
    }

    onLaunched();
  }

  function Help({ results }: { results: Accessor<LauncherApp[]> }) {
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
        command: "apps ...",
        description: "list all installed applications",
        keybind: ["SUPER", "A"],
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
  }

  function ResultsList({
    results,
    onLaunch,
  }: {
    results: Accessor<LauncherApp[]>;
    onLaunch: (app: LauncherApp) => void;
  }) {
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
  }

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
          setResults(getClipboardResults(clipboardQuery));
          return;
        }

        const noteQuery = parseNoteQuery(text);
        if (noteQuery !== null) {
          setResults(
            getNoteResults(noteQuery, MAX_ITEMS, {
              prefillEntry: (value: string) => {
                // handled via searchQuery state now
              },
            }),
          );
          return;
        }

        const appsQuery = parseAppsQuery(text);
        if (appsQuery !== null) {
          setResults(getAppsResults(appsQuery, launchAndRecord));
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

  const players = createBinding(mpris, "players");

  return (
    <box
      class="app-launcher"
      spacing={10}
      $={(self) => {
        // React to global search text/activate, scoped to this monitor
        searchQuery.subscribe(() => {
          handleEntryChanged(searchQuery.get());
        });

        searchActivate.subscribe(() => {
          const first = Results.get()[0];
          if (first) launchApp(first);
        });

        // Reload app db + prune stale history whenever this popover
        // becomes visible (mirrors old notify::visible logic)
        self.connect("map", () => {
          apps.reload();

          const currentHistory = history.get();
          const validHistory = currentHistory.filter(
            (appName) => apps.fuzzy_query(appName).length > 0,
          );

          if (validHistory.length !== currentHistory.length) {
            setHistory(validHistory);
            persistHistory(validHistory);
          }
        });
      }}
    >
      <box class={"left"}>
        <With value={players}>
          {(players) =>
            players.length > 0 ? (
              <Player
                width={300}
                player={
                  mpris.players.find(
                    (player) =>
                      player.playbackStatus === Mpris.PlaybackStatus.PLAYING,
                  ) || mpris.players[0]
                }
              />
            ) : (
              <box></box>
            )
          }
        </With>
      </box>
      <box
        class={"center"}
        hexpand
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        widthRequest={500}
      >
        <scrolledwindow hexpand vexpand>
          <ResultsList results={Results} onLaunch={launchApp} />
        </scrolledwindow>
      </box>
      <box
        class={"right"}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        widthRequest={300}
      >
        <QuickApps onAfterLaunch={onLaunched} />
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
  );
};
