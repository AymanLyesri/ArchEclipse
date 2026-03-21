import { Accessor } from "ags";
import { execAsync } from "ags/process";
import { Gtk } from "ags/gtk4";
import Apps from "gi://AstalApps";
import GLib from "gi://GLib";
import Hyprland from "gi://AstalHyprland";
import Pango from "gi://Pango";
import { For } from "gnim";
import KeyBind from "../KeyBind";
import { LauncherApp } from "../../interfaces/app.interface";
import { readJSONFile } from "../../utils/json";
import { arithmetic, containsOperator } from "../../utils/arithmetic";
import {
  containsProtocolOrTLD,
  formatToURL,
  getDomainFromURL,
} from "../../utils/url";
import { customApps } from "../../constants/app.constants";
import { convert, isConversionQuery } from "../../utils/convert";
import { notify } from "../../utils/notification";

const apps = new Apps.Apps();
const hyprland = Hyprland.get_default();

const MAX_ITEMS = 10;
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
      `if [ -f ${quotedPath} ]; then wl-copy --type ${quotedMime} < ${quotedPath}; else echo "Missing image file"; exit 1; fi`,
    ])
      .then(() => {
        notify({
          summary: "Clipboard",
          body: isImage
            ? `Copied image (${entry.mimeType}) to clipboard`
            : "Copied text to clipboard",
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
    <Gtk.Button
      hexpand={true}
      class={className}
      onClicked={() => {
        onLaunch(element);
      }}
    >
      {buttonContent(element)}
    </Gtk.Button>
  );
};

const Help = ({ results }: { results: Accessor<LauncherApp[]> }) => {
  const helpTips: {
    command: string;
    description: string;
    keybind?: string[];
  }[] = [
    {
      command: "cb / cb ...",
      description: "clipboard history (text/html/image)",
      keybind: ["SUPER", "SHIFT", "v"],
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

const LauncherEntry = ({
  onEntryReady,
  onTextChanged,
  onActivate,
}: {
  onEntryReady: (entry: Gtk.Entry) => void;
  onTextChanged: (text: string) => void;
  onActivate: () => void;
}) => (
  <Gtk.Entry
    hexpand={true}
    placeholderText="Search for an app, emoji, translate, url, or do some math..."
    $={(self) => {
      onEntryReady(self);
      return self;
    }}
    onChanged={(self: any) => {
      onTextChanged(self.get_text());
    }}
    onActivate={onActivate}
  />
);

const AppsPane = ({
  results,
  setResults,
  onLaunch,
  onLaunchInstalledApp,
  onEntryReady,
}: {
  results: Accessor<LauncherApp[]>;
  setResults: (results: LauncherApp[]) => void;
  onLaunch: (app: LauncherApp) => void;
  onLaunchInstalledApp: (application: Apps.Application) => void;
  onEntryReady: (entry: Gtk.Entry) => void;
}) => {
  let debounceTimer: any;
  let args: string[];

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

        if (isConversionQuery(text)) {
          const conversions = await convert(text);
          setResults(
            conversions.map((conv) => ({
              app_name: `${conv.formatted}`,
              app_icon: "󰟛",
              app_desc: `Converted from ${conv.original}`,
              app_launch: () => execAsync(`wl-copy "${conv.formatted}"`),
            })),
          );
          return;
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
        } else if (args[0].includes("emoji")) {
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
        } else if (containsOperator(args[0])) {
          setResults([
            {
              app_name: arithmetic(text),
              app_launch: () => execAsync(`wl-copy ${arithmetic(text)}`),
            },
          ]);
        } else if (containsProtocolOrTLD(args[0])) {
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
        } else {
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
                app_launch: () => onLaunchInstalledApp(app),
              })),
          );
          if (results.get().length === 0) {
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
    <box
      class={"main"}
      hexpand
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
    >
      <LauncherEntry
        onEntryReady={onEntryReady}
        onTextChanged={handleEntryChanged}
        onActivate={() => {
          if (results.get().length > 0) {
            onLaunch(results.get()[0]);
          }
        }}
      />
      <scrolledwindow hexpand vexpand>
        <ResultsList results={results} onLaunch={onLaunch} />
      </scrolledwindow>
    </box>
  );
};

export default AppsPane;
