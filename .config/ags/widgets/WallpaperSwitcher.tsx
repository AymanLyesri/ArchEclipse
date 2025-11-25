import hyprland from "gi://AstalHyprland";
import {
  createBinding,
  createComputed,
  exec,
  execAsync,
  monitorFile,
  createState,
  createEffect,
} from "ags";
import App from "ags/gtk3/app";
import Gtk from "gi://Gtk?version=3.0";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import { notify } from "../utils/notification";
import { focusedWorkspace, globalTransition } from "../variables";
import ToggleButton from "./toggleButton";
import { getMonitorName } from "../utils/monitor";
import { hideWindow } from "../utils/window";

const Hyprland = hyprland.get_default();

// State management
const [selectedWorkspaceId, setSelectedWorkspaceId] = createState(0);
const [selectedWorkspaceWidget, setSelectedWorkspaceWidget] =
  createState<Gtk.Button | null>(null);

const updateSelectedWorkspaceWidget = (
  workspaceId: number,
  widget: Gtk.Button
) => {
  setSelectedWorkspaceId(workspaceId);
  setSelectedWorkspaceWidget(widget);
};

const targetTypes = ["workspace", "sddm", "lockscreen"];
const [targetType, setTargetType] = createState("workspace");
const [wallpaperType, setWallpaperType] = createState(false);

// Wallpaper data
const wallpaperData = {
  default: {
    wallpapers: [] as string[],
    thumbnails: [] as string[],
  },
  custom: {
    wallpapers: [] as string[],
    thumbnails: [] as string[],
  },
};

const [allWallpapers, setAllWallpapers] = createState<string[]>([]);
const [allThumbnails, setAllThumbnails] = createState<string[]>([]);

// Utility functions
const shuffleArraysTogether = (
  arr1: string[],
  arr2: string[]
): [string[], string[]] => {
  const combined = arr1.map((item, index) => ({ item, thumb: arr2[index] }));
  combined.sort(() => Math.random() - 0.5);
  return [combined.map((c) => c.item), combined.map((c) => c.thumb)];
};

const FetchWallpapers = async () => {
  try {
    await execAsync("bash ./scripts/wallpaper-to-thumbnail.sh");

    const [defaultThumbs, customThumbs, defaultWalls, customWalls] =
      await Promise.all([
        execAsync(
          "bash ./scripts/get-wallpapers-thumbnails.sh --defaults"
        ).then(JSON.parse),
        execAsync("bash ./scripts/get-wallpapers-thumbnails.sh --custom").then(
          JSON.parse
        ),
        execAsync("bash ./scripts/get-wallpapers.sh --defaults").then(
          JSON.parse
        ),
        execAsync("bash ./scripts/get-wallpapers.sh --custom").then(JSON.parse),
      ]);

    wallpaperData.default.thumbnails = defaultThumbs;
    wallpaperData.custom.thumbnails = customThumbs;
    wallpaperData.default.wallpapers = defaultWalls;
    wallpaperData.custom.wallpapers = customWalls;

    if (wallpaperType()) {
      setAllWallpapers(wallpaperData.custom.wallpapers);
      setAllThumbnails(wallpaperData.custom.thumbnails);
    } else {
      const [shuffledWallpapers, shuffledThumbnails] = shuffleArraysTogether(
        [
          ...wallpaperData.default.wallpapers,
          ...wallpaperData.custom.wallpapers,
        ],
        [
          ...wallpaperData.default.thumbnails,
          ...wallpaperData.custom.thumbnails,
        ]
      );
      setAllWallpapers(shuffledWallpapers);
      setAllThumbnails(shuffledThumbnails);
    }
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
  }
};

function Wallpapers(monitor: string) {
  const getAllWallpapers = () => (
    <scrollable
      className="all-wallpapers-scrollable"
      hscrollbarPolicy={Gtk.PolicyType.ALWAYS}
      vscrollbarPolicy={Gtk.PolicyType.NEVER}
      hexpand
      vexpand
      child={
        <box className="all-wallpapers" spacing={5}>
          {createComputed(() => {
            const wallpapers = allWallpapers();
            const thumbnails = allThumbnails();
            return wallpapers.map((wallpaper, key) => (
              <eventbox
                className="wallpaper-event-box"
                onClick={() => {
                  const target = targetType();
                  const command = {
                    sddm: `pkexec sh -c 'sed -i "s|^background=.*|background=\"${wallpaper}\"|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf'`,
                    lockscreen: `bash -c "cp ${wallpaper} $HOME/.config/wallpapers/lockscreen/wallpaper"`,
                    workspace: `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceId()} ${wallpaper} ${monitor}"`,
                  }[target];

                  execAsync(command!)
                    .then(() => {
                      if (target === "workspace") {
                        const widget = selectedWorkspaceWidget();
                        if (widget)
                          widget.css = `background-image: url('${wallpaper}');`;
                      }
                      notify({
                        summary: target,
                        body: `${target} wallpaper changed successfully!`,
                      });
                    })
                    .catch(notify);
                }}
                child={
                  <box
                    className="wallpaper"
                    vertical
                    css={`
                      background-image: url("${thumbnails[key]}");
                    `}
                    child={
                      <button
                        visible={createComputed(() => wallpaperType())}
                        className="delete-wallpaper"
                        halign={Gtk.Align.END}
                        valign={Gtk.Align.START}
                        label=""
                        onClicked={() => {
                          execAsync(
                            `bash -c "rm -f '${thumbnails[key]}' '${wallpaper}'"`
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
                      />
                    }
                  />
                }
              />
            ));
          })}
        </box>
      }
    />
  );

  const getCurrentWorkspaces = () => {
    const activeId = createComputed(() => focusedWorkspace()?.id || 1);
    const wallpapers: string[] = JSON.parse(
      exec(`bash ./scripts/get-wallpapers.sh --current ${monitor}`) || "[]"
    );

    return wallpapers.map((wallpaper, key) => {
      const workspaceId = key + 1;

      return (
        <button
          valign={Gtk.Align.CENTER}
          css={`
            background-image: url("${wallpaper}");
          `}
          className={createComputed(() => {
            return activeId() === workspaceId
              ? "workspace-wallpaper focused"
              : "workspace-wallpaper";
          })}
          label={`${workspaceId}`}
          onClicked={(self) => {
            setTargetType("workspace");
            bottomRevealer.reveal_child = true;
            updateSelectedWorkspaceWidget(workspaceId, self);
          }}
        />
      );
    });
  };

  let currentWorkspaces = getCurrentWorkspaces();
  createEffect(() => {
    const workspace = focusedWorkspace();
    if (workspace) {
      setSelectedWorkspaceId(workspace.id);
      const widget = currentWorkspaces[workspace.id - 1];
      if (widget) setSelectedWorkspaceWidget(widget as unknown as Gtk.Button);
    }
  });

  const resetButton = (
    <button
      valign={Gtk.Align.CENTER}
      className="reload-wallpapers"
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
      className="random-wallpaper"
      label=""
      onClicked={() => {
        const randomWallpaper =
          allWallpapers()[Math.floor(Math.random() * allWallpapers().length)];
        execAsync(
          `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceId()} ${randomWallpaper} ${monitor}"`
        )
          .finally(() => {
            const newWallpaper = JSON.parse(
              exec(`bash ./scripts/get-wallpapers.sh --current ${monitor}`)
            )[selectedWorkspaceId() - 1];
            const widget = selectedWorkspaceWidget();
            if (widget)
              widget.css = `background-image: url('${newWallpaper}');`;
          })
          .catch(notify);
      }}
    />
  );

  const customToggle = (
    <ToggleButton
      valign={Gtk.Align.CENTER}
      className="custom-wallpaper"
      label="all"
      onToggled={(self: any, on: boolean) => {
        setWallpaperType(on);
        self.label = on ? "custom" : "all";
      }}
    />
  );

  const revealButton = (
    <ToggleButton
      className="bottom-revealer-button"
      label=""
      onToggled={(self: any, on: boolean) => {
        bottomRevealer.reveal_child = on;
        self.label = on ? "" : "";
      }}
    />
  );

  const targetButtons = (
    <box className="targets" hexpand={true} halign={Gtk.Align.CENTER}>
      {targetTypes.map((type) => (
        <ToggleButton
          valign={Gtk.Align.CENTER}
          className={type}
          label={type}
          state={createComputed(() => targetType() === type)}
          onToggled={() => setTargetType(type)}
        />
      ))}
    </box>
  );

  const selectedWorkspaceLabel = (
    <label
      className="button selected-workspace"
      label={createComputed(
        () =>
          `Wallpaper -> ${targetType()} ${
            targetType() === "workspace" ? selectedWorkspaceId() : ""
          }`
      )}
    />
  );

  const addWallpaperButton = (
    <button
      label=""
      className="upload"
      onClicked={() => {
        let dialog = new Gtk.FileChooserDialog({
          title: "Open Image",
          action: Gtk.FileChooserAction.OPEN,
        });
        dialog.add_button("Upload", Gtk.ResponseType.OK);
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL);
        let response = dialog.run();
        if (response == Gtk.ResponseType.OK) {
          let filename = dialog.get_filename();
          execAsync(
            `bash -c "cp '${filename}' $HOME/.config/wallpapers/custom"`
          )
            .then(() =>
              notify({
                summary: "Success",
                body: "Wallpaper added successfully!",
              })
            )
            .catch((err) => notify({ summary: "Error", body: String(err) }));
        }
        dialog.destroy();
      }}
    />
  );

  const actions = (
    <box
      className="actions"
      hexpand={true}
      halign={Gtk.Align.CENTER}
      spacing={10}
    >
      {targetButtons}
      {selectedWorkspaceLabel}
      {revealButton}
      {customToggle}
      {randomButton}
      {resetButton}
      {addWallpaperButton}
    </box>
  );

  const bottomRevealer = (
    <revealer
      visible={true}
      reveal_child={false}
      transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
      transitionDuration={globalTransition}
      child={<box child={getAllWallpapers()}></box>}
    />
  );

  return (
    <box className="wallpaper-switcher" vertical={true} spacing={20}>
      <box hexpand={true} vexpand={true} halign={Gtk.Align.CENTER} spacing={10}>
        {currentWorkspaces}
      </box>
      {actions}
      <box
        className="bottom"
        hexpand={true}
        vexpand={true}
        child={bottomRevealer}
      ></box>
    </box>
  );
}

// Initialize
FetchWallpapers();
monitorFile("./../wallpapers/custom", FetchWallpapers);
createEffect(() => {
  wallpaperType();
  FetchWallpapers();
});

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;
  return (
    <window
      gdkmonitor={monitor}
      namespace="wallpaper-switcher"
      name={`wallpaper-switcher-${monitorName}`}
      application={App}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          hideWindow(`wallpaper-switcher-${monitorName}`);
          return true;
        }
      }}
      child={Wallpapers(monitorName)}
    />
  );
};
