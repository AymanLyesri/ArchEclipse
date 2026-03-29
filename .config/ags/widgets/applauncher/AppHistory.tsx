import { Accessor } from "ags";
import { execAsync } from "ags/process";
import { Gtk } from "ags/gtk4";
import Apps from "gi://AstalApps";
import GLib from "gi://GLib";
import { For } from "gnim";

import { readJSONFile } from "../../utils/json";
import { LauncherApp } from "../../interfaces/app.interface";
import { AppButton } from "./AppLauncher";

const MAX_HISTORY_ENTRIES = 10;
const LAUNCHER_HISTORY_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/app-history.json`;

export const normalizeHistory = (entries: unknown): string[] => {
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

const AppHistory = ({
  history,
  setHistory,
  persistHistory,
  getInstalledAppByName,
  launchAndRecord,
  onLaunch,
}: {
  history: Accessor<string[]>;
  setHistory: (history: string[]) => void;
  persistHistory: (history: string[]) => void;
  getInstalledAppByName: (appName: string) => Apps.Application | null;
  launchAndRecord: (application: Apps.Application) => void;
  onLaunch: (app: LauncherApp) => void;
}) => {
  return (
    <scrolledwindow vexpand>
      <box
        valign={Gtk.Align.START}
        class={"history"}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
        $={() => {
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
          visible={history((entries) => entries.length === 0)}
          label={"Empty History"}
        />
        <For each={history}>
          {(appName) => {
            const app = getInstalledAppByName(appName);
            if (!app) return <box />;

            const launcherApp: LauncherApp = {
              app_name: app.name,
              app_icon: app.iconName,
              app_description: app.description,
              app_type: "app",
              app_launch: () => {
                launchAndRecord(app);
              },
            };

            return <AppButton element={launcherApp} onLaunch={onLaunch} />;
          }}
        </For>
      </box>
    </scrolledwindow>
  );
};

export default AppHistory;
