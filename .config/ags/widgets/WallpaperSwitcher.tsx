import hyprland from "gi://AstalHyprland";
import { createState, createComputed, For } from "ags";
import { exec, execAsync } from "ags/process";
import { monitorFile } from "ags/file";
import app from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { notify } from "../utils/notification";
import { focusedWorkspace, globalTransition } from "../variables";
import { getMonitorName } from "../utils/monitor";
import { hideWindow } from "../utils/window";
import Picture from "./Picture";
import Gio from "gi://Gio";
import { Progress } from "./Progress";
import { timeout } from "ags/time";

// progress status
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");

// State management
const [selectedWorkspaceId, setSelectedWorkspaceId] = createState<number>(0);
const [selectedWorkspaceWidget, setSelectedWorkspaceWidget] =
  createState<any>(null);

const updateSelectedWorkspaceWidget = (workspaceId: number, widget: any) => {
  setSelectedWorkspaceId(workspaceId);
  setSelectedWorkspaceWidget(widget);
};

const targetTypes = ["workspace", "sddm", "lockscreen"];
const [targetType, setTargetType] = createState<string>("workspace");

const [allWallpapers, setAllWallpapers] = createState<string[]>([]);

const FetchWallpapers = async () => {
  try {
    await execAsync("bash ./scripts/wallpaper-to-thumbnail.sh");

    const [defaultWalls, customWalls] = await Promise.all([
      execAsync("bash ./scripts/get-wallpapers.sh --defaults").then(JSON.parse),
      execAsync("bash ./scripts/get-wallpapers.sh --custom").then(JSON.parse),
    ]);

    if (wallpaperType.get()) {
      setAllWallpapers(customWalls);
    } else {
      setAllWallpapers([...defaultWalls, ...customWalls]);
    }
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    print("Error fetching wallpapers: " + String(err));
  }
};

const [wallpaperType, setWallpaperType] = createState<boolean>(false);

wallpaperType.subscribe(() => {
  FetchWallpapers();
});

export function toThumbnailPath(file: string) {
  return file.replace(
    "/.config/wallpapers/",
    "/.config/ags/assets/thumbnails/"
  );
}

// Main Display Component
function Display(monitor: string) {
  const getCurrentWorkspaces = () => {
    const wallpapers: string[] = JSON.parse(
      exec(`bash ./scripts/get-wallpapers.sh --current ${monitor}`) || "[]"
    );

    return wallpapers.map((wallpaper, key) => {
      const workspaceId = key + 1;

      return (
        <button
          class={focusedWorkspace((workspace) => {
            const i = workspace?.id || 1;
            return i === workspaceId
              ? "wallpaper-button focused"
              : "wallpaper-button";
          })}
          onClicked={(self) => {
            setTargetType("workspace");
            updateSelectedWorkspaceWidget(workspaceId, self);
          }}
          $={(self) => {
            const i = focusedWorkspace.get()?.id || 1;
            if (i === workspaceId) {
              updateSelectedWorkspaceWidget(workspaceId, self);
            }
          }}
        >
          {wallpaper !== "" ? (
            <Picture
              class="wallpaper"
              file={toThumbnailPath(wallpaper)}
            ></Picture>
          ) : (
            <box
              class="wallpaper no-wallpaper"
              vexpand
              hexpand
              tooltipMarkup={`Click to set Wallpaper\n<b>For Workspace ${workspaceId}</b>`}
            >
              <label
                label={"?"}
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.CENTER}
                hexpand
                vexpand
              />
            </box>
          )}
        </button>
      );
    });
  };

  const allWallpapersDisplay = (
    <Gtk.ScrolledWindow
      hscrollbarPolicy={Gtk.PolicyType.ALWAYS}
      vscrollbarPolicy={Gtk.PolicyType.NEVER}
      hexpand
      vexpand
    >
      <Gtk.Box class="all-wallpapers" spacing={5}>
        <For each={allWallpapers}>
          {(wallpaper, key) => {
            return (
              <button
                class="wallpaper-button preview"
                $={(self) => {
                  const gesture = new Gtk.GestureClick({
                    button: 0, // 0 = listen to all buttons
                  });

                  gesture.connect("pressed", (gesture, nPress, x, y) => {
                    if (gesture.get_current_button() === 1) {
                      // Left click
                      setProgressStatus("loading");
                      const target = targetType.get();
                      const command = {
                        sddm: `pkexec sh -c 'sed -i "s|^background=.*|background=\"${wallpaper}\"|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf'`,
                        lockscreen: `bash -c "cp ${wallpaper} $HOME/.config/wallpapers/lockscreen/wallpaper"`,
                        workspace: `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceId.get()} ${wallpaper} ${monitor}"`,
                      }[target];

                      execAsync(command!)
                        .then(() => {
                          const picture = selectedWorkspaceWidget
                            .get()
                            .child.getPicture() as Gtk.Picture;
                          if (target === "workspace" && picture) {
                            picture.file = Gio.File.new_for_path(wallpaper);
                          }
                        })
                        .finally(() => {
                          setProgressStatus("success");
                        })
                        .catch((err) => {
                          setProgressStatus("error");
                          notify({ summary: "Error", body: String(err) });
                          throw err;
                        });
                    } else if (gesture.get_current_button() === 3) {
                      // Right click
                      setProgressStatus("loading");
                      execAsync(
                        `bash -c "rm -f '${toThumbnailPath(
                          wallpaper
                        )}' && rm -f '${wallpaper}'"`
                      )
                        .then(() =>
                          notify({
                            summary: "Success",
                            body: "Wallpaper deleted successfully!",
                          })
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
                    }
                  });

                  self.add_controller(gesture);
                }}
                tooltipMarkup={targetType(
                  (type) =>
                    "Click to set as <b>" +
                    type +
                    "</b> wallpaper.\nRight-click to delete."
                )}
              >
                <Picture
                  class="wallpaper"
                  file={toThumbnailPath(wallpaper)}
                ></Picture>
              </button>
            );
          }}
        </For>
      </Gtk.Box>
    </Gtk.ScrolledWindow>
  );

  let currentWorkspaces = getCurrentWorkspaces();
  focusedWorkspace.subscribe(() => {
    const workspace = focusedWorkspace.get();
    if (workspace) {
      setSelectedWorkspaceId(workspace.id);
      setSelectedWorkspaceWidget(currentWorkspaces[workspace.id - 1]);
    }
  });

  const resetButton = (
    <button
      valign={Gtk.Align.CENTER}
      class="reload-wallpapers"
      label="󰑐"
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
      onClicked={() => {
        setProgressStatus("loading");
        const randomWallpaper =
          allWallpapers.get()[
            Math.floor(Math.random() * allWallpapers.get().length)
          ];
        execAsync(
          `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceId.get()} ${randomWallpaper} ${monitor}"`
        )
          .finally(() => {
            const newWallpaper = JSON.parse(
              exec(`bash ./scripts/get-wallpapers.sh --current ${monitor}`)
            )[selectedWorkspaceId.get() - 1];
            const picture = selectedWorkspaceWidget
              .get()
              .child.getPicture() as Gtk.Picture;
            if (picture) {
              picture.file = Gio.File.new_for_path(newWallpaper);
            }
            setProgressStatus("success");
          })
          .catch((err) => {
            setProgressStatus("error");
            notify({ summary: "Error", body: String(err) });
          });
      }}
    />
  );

  const customToggle = (
    <togglebutton
      valign={Gtk.Align.CENTER}
      class="custom-wallpaper"
      label={wallpaperType((type) => (type ? "Custom" : "All"))}
      onToggled={({ active }) => setWallpaperType(active)}
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
      // class="selected-workspace"
      class={createComputed(
        [selectedWorkspaceId, targetType],
        (workspace, targetType) =>
          // set a timout to add a ping class and remove the class after 2 seconds
          `selected-workspace }`
      )}
      label={createComputed(
        [selectedWorkspaceId, targetType],
        (workspace, targetType) =>
          `Wallpaper -> ${targetType} ${
            targetType === "workspace" ? workspace : ""
          }`
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

  // const addWallpaperButton = (
  //   <button
  //     label=""
  //     class="upload"
  //     onClicked={() => {
  //       let dialog = new Gtk.FileChooserDialog({
  //         title: "Open Image",
  //         action: Gtk.FileChooserAction.OPEN,
  //       });
  //       dialog.add_button("Upload", Gtk.ResponseType.OK);
  //       dialog.add_button("Cancel", Gtk.ResponseType.CANCEL);
  //       let response = dialog.run();
  //       if (response == Gtk.ResponseType.OK) {
  //         let filename = dialog.get_filename();
  //         execAsync(
  //           `bash -c "cp '${filename}' $HOME/.config/wallpapers/custom"`
  //         )
  //           .then(() =>
  //             notify({
  //               summary: "Success",
  //               body: "Wallpaper added successfully!",
  //             })
  //           )
  //           .catch((err) => notify({ summary: "Error", body: String(err) }));
  //       }
  //       dialog.destroy();
  //     }}
  //   />
  // );

  const actions = (
    <box class="actions" hexpand={true} halign={Gtk.Align.CENTER} spacing={10}>
      {targetButtons}
      {selectedWorkspaceLabel}
      {customToggle}
      {randomButton}
      {resetButton}
      <Progress
        status={progressStatus}
        transitionType={Gtk.RevealerTransitionType.SWING_RIGHT}
      />
      {/* {addWallpaperButton} */}
    </box>
  );

  return (
    <box
      class="wallpaper-switcher"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={20}
    >
      <box hexpand={true} vexpand={true} halign={Gtk.Align.CENTER} spacing={10}>
        {currentWorkspaces}
      </box>
      {actions}
      {allWallpapersDisplay}
    </box>
  );
}

// Initialize
FetchWallpapers();
monitorFile("./../wallpapers/custom", FetchWallpapers);

export default (monitor: any) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;
  return (
    <window
      gdkmonitor={monitor}
      namespace="wallpaper-switcher"
      name={`wallpaper-switcher-${monitorName}`}
      application={app}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.BOTTOM |
        Astal.WindowAnchor.RIGHT
      }
    >
      {Display(monitorName)}
    </window>
  );
};
