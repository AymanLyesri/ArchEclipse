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
import { Astal, Gtk } from "ags/gtk4";

import { notify } from "../utils/notification";
import {
  emptyWorkspace,
  globalMargin,
  globalSettings,
  globalTransition,
} from "../variables";

const apps = new Apps.Apps();

import Hyprland from "gi://AstalHyprland";
import { getMonitorName } from "../utils/monitor";
import { LauncherApp } from "../interfaces/app.interface";
import { customApps } from "../constants/app.constants";
import { quickApps } from "../constants/app.constants";
import { For } from "gnim";
import { Gdk } from "ags/gtk4";
import { convert, isConversionQuery } from "../utils/convert";
import Pango from "gi://Pango";
import GLib from "gi://GLib";
const hyprland = Hyprland.get_default();

const MAX_ITEMS = 10;
const MAX_HISTORY_ENTRIES = 10;
const LAUNCHER_HISTORY_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/app-history.json`;
const CLIPBOARD_HISTORY_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/clipboard-history.json`;
const CLIPBOARD_PREVIEW_MAX_LENGTH = 120;

type ClipboardHistoryEntry = {
  id?: number;
  timestamp?: number;
  type?: string;
  content?: string;
  mimeType?: string;
};

type NormalizedClipboardEntry = {
  id: number;
  timestamp: number;
  type: string;
  content: string;
  mimeType: string;
  preview: string;
  searchableText: string;
};

const [Results, setResults] = createState<LauncherApp[]>([]);

const [history, setHistory] = createState<string[]>([]);

const normalizeHistory = (entries: unknown): string[] => {
  if (!Array.isArray(entries)) return [];

  const normalized: string[] = [];
  for (const entry of entries) {
    if (typeof entry !== "string") continue;
    const appName = entry.trim();
    if (!appName || normalized.includes(appName)) continue;

    normalized.push(appName);
    if (normalized.length >= MAX_HISTORY_ENTRIES) break;
  }

  return normalized;
};

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

const stripHtml = (value: string): string =>
  value
    .replace(/<[^>]*>/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const truncateText = (value: string, maxLength: number): string => {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, maxLength - 1)}…`;
};

const parseClipboardQuery = (value: string): string | null => {
  const match = value.match(/^cb(?:\s+(.*))?$/i);
  if (!match) return null;
  return (match[1] || "").trim();
};

const normalizeClipboardEntries = (
  entries: unknown,
): NormalizedClipboardEntry[] => {
  if (!Array.isArray(entries)) return [];

  return entries
    .map((entry: ClipboardHistoryEntry, index) => {
      const content =
        typeof entry.content === "string" ? entry.content.trim() : "";
      if (!content) return null;

      const type =
        typeof entry.type === "string" && entry.type.trim()
          ? entry.type.trim().toLowerCase()
          : "text";
      const mimeType =
        typeof entry.mimeType === "string" && entry.mimeType.trim()
          ? entry.mimeType.trim().toLowerCase()
          : "text/plain";

      const fallbackTimestamp = Math.max(0, entries.length - index);
      const timestamp =
        typeof entry.timestamp === "number"
          ? entry.timestamp
          : fallbackTimestamp;
      const id = typeof entry.id === "number" ? entry.id : fallbackTimestamp;

      const isImage = type === "image" || mimeType.startsWith("image/");
      const basename = GLib.path_get_basename(content) || content;

      const textPreview = mimeType.includes("html")
        ? stripHtml(content)
        : content;
      const preview = isImage
        ? truncateText(`🖼 ${basename}`, CLIPBOARD_PREVIEW_MAX_LENGTH)
        : truncateText(textPreview || "(empty)", CLIPBOARD_PREVIEW_MAX_LENGTH);

      const searchableText = isImage
        ? `${content} ${basename} ${mimeType} ${type} image`
        : `${textPreview} ${content} ${mimeType} ${type} text html`;

      return {
        id,
        timestamp,
        type,
        content,
        mimeType,
        preview,
        searchableText: searchableText.toLowerCase(),
      };
    })
    .filter((entry): entry is NormalizedClipboardEntry => Boolean(entry))
    .sort((a, b) => b.timestamp - a.timestamp)
    .slice(0, MAX_ITEMS);
};

const copyClipboardEntry = (entry: NormalizedClipboardEntry) => {
  const isImage = entry.type === "image" || entry.mimeType.startsWith("image/");

  if (isImage) {
    const quotedPath = `'${entry.content.replace(/'/g, `'"'"'`)}'`;
    const quotedMime = `'${entry.mimeType.replace(/'/g, `'"'"'`)}'`;

    execAsync([
      "bash",
      "-lc",
      `if [ -f ${quotedPath} ]; then wl-copy --type ${quotedMime} < ${quotedPath}; else echo \"Missing image file\"; exit 1; fi`,
    ])
      .then(() => {
        notify({
          summary: "Clipboard",
          body: isImage
            ? `Copied image (${entry.mimeType}) to clipboard`
            : `Copied text to clipboard`,
        });
      })
      .catch((err) => {
        notify({
          summary: "Clipboard",
          body: err instanceof Error ? err.message : String(err),
        });
      });

    return;
  }

  execAsync(["wl-copy", "--type", entry.mimeType, entry.content]).catch(
    (err) => {
      notify({
        summary: "Clipboard",
        body: err instanceof Error ? err.message : String(err),
      });
    },
  );
};

let parentWindowRef: Gtk.Window | null = null;

const QuickApps = () => {
  return (
    <scrolledwindow vexpand>
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

          const clipboardQuery = parseClipboardQuery(text.trim());
          if (clipboardQuery !== null) {
            const clipboardEntries = normalizeClipboardEntries(
              readJSONFile(CLIPBOARD_HISTORY_PATH, []),
            );
            const searchTerm = clipboardQuery.toLowerCase();
            const filteredEntries = searchTerm
              ? clipboardEntries.filter((entry) =>
                  entry.searchableText.includes(searchTerm),
                )
              : clipboardEntries;

            setResults(
              filteredEntries.map((entry) => ({
                app_name: entry.preview,
                app_description: `${entry.mimeType} • ${entry.type}`,
                app_type: "clipboard",
                app_launch: () => copyClipboardEntry(entry),
              })),
            );
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
              `bash ${GLib.get_home_dir()}/.config/ags/scripts/translate.sh '${text
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
            const emojis: [] = readJSONFile(
              `${GLib.get_home_dir()}/.config/ags/assets/emojis/emojis.json`,
            );
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
                  app_launch: () => launchAndRecord(app),
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
    "cb / cb ...": "clipboard history (text/html/image)",
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
          <label label={command} class="command" hexpand wrap xalign={0} />
          <label
            label={description}
            class="description"
            hexpand
            wrap
            xalign={1}
          />
        </box>
      ))}
    </box>
  );
};

const AppButton = ({
  element,
  className,
}: {
  element: LauncherApp;
  className?: string;
}) => {
  const buttonContent = (element: LauncherApp) => (
    <box
      spacing={10}
      hexpand
      tooltipMarkup={`${element.app_name}\n<b>${element.app_description}</b>`}
    >
      {/* ICON SLOT — always present */}

      <image visible={element.app_type === "app"} iconName={element.app_icon} />

      {/* MAIN LABEL — expands */}
      <label
        xalign={0}
        label={element.app_name}
        ellipsize={Pango.EllipsizeMode.END}
      />

      {/* ARGUMENT — fixed alignment */}
      <label
        class="argument"
        hexpand
        xalign={0}
        label={element.app_arg || ""}
      />

      {/* <label
          class="description"
          xalign={1}
          ellipsize={Pango.EllipsizeMode.END}
          label={element.app_description || ""}
        /> */}
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

const ResultsDisplay = () => {
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
    <scrolledwindow hexpand vexpand>
      <box orientation={Gtk.Orientation.VERTICAL}>
        <Help />
        {rows}
      </box>
    </scrolledwindow>
  );
};

const History = () => {
  return (
    <scrolledwindow vexpand>
      <box
        valign={Gtk.Align.START}
        class={"history"}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
        $={(self) => {
          execAsync(
            `mkdir -p ${GLib.get_home_dir()}/.config/ags/cache/launcher`,
          ).then(() => {
            const loadedHistory = normalizeHistory(
              readJSONFile(LAUNCHER_HISTORY_PATH, []),
            );

            const validHistory = loadedHistory.filter(
              (appName) => getInstalledAppByName(appName) !== null,
            );

            setHistory(validHistory);

            if (validHistory.length !== loadedHistory.length) {
              persistHistory(validHistory);
            }
          });
        }}
      >
        <label
          visible={history((h) => h.length == 0)}
          label={"Empty History"}
        ></label>
        <For each={history}>
          {(appName) => {
            const _app = getInstalledAppByName(appName);

            if (_app) {
              const app: LauncherApp = {
                app_name: _app.name,
                app_icon: _app.iconName,
                app_description: _app.description,
                app_type: "app",
                app_launch: () => {
                  launchAndRecord(_app);
                },
              };
              return <AppButton element={app} />;
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
    exclusivity={Astal.Exclusivity.IGNORE}
    keymode={Astal.Keymode.EXCLUSIVE}
    layer={Astal.Layer.TOP}
    margin={globalMargin} // top right bottom left
    visible={false}
    $={(self) => {
      parentWindowRef = self;
      setup(self);

      (self as any).entry = entryWidget; // expose entry widget for external access (e.g. from notifications)

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
      <box
        class={"main"}
        hexpand
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
      >
        <ResultsDisplay />
        <Entry />
      </box>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
        <QuickApps />
        <History />
      </box>
    </box>
  </Astal.Window>
);
