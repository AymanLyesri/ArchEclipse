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

const Hyprland = hyprland.get_default();

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
const [wallpaperType, setWallpaperType] = createState<boolean>(false);

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
            (bottomRevealer as any).reveal_child = true;
            updateSelectedWorkspaceWidget(workspaceId, self);
          }}
          $={(self) => {
            const i = focusedWorkspace.get()?.id || 1;
            if (i === workspaceId) {
              updateSelectedWorkspaceWidget(workspaceId, self);
            }
          }}
        >
          <Picture
            class="wallpaper"
            file={toThumbnailPath(wallpaper)}
          ></Picture>
        </button>
      );
    });
  };

  const getAllWallpapers = () => (
    <Gtk.ScrolledWindow
      class="all-wallpapers-scrolledwindow"
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
                onClicked={() => {
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
                        setSelectedWorkspaceWidget(picture);
                      }
                      notify({
                        summary: target,
                        body: `${target} wallpaper changed successfully!`,
                      });
                    })
                    .catch(notify);
                }}
              >
                <Picture
                  class="wallpaper"
                  file={toThumbnailPath(wallpaper)}
                ></Picture>
                {/* <button
                  visible={wallpaperType.get()}
                  class="delete-wallpaper"
                  halign={Gtk.Align.END}
                  valign={Gtk.Align.START}
                  onClicked={() => {
                    execAsync(
                      `bash -c "rm -f '${toThumbnailPath(
                        wallpaper
                      )}' '${wallpaper}'"`
                    )
                      .then(() =>
                        notify({
                          summary: "Success",
                          body: "Wallpaper deleted successfully!",
                        })
                      )
                      .catch((err) =>
                        notify({
                          summary: "Error",
                          body: String(err),
                        })
                      );
                  }}
                /> */}
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
            const widget = selectedWorkspaceWidget.get();
            if (widget) {
              widget.css = `background-image: url('${newWallpaper}');`;
              setSelectedWorkspaceWidget(widget);
            }
          })
          .catch(notify);
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
      class="button selected-workspace"
      label={createComputed(
        [selectedWorkspaceId, targetType],
        (workspace, targetType) =>
          `Wallpaper -> ${targetType} ${
            targetType === "workspace" ? workspace : ""
          }`
      )}
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

  const bottomRevealer = (
    <revealer
      visible={true}
      revealChild={false}
      transitionType={Gtk.RevealerTransitionType.SLIDE_UP}
      transitionDuration={globalTransition}
    >
      <box>{getAllWallpapers()}</box>
    </revealer>
  );

  const revealButton = (
    <togglebutton
      valign={Gtk.Align.CENTER}
      class="bottom-revealer-button"
      label={""}
      onToggled={(source) => {
        (bottomRevealer as Gtk.Revealer).reveal_child = source.active;
        source.label = source.active ? "" : "";
      }}
    />
  );

  const actions = (
    <box class="actions" hexpand={true} halign={Gtk.Align.CENTER} spacing={10}>
      {targetButtons}
      {selectedWorkspaceLabel}
      {revealButton}
      {customToggle}
      {randomButton}
      {resetButton}
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
      <box class="bottom" hexpand={true} vexpand={true}>
        {bottomRevealer}
      </box>
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
      // onKeysChanged={(self: any, event: any) => {
      //   if (event.get_keyval()[1] === 65307) {
      //     hideWindow(`wallpaper-switcher-${monitorName}`);
      //     return true;
      //   }
      // }}
    >
      {Display(monitorName)}
    </window>
  );
};
