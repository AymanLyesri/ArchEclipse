import { createState, createComputed, For, With } from "ags";
import { execAsync } from "ags/process";
import { monitorFile } from "ags/file";
import app from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { notify } from "../utils/notification";
import {
  focusedWorkspace,
  globalSettings,
  setGlobalSetting,
} from "../variables";
import { getMonitorName } from "../utils/monitor";
import Picture from "./Picture";
import Gio from "gi://Gio";
import GLib from "gi://GLib?version=2.0";
import { Progress } from "./Progress";
import { timeout } from "ags/time";
import { Gdk } from "ags/gtk4";
import { formatKiloBytes } from "../utils/bytes";
import { readJson } from "../utils/json";

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

const FetchWallpapers = async () => {
  try {
    execAsync(
      `bash ${GLib.get_home_dir()}/.config/ags/scripts/get-wallpapers.sh`,
    )
      .then((output) => {
        const wallpapers = readJson(output);
        setWallpapers(wallpapers);
      })
      .catch((err) => {
        notify({ summary: "Error", body: String(err) });
        print("Error fetching wallpapers: " + String(err));
      });
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    print("Error fetching wallpapers: " + String(err));
  }
};

const [currentWallpapers, setCurrentWallpapers] = createState<string[]>([]);

const FetchCurrentWallpapers = (monitorName: string) => {
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
};

export function toThumbnailPath(file: string) {
  return file.replace("/.config/wallpapers/", "/.config/ags/cache/thumbnails/");
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
              spacing={10}>
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
                  tooltipMarkup={`Set wallpaper for <b>Workspace ${workspaceId + 1}</b>`}>
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
                      file={toThumbnailPath(wallpaper)}></Picture>
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
      vexpand>
      <Gtk.Box class="all-wallpapers" spacing={5}>
        <For each={selectedWallpapers}>
          {(wallpaper) => {
            const handleLeftClick = (self: Gtk.Button) => {
              setProgressStatus("loading");
              const target = targetType.peek();
              const command = {
                sddm: `pkexec sh -c 'sed -i "s|^background=.*|background=\"${wallpaper}\"|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf'`,
                lockscreen: `bash -c "mkdir -p $HOME/.config/wallpapers/lockscreen && cp ${wallpaper} $HOME/.config/wallpapers/lockscreen/wallpaper"`,
                workspace: `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceId.peek()} ${
                  (self.get_root() as any).monitorName
                } ${wallpaper}"`,
              }[target];

              execAsync(command!)
                .then(() => {
                  FetchCurrentWallpapers((self.get_root() as any).monitorName);
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
                )}>
                <Picture
                  class="wallpaper"
                  file={toThumbnailPath(wallpaper)}></Picture>
              </button>
            ) as Gtk.Widget;
          }}
        </For>
      </Gtk.Box>
    </Gtk.ScrolledWindow>
  );

  const resetButton = (
    <button
      valign={Gtk.Align.CENTER}
      class="reload-wallpapers"
      label="󰑐"
      tooltipMarkup={`Reload <b>HyprPaper</b>`}
      onClicked={() => {
        execAsync('bash -c "$HOME/.config/hypr/hyprpaper/reload.sh"')
          .finally(FetchWallpapers)
          .catch(notify);
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
          `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceId.peek()} ${
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
      onClicked={async (self) => {
        setProgressStatus("loading");
        const dialog = new Gtk.FileDialog({
          title: "Open Image",
          modal: true,
        });

        // Image filter
        const filter = new Gtk.FileFilter();
        filter.set_name("Images");
        filter.add_mime_type("image/png");
        filter.add_mime_type("image/jpeg");
        filter.add_mime_type("image/webp");
        filter.add_mime_type("image/gif");

        dialog.set_default_filter(filter);

        try {
          const root = self.get_root();
          if (!(root instanceof Gtk.Window)) return;

          const file: Gio.File = await new Promise((resolve, reject) => {
            dialog.open(root, null, (dlg, res) => {
              try {
                resolve(dlg!.open_finish(res));
              } catch (e) {
                reject(e);
              }
            });
          });

          if (!file) return;

          const filename = file.get_path();
          if (!filename) return;

          await execAsync(
            `bash -c "cp '${filename}' $HOME/.config/wallpapers/custom"`,
          );

          notify({
            summary: "Success",
            body: "Wallpaper added successfully!",
          });
          setProgressStatus("success");

          // FetchWallpapers();
        } catch (err) {
          // Gtk.FileDialog throws on cancel — ignore silently
          if (
            err instanceof GLib.Error &&
            err.matches(Gtk.dialog_error_quark(), Gtk.DialogError.CANCELLED)
          )
            return;

          setProgressStatus("error");

          notify({
            summary: "Error",
            body: String(err),
          });
        }
      }}
    />
  );

  const displayColorScheme = (
    <box
      class="color-scheme"
      spacing={10}
      tooltipMarkup={`Dynamic Colors using <b>Pywal</b>`}>
      {/* from 1 to 7 */}
      {[1, 2, 3, 4, 5, 6, 7].map((color, index) => (
        <label
          label={""}
          class="color"
          css={`
            color: var(--color${color});
          `}></label>
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
            <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
              {Object.keys(wallpapers).map((category) => (
                <button
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
    <box class="actions" hexpand={true} halign={Gtk.Align.CENTER} spacing={10}>
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
      spacing={20}>
      {getCurrentWorkspaces}
      {actions}
      {allWallpapersDisplay}
    </box>
  );
}

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;
  return (
    <window
      gdkmonitor={monitor}
      namespace="wallpaper-switcher"
      name={`wallpaper-switcher-${monitorName}`}
      application={app}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
      exclusivity={Astal.Exclusivity.NORMAL}
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
      }}>
      <Display />
    </window>
  );
};

monitorFile("./../wallpapers", async () => FetchWallpapers());
