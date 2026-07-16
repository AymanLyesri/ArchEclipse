import { createState, createComputed, For, With } from "ags";
import { execAsync } from "ags/process";
import { monitorFile } from "ags/file";
import app from "ags/gtk4/app";
import { Gtk } from "ags/gtk4";
import { Astal } from "ags/gtk4";
import { notify } from "../utils/notification";
import {
  focusedWorkspace,
  globalSettings,
  setGlobalSetting,
} from "../variables";
import { getMonitorName } from "../utils/monitor";
import Picture from "./Picture";
import Gio from "gi://Gio";
import { Progress } from "./Progress";
import { timeout } from "ags/time";
import { Gdk } from "ags/gtk4";
import { formatKiloBytes } from "../utils/bytes";
import { readJson } from "../utils/json";
import GLib from "gi://GLib";
import {
  Setting,
  weScalingChoices,
  weClampChoices,
  wallpaperModeChoices,
  applyCurrentWallpapers,
  controlWE,
} from "./leftPanel/components/SettingsWidget";

import { WallpaperEngineProperties } from "./WallpaperEngineProperties";

export const WALLPAPER_ENGINE_CATEGORY = "wallpaperengine";

export function toThumbnailPath(file: string) {
  // Wallpaper Engine items live under the Steam Workshop folder; their thumbnail
  // is cached by id under thumbnails/wallpaperengine/<id>.jpg.
  const we = file.match(/\/workshop\/content\/431960\/([^/]+)\//);
  if (we)
    return `${GLib.get_home_dir()}/.config/ags/cache/thumbnails/wallpaperengine/${we[1]}.jpg`;

  return file
    .replace("/.config/wallpapers/", "/.config/ags/cache/thumbnails/")
    .replace(/\.[^/.]+$/, ".jpg");
}

// A Wallpaper Engine item is identified by its Workshop content path.
export function isWallpaperEngine(file: string) {
  return file.includes("/workshop/content/431960/");
}

// Human-friendly label for category keys (folder names) shown in the selector.
export function prettyCategory(category: string) {
  if (category === WALLPAPER_ENGINE_CATEGORY) return "Wallpaper Engine";
  return category;
}

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;
  const [selectedWorkspaceId, setSelectedWorkspaceId] = createState<number>(1);

  // progress status
  const [progressStatus, setProgressStatus] = createState<
    "loading" | "error" | "success" | "idle"
  >("idle");

  const targetTypes = ["workspace", "primary", "sddm", "lockscreen"];
  const [targetType, setTargetType] = createState<string>("workspace");

  // Values are string[] for categories, plus a reserved "__types" object map
  // (preview path -> WE project type) — hence `any`.
  const [wallpapers, setWallpapers] = createState<Record<string, any>>({});

  // Category keys for the selector, excluding reserved "__"-prefixed metadata keys.
  const wallpaperCategories = (w: Record<string, any>) =>
    Object.keys(w).filter((k) => !k.startsWith("__"));

  // Badge text for a tile: the WE project type (scene/web/video/application) for
  // Wallpaper Engine items, otherwise an image/video label from the file extension.
  function wallpaperBadge(path: string): string {
    if (isWallpaperEngine(path)) {
      return (wallpapers() as any).__types?.[path] || "scene";
    }
    const ext = (path.split(".").pop() || "").toLowerCase();
    return ["mp4", "webm", "mkv", "mov", "gif"].includes(ext) ? "video" : "image";
  }

  const selectedWallpapers = createComputed(() => {
    return (
      wallpapers()[
        globalSettings(({ wallpaperSwitcher }) => wallpaperSwitcher.category)()
      ] || []
    );
  });

  // Raw JSON of the last successful scan; used to skip a full re-render (rebuilding
  // every tile/Picture) when an open or folder event produced no actual change.
  let lastWallpapersJson = "";
  async function FetchWallpapers() {
    try {
      // Added await so that the function actually waits for the bash script to complete.
      const output = await execAsync(
        `bash ${GLib.get_home_dir()}/.config/ags/scripts/get-wallpapers.sh`,
      );
      if (output === lastWallpapersJson) return; // nothing changed -> no re-render
      lastWallpapersJson = output;
      const wallpapers = readJson(output);
      setWallpapers(wallpapers);
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
      print("Error fetching wallpapers: " + String(err));
    }
  }

  // Coalesce bursts of filesystem events (a single Workshop download touches many
  // files) into one rescan so we don't run get-wallpapers.sh dozens of times.
  let rescanTimer: ReturnType<typeof timeout> | null = null;
  function scheduleRescan() {
    rescanTimer?.cancel();
    rescanTimer = timeout(750, () => {
      rescanTimer = null;
      FetchWallpapers();
    });
  }

  const [currentWallpapers, setCurrentWallpapers] = createState<string[]>([]);

  async function FetchCurrentWallpapers(monitorName: string) {
    try {
      execAsync(
        `bash ${GLib.get_home_dir()}/.config/ags/scripts/get-wallpapers.sh --current ${monitorName}`,
      )
        .then((output) => {
          const wallpapers = JSON.parse(output).map((item: string) =>
            String(item),
          );
          setCurrentWallpapers(wallpapers);
        })
        .catch((err) => {
          notify({ summary: "Error", body: String(err) });
          print("Error fetching current wallpapers: " + String(err));
        });
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
      print("Error fetching current wallpapers: " + String(err));
    }
  }

  // Main Display Component
  function Display() {
    const getCurrentWorkspaces = (
      <box>
        <With value={currentWallpapers}>
          {(wallpapers) => {
            return (
              <box
                hexpand={true}
                vexpand={true}
                halign={Gtk.Align.CENTER}
                spacing={10}
              >
                {wallpapers.map((wallpaper, workspaceId) => (
                  <button
                    class={focusedWorkspace((workspace) => {
                      const i = workspace?.id || 1;
                      return i === workspaceId + 1
                        ? "wallpaper-button focused"
                        : "wallpaper-button";
                    })}
                    css={wallpaper == "" ? "background-color: black" : ""}
                    onClicked={(self) => {
                      setTargetType("workspace");
                      setSelectedWorkspaceId(workspaceId + 1);
                    }}
                    tooltipMarkup={`Set wallpaper for <b>Workspace ${workspaceId + 1}</b>`}
                  >
                    {wallpaper == "" ? (
                      <label
                        class="no-wallpaper"
                        label="No Wallpaper"
                        halign={Gtk.Align.CENTER}
                        valign={Gtk.Align.CENTER}
                      />
                    ) : (
                      <Picture
                        class="wallpaper"
                        file={toThumbnailPath(wallpaper)}
                        info={[
                          String(workspaceId + 1),
                          wallpaper.split(".").pop() || "unknown",
                        ]}
                      ></Picture>
                    )}
                  </button>
                ))}
              </box>
            );
          }}
        </With>
      </box>
    );

    const allWallpapersDisplay = (
      <Gtk.ScrolledWindow
        hscrollbarPolicy={Gtk.PolicyType.ALWAYS}
        vscrollbarPolicy={Gtk.PolicyType.NEVER}
        hexpand
        vexpand
      >
        <box halign={Gtk.Align.CENTER}>
          <box class="all-wallpapers" spacing={5} hexpand>
            <For each={selectedWallpapers}>
              {(wallpaper) => {
                const handleLeftClick = (self: Gtk.Button) => {
                  setProgressStatus("loading");
                  const target = targetType.peek();
                  const monitorName = (self.get_root() as any).monitorName;
                  // In Global mode the "workspace" target writes the single
                  // global wallpaper; otherwise the selected workspace.
                  const slot =
                    globalSettings.peek().wallpaper.mode.value === "global"
                      ? "global"
                      : selectedWorkspaceId.peek();
                  const command = {
                    sddm: `pkexec bash -c 'sed -i "s|^background=.*|background=${wallpaper}|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf'`,
                    lockscreen: `bash -c "mkdir -p $HOME/.config/wallpapers/lockscreen && cp ${wallpaper} $HOME/.config/wallpapers/lockscreen/wallpaper"`,
                    workspace: `bash -c "$HOME/.config/hypr/wallpaper-daemon/set-wallpaper.sh ${slot} ${monitorName} ${wallpaper}"`,
                    primary: `bash -c "$HOME/.config/hypr/wallpaper-daemon/set-wallpaper.sh primary ${monitorName} ${wallpaper}"`,
                  }[target];

                  execAsync(command!)
                    .then(() => {
                      FetchCurrentWallpapers(
                        (self.get_root() as any).monitorName,
                      );
                    })
                    .finally(() => {
                      setProgressStatus("success");
                    })
                    .catch((err) => {
                      setProgressStatus("error");
                      notify({ summary: "Error", body: String(err) });
                      throw err;
                    });
                };

                const handleRightClick = () => {
                  // Never delete Wallpaper Engine items from disk (they belong to
                  // Steam); manage those through the Steam Workshop instead.
                  if (isWallpaperEngine(wallpaper)) {
                    notify({
                      summary: "Wallpaper Engine",
                      body: "Unsubscribe from this item in Steam to remove it.",
                    });
                    return;
                  }
                  setProgressStatus("loading");
                  execAsync(
                    `bash -c "rm -f '${toThumbnailPath(
                      wallpaper,
                    )}' && rm -f '${wallpaper}'"`,
                  )
                    .then(() =>
                      notify({
                        summary: "Success",
                        body: "Wallpaper deleted successfully!",
                      }),
                    )
                    .catch((err) => {
                      setProgressStatus("error");
                      notify({ summary: "Error", body: String(err) });
                      throw err;
                    })
                    .finally(() => {
                      FetchWallpapers();
                      setProgressStatus("success");
                    });
                };

                const fileSize = (path: string) => {
                  const file = Gio.File.new_for_path(path);

                  try {
                    const info = file.query_info(
                      "standard::size",
                      Gio.FileQueryInfoFlags.NONE,
                      null,
                    );

                    const size = info.get_size(); // bytes
                    return formatKiloBytes(size / 1024); // convert to KB and format
                  } catch (e) {
                    // logError(e);
                    print("Error getting file size: " + String(e));
                    return "N/A";
                  }
                };

                return (
                  <button
                    class="wallpaper-button preview"
                    onClicked={handleLeftClick}
                    $={(self) => {
                      const gesture = new Gtk.GestureClick({
                        button: 3, // Right click only
                      });

                      gesture.connect("pressed", () => {
                        handleRightClick();
                      });

                      self.add_controller(gesture);
                    }}
                    tooltipMarkup={targetType(
                      (type) =>
                        "Click to set as <b>" +
                        type +
                        "</b> wallpaper.\nRight-click to delete." +
                        // get filename from path
                        `\n ${wallpaper.split("/").pop()}` +
                        // file size
                        `\n Size: ${fileSize(wallpaper)}`,
                    )}
                  >
                    <Picture
                      class="wallpaper"
                      file={toThumbnailPath(wallpaper)}
                      info={[wallpaperBadge(wallpaper)]}
                    ></Picture>
                  </button>
                ) as Gtk.Widget;
              }}
            </For>
          </box>
        </box>
      </Gtk.ScrolledWindow>
    );

    const resetButton = (
      <button
        valign={Gtk.Align.CENTER}
        class="reload-wallpapers"
        label="󰑐"
        tooltipMarkup={`Reload <b>Wallpaper Daemon</b>`}
        onClicked={() => {
          setProgressStatus("loading");
          execAsync('bash -c "$HOME/.config/hypr/wallpaper-daemon/reload.sh"')
            .then(FetchWallpapers)
            .finally(() => setProgressStatus("success"))
            .catch((err) => {
              setProgressStatus("error");
              notify({ summary: "Error", body: String(err) });
            });
        }}
      />
    );

    const randomButton = (
      <button
        valign={Gtk.Align.CENTER}
        class="random-wallpaper"
        label=""
        tooltipMarkup={`Set a <b>Random</b> wallpaper`}
        onClicked={(self) => {
          setProgressStatus("loading");
          const randomWallpaper =
            selectedWallpapers.peek()[
              Math.floor(Math.random() * selectedWallpapers.peek().length)
            ];
          const slot =
            globalSettings.peek().wallpaper.mode.value === "global"
              ? "global"
              : selectedWorkspaceId.peek();
          execAsync(
            `bash -c "$HOME/.config/hypr/wallpaper-daemon/set-wallpaper.sh ${slot} ${
              (self.get_root() as any).monitorName
            } ${randomWallpaper}"`,
          )
            .finally(() => {
              FetchCurrentWallpapers((self.get_root() as any).monitorName);
              setProgressStatus("success");
            })
            .catch((err) => {
              setProgressStatus("error");
              notify({ summary: "Error", body: String(err) });
            });
        }}
      />
    );

    const targetButtons = (
      <box class="targets" hexpand={true} halign={Gtk.Align.CENTER}>
        {targetTypes.map((type) => (
          <togglebutton
            valign={Gtk.Align.CENTER}
            class={type}
            label={type}
            active={targetType((t) => t === type)}
            onToggled={({ active }) => {
              if (active) setTargetType(type);
            }}
          />
        ))}
      </box>
    );

    const selectedWorkspaceLabel = (
      <label
        class="selected-workspace"
        label={createComputed(
          () =>
            `Wallpaper -> ${targetType()} ${
              targetType() === "workspace" ? selectedWorkspaceId() : ""
            }`,
        )}
        $={(self) =>
          createComputed([selectedWorkspaceId, targetType]).subscribe(() => {
            self.add_css_class("ping");
            timeout(500, () => {
              self.remove_css_class("ping");
            });
          })
        }
      />
    );

    const addWallpaper = (
      <button
        label=""
        class="upload"
        tooltipMarkup={`Add a <b>New Custom Wallpaper</b>`}
        onClicked={async () => {
          setProgressStatus("loading");
          try {
            const filename = await execAsync(
              'zenity --file-selection --title="Select Wallpaper" --file-filter="Images (png, jpg, webp, gif, mp4) | *.png *.jpg *.jpeg *.webp *.gif *.mp4"',
            );

            if (!filename || filename.trim() === "") {
              setProgressStatus("idle");
              return;
            }

            const cleanPath = filename.trim();

            print(`Selected file path: ${cleanPath}`);

            const homeDir = GLib.get_home_dir();
            const targetDir = homeDir + "/.config/wallpapers/custom";
            const basename = cleanPath.split("/").pop() || "wallpaper";
            const targetPath = targetDir + "/" + basename;

            print(`Target directory: ${targetDir}`);
            print(`Target path: ${targetPath}`);

            await execAsync(`mkdir -p ${JSON.stringify(targetDir)}`);

            print(
              `About to copy ${JSON.stringify(cleanPath)} to ${JSON.stringify(targetPath)}`,
            );
            await execAsync(
              `cp -- ${JSON.stringify(cleanPath)} ${JSON.stringify(targetPath)}`,
            );
            print(`File copy completed`);

            // --- ADDED BLOCK: Force preview generation ---
            try {
              const thumbDir = homeDir + "/.config/ags/cache/thumbnails/custom";
              const thumbPath =
                thumbDir + "/" + basename.replace(/\.[^/.]+$/, ".jpg");
              await execAsync(`mkdir -p ${JSON.stringify(thumbDir)}`);

              // If it's a video, extract the first frame using ffmpeg. If it's an image, extract it using magick.
              if (cleanPath.toLowerCase().match(/\.(mp4|webm)$/)) {
                await execAsync(
                  `ffmpeg -i ${JSON.stringify(targetPath)} -vframes 1 -vf "scale=500:-1" -y ${JSON.stringify(thumbPath)}`,
                );
              } else {
                await execAsync(
                  `magick ${JSON.stringify(targetPath)} -resize "500x500^" -gravity center -extent 500x500 ${JSON.stringify(thumbPath)}`,
                );
              }
              print(`Thumbnail generated successfully at: ${thumbPath}`);
            } catch (thumbErr) {
              print(
                `Warning: Failed to generate thumbnail: ${String(thumbErr)}`,
              );
            }
            // --- END OF ADDED BLOCK ---

            notify({
              summary: "Success",
              body: "Wallpaper added successfully!",
            });

            setProgressStatus("success");

            await FetchWallpapers();

            timeout(2000, () => {
              setProgressStatus("idle");
            });
          } catch (err) {
            setProgressStatus("idle");

            const errorStr = String(err);
            if (!errorStr.includes("exit status 1")) {
              setProgressStatus("error");
              print(`Error adding wallpaper: ${errorStr}`);
              notify({
                summary: "Error",
                body: errorStr,
              });
            }
          }
        }}
      />
    );

    const displayColorScheme = (
      <box
        class="color-scheme"
        spacing={10}
        tooltipMarkup={`Dynamic Colors using <b>Pywal</b>`}
      >
        {/* from 1 to 7 */}
        {[1, 2, 3, 4, 5, 6, 7].map((color, index) => (
          <label
            label={""}
            class="color"
            css={`
              color: var(--color${color});
            `}
          ></label>
        ))}
      </box>
    );

    const categorySelector = (
      <menubutton class="category-selector" halign={Gtk.Align.CENTER}>
        <label
          label={globalSettings(({ wallpaperSwitcher }) =>
            prettyCategory(wallpaperSwitcher.category),
          )}
        />
        <popover>
          <With value={wallpapers}>
            {(wallpapers) => (
              <box
                orientation={Gtk.Orientation.VERTICAL}
                spacing={5}
                class={"popover"}
              >
                {wallpaperCategories(wallpapers).map((category) => (
                  <button
                    class={"category"}
                    label={prettyCategory(category)}
                    onClicked={() =>
                      setGlobalSetting("wallpaperSwitcher.category", category)
                    }
                  />
                ))}
              </box>
            )}
          </With>
        </popover>
      </menubutton>
    );

    const modeSelector = (
      <Setting
        compact
        keyChanged="wallpaper.mode"
        setting={globalSettings.peek().wallpaper.mode}
        choices={wallpaperModeChoices}
        callBack={applyCurrentWallpapers}
      />
    );

    // Playback speed applies to video/GIF wallpapers (via mpvpaper). Wallpaper
    // Engine scenes have no speed control in the engine yet.
    const speedSelector = (
      <Setting
        compact
        keyChanged="wallpaper.playbackSpeed"
        setting={globalSettings.peek().wallpaper.playbackSpeed}
        callBack={(v) => controlWE(`speed ${v}`)}
      />
    );

    const actions = (
      <box
        class="actions"
        hexpand={true}
        halign={Gtk.Align.CENTER}
        spacing={10}
      >
        {targetButtons}
        {selectedWorkspaceLabel}
        {modeSelector}
        {speedSelector}
        {displayColorScheme}
        {categorySelector}
        {randomButton}
        {resetButton}
        {addWallpaper}
        <Progress
          status={progressStatus}
          transitionType={Gtk.RevealerTransitionType.SWING_RIGHT}
        />
      </box>
    );

    // Live Wallpaper Engine controls, revealed only while the Wallpaper Engine
    // category is selected. Changing a value re-renders the active live
    // wallpaper(s) immediately. Full set of options lives in Settings.
    const wallpaperEngineOptions = (
      <revealer
        transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
        revealChild={globalSettings(
          ({ wallpaperSwitcher }) =>
            wallpaperSwitcher.category === WALLPAPER_ENGINE_CATEGORY,
        )}
      >
        <box
          class="wallpaper-engine-options"
          halign={Gtk.Align.CENTER}
          spacing={20}
        >
          <Setting
            compact
            keyChanged="wallpaperEngine.scaling"
            setting={globalSettings.peek().wallpaperEngine.scaling}
            choices={weScalingChoices}
            callBack={(v) => controlWE(`scaling ${v}`)}
          />
          <Setting
            compact
            keyChanged="wallpaperEngine.clamping"
            setting={globalSettings.peek().wallpaperEngine.clamping}
            choices={weClampChoices}
            callBack={(v) => controlWE(`clamp ${v}`)}
          />
          <Setting
            compact
            keyChanged="wallpaperEngine.fps"
            setting={globalSettings.peek().wallpaperEngine.fps}
            callBack={(v) => controlWE(`set fps ${v}`)}
          />
          <Setting
            compact
            keyChanged="wallpaperEngine.volume"
            setting={globalSettings.peek().wallpaperEngine.volume}
            callBack={(v) => controlWE(`volume ${v}`)}
          />
          <Setting
            compact
            keyChanged="wallpaperEngine.mute"
            setting={globalSettings.peek().wallpaperEngine.mute}
            callBack={(v) => controlWE(`mute ${v ? 1 : 0}`)}
          />
          <WallpaperEngineProperties monitorName={monitorName} />
        </box>
      </revealer>
    );

    return (
      <box
        class="wallpaper-switcher"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={20}
      >
        <box
          visible={globalSettings(
            ({ wallpaper }) => wallpaper.mode.value !== "global",
          )}
        >
          {getCurrentWorkspaces}
        </box>
        <box
          class="global-indicator"
          halign={Gtk.Align.CENTER}
          visible={globalSettings(
            ({ wallpaper }) => wallpaper.mode.value === "global",
          )}
        >
          <label label="󰸉  Global — one wallpaper for all workspaces" />
        </box>
        {actions}
        {wallpaperEngineOptions}
        {allWallpapersDisplay}
      </box>
    );
  }
  return (
    <window
      gdkmonitor={monitor}
      namespace="wallpaper-switcher"
      name={`wallpaper-switcher-${monitorName}`}
      application={app}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
      exclusivity={Astal.Exclusivity.IGNORE}
      layer={Astal.Layer.OVERLAY}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.BOTTOM |
        Astal.WindowAnchor.RIGHT
      }
      $={async (self) => {
        setup(self);
        (self as any).monitorName = monitorName;
        FetchWallpapers();
        FetchCurrentWallpapers(monitorName);

        // Auto-discover: rescan every time the switcher is opened (Super+W), so
        // wallpapers subscribed/added since AGS started show up without a restart.
        self.connect("notify::visible", () => {
          if (self.visible) {
            FetchWallpapers();
            FetchCurrentWallpapers(monitorName);
          }
        });

        // Live auto-discovery: watch the wallpaper sources and rescan when their
        // contents change — e.g. Steam finishing a Workshop download while the
        // switcher is open, or a file dropped into ~/.config/wallpapers.
        const watchPaths = [
          `${GLib.get_home_dir()}/.local/share/Steam/steamapps/workshop/content/431960`,
          // Subscription manifest: unsubscribing updates this even when Steam leaves the content
          // folder on disk, so watching it makes removals show up live.
          `${GLib.get_home_dir()}/.local/share/Steam/steamapps/workshop/appworkshop_431960.acf`,
          `${GLib.get_home_dir()}/.config/wallpapers`,
        ];
        for (const path of watchPaths) {
          try {
            if (GLib.file_test(path, GLib.FileTest.EXISTS)) {
              monitorFile(path, () => scheduleRescan());
            }
          } catch (err) {
            print("WallpaperSwitcher: could not watch " + path + ": " + String(err));
          }
        }

        // Initialize selected workspace
        focusedWorkspace.subscribe(() => {
          const workspace = focusedWorkspace.peek();
          if (workspace) {
            setSelectedWorkspaceId(workspace.id);
          }
        });
      }}
    >
      <Display />
    </window>
  );
};
