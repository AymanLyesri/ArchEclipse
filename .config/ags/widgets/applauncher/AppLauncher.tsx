import { createState } from "ags";
import Apps from "gi://AstalApps";

import { writeJSONFile } from "../../utils/json";
import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";

import { globalMargin } from "../../variables";

const apps = new Apps.Apps();

import { getMonitorName } from "../../utils/monitor";
import { LauncherApp } from "../../interfaces/app.interface";
import { Gdk } from "ags/gtk4";
import GLib from "gi://GLib";
import AppsPane from "./Apps";
import QuickApps from "./QuickApps";
import AppHistory, { normalizeHistory } from "./AppHistory";

const LAUNCHER_HISTORY_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/app-history.json`;

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

let entryWidget: any;

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
        if (self.visible) {
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
      <AppsPane
        results={Results}
        setResults={setResults}
        onLaunch={launchApp}
        onLaunchInstalledApp={launchAndRecord}
        onEntryReady={(entry) => {
          entryWidget = entry;
        }}
      />
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
