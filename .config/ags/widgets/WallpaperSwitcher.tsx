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

export function toThumbnailPath(file: string) {
  return file
    .replace("/.config/wallpapers/", "/.config/ags/cache/thumbnails/")
    .replace(/\.[^/.]+$/, ".jpg");
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

  const targetTypes = ["workspace", "sddm", "lockscreen"];
  const [targetType, setTargetType] = createState<string>("workspace");

  const [wallpapers, setWallpapers] = createState<Record<string, string[]>>({});

  const selectedWallpapers = createComputed(() => {
    return (
      wallpapers()[
        globalSettings(({ wallpaperSwitcher }) => wallpaperSwitcher.category)()
      ] || []
    );
  });

  async function FetchWallpapers() {
    try {
      // Added await so that the function actually waits for the bash script to complete.
      const output = await execAsync(
        `bash ${GLib.get_home_dir()}/.config/ags/scripts/get-wallpapers.sh`,
      );
      const wallpapers = readJson(output);
      setWallpapers(wallpapers);
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
      print("Error fetching wallpapers: " + String(err));
    }
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
                  const command = {
                    sddm: `pkexec bash -c 'sed -i "s|^background=.*|background=${wallpaper}|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf'`,
                    lockscreen: `bash -c "mkdir -p $HOME/.config/wallpapers/lockscreen && cp ${wallpaper} $HOME/.config/wallpapers/lockscreen/wallpaper"`,
                    workspace: `bash -c "$HOME/.config/hypr/wallpaper-daemon/set-wallpaper.sh ${selectedWorkspaceId.peek()} ${
                      (self.get_root() as any).monitorName
                    } ${wallpaper}"`,
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
                      info={[wallpaper.split(".").pop() || "unknown"]}
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
          execAsync(
            `bash -c "$HOME/.config/hypr/wallpaper-daemon/set-wallpaper.sh ${selectedWorkspaceId.peek()} ${
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
          label={globalSettings(
            ({ wallpaperSwitcher }) => wallpaperSwitcher.category,
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
                {Object.keys(wallpapers).map((category) => (
                  <button
                    class={"category"}
                    label={category}
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

    const actions = (
      <box
        class="actions"
        hexpand={true}
        halign={Gtk.Align.CENTER}
        spacing={10}
      >
        {targetButtons}
        {selectedWorkspaceLabel}
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

    return (
      <box
        class="wallpaper-switcher"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={20}
      >
        {getCurrentWorkspaces}
        {actions}
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
