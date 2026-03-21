import { createState } from "ags";
import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib";
import { For } from "gnim";

import { readJSONFile, writeJSONFile } from "../../utils/json";
import { quickApps } from "../../constants/app.constants";
import { LauncherApp } from "../../interfaces/app.interface";

const QUICK_APP_HISTORY_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/quick-app-history.json`;

const quickAppNames = new Set(quickApps.map((app) => app.app_name));
const quickAppIndex = new Map(
  quickApps.map((app, index) => [app.app_name, index]),
);

const normalizeQuickAppHistory = (entries: unknown): string[] => {
  if (!Array.isArray(entries)) return [];

  const normalized: string[] = [];
  for (const entry of entries) {
    if (typeof entry !== "string") continue;
    const appName = entry.trim();
    if (
      !appName ||
      normalized.includes(appName) ||
      !quickAppNames.has(appName)
    ) {
      continue;
    }

    normalized.push(appName);
    if (normalized.length >= quickApps.length) break;
  }

  return normalized;
};

const sortQuickAppsByHistory = (entries: string[]): LauncherApp[] => {
  const rank = new Map(entries.map((name, index) => [name, index]));

  return [...quickApps].sort((a, b) => {
    const aRank = rank.get(a.app_name) ?? Number.POSITIVE_INFINITY;
    const bRank = rank.get(b.app_name) ?? Number.POSITIVE_INFINITY;

    if (aRank === bRank) {
      return (
        (quickAppIndex.get(a.app_name) ?? Number.POSITIVE_INFINITY) -
        (quickAppIndex.get(b.app_name) ?? Number.POSITIVE_INFINITY)
      );
    }

    return aRank - bRank;
  });
};

const persistQuickAppHistory = (entries: string[]) => {
  writeJSONFile(QUICK_APP_HISTORY_PATH, entries);
};

const QuickApps = ({ onAfterLaunch }: { onAfterLaunch: () => void }) => {
  const [quickAppHistory, setQuickAppHistory] = createState<string[]>([]);
  const [orderedQuickApps, setOrderedQuickApps] =
    createState<LauncherApp[]>(quickApps);

  const touchQuickAppHistory = (appName: string) => {
    if (!quickAppNames.has(appName)) return;

    const nextHistory = normalizeQuickAppHistory([
      appName,
      ...quickAppHistory.peek().filter((name) => name !== appName),
    ]);

    setQuickAppHistory(nextHistory);
    setOrderedQuickApps(sortQuickAppsByHistory(nextHistory));
    persistQuickAppHistory(nextHistory);
  };

  return (
    <scrolledwindow vexpand>
      <box
        class="quick-apps results"
        spacing={5}
        orientation={Gtk.Orientation.VERTICAL}
        valign={Gtk.Align.START}
        $={() => {
          const rawHistory = readJSONFile(QUICK_APP_HISTORY_PATH, []);
          const loadedHistory = normalizeQuickAppHistory(rawHistory);

          setQuickAppHistory(loadedHistory);
          setOrderedQuickApps(sortQuickAppsByHistory(loadedHistory));

          const hasInvalidEntries =
            Array.isArray(rawHistory) &&
            loadedHistory.length !== rawHistory.length;

          if (hasInvalidEntries) {
            persistQuickAppHistory(loadedHistory);
          }
        }}
      >
        <For each={orderedQuickApps}>
          {(app) => (
            <Gtk.Button
              hexpand
              class="quick-app"
              onClicked={(self) => {
                const monitorName = (self.get_root() as any).monitorName;
                touchQuickAppHistory(app.app_name);
                app.app_launch(monitorName);
                onAfterLaunch();
              }}
            >
              <box spacing={5}>
                <label widthRequest={24} label={app.app_icon} />
                <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
                  <label label={app.app_name} xalign={0} />
                  <label
                    visible={!!app.app_description}
                    class="description"
                    label={app.app_description || ""}
                  />
                </box>
              </box>
            </Gtk.Button>
          )}
        </For>
      </box>
    </scrolledwindow>
  );
};

export default QuickApps;
