import hyprland from "gi://AstalHyprland";
import { bind, exec, execAsync, monitorFile, Variable } from "astal";
import { App, Astal, Gdk, Gtk } from "astal/gtk3";
import { notify } from "../utils/notification";
import { focusedWorkspace, globalTransition } from "../variables";
import ToggleButton from "./toggleButton";
import { Button } from "astal/gtk3/widget";
import { getMonitorName } from "../utils/monitor";
import { hideWindow } from "../utils/window";

const Hyprland = hyprland.get_default();

// State management
const selectedWorkspaceState = {
  id: Variable<number>(0),
  widget: Variable<Button>(new Button()),
};

const updateSelectedWorkspaceWidget = (workspaceId: number, widget: Button) => {
  selectedWorkspaceState.id.set(workspaceId);
  selectedWorkspaceState.widget.set(widget);
};

const targetTypes = ["workspace", "sddm", "lockscreen"];
const targetType = Variable<string>("workspace");
const wallpaperType = Variable<boolean>(false);

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

const allWallpapers = Variable<string[]>([]);
const allThumbnails = Variable<string[]>([]);

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

    if (wallpaperType.get()) {
      allWallpapers.set(wallpaperData.custom.wallpapers);
      allThumbnails.set(wallpaperData.custom.thumbnails);
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
      allWallpapers.set(shuffledWallpapers);
      allThumbnails.set(shuffledThumbnails);
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
          {bind(
            Variable.derive(
              [bind(allWallpapers), bind(allThumbnails)],
              (allWallpapers, allThumbnails) =>
                allWallpapers.map((wallpaper, key) => (
                  <eventbox
                    className="wallpaper-event-box"
                    onClick={() => {
                      const target = targetType.get();
                      const command = {
                        sddm: `pkexec sh -c 'sed -i "s|^background=.*|background=\"${wallpaper}\"|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf'`,
                        lockscreen: `bash -c "cp ${wallpaper} $HOME/.config/wallpapers/lockscreen/wallpaper"`,
                        workspace: `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceState.id.get()} ${wallpaper} ${monitor}"`,
                      }[target];

                      execAsync(command!)
                        .then(() => {
                          if (target === "workspace") {
                            const widget = selectedWorkspaceState.widget.get();
                            widget.css = `background-image: url('${wallpaper}');`;
                            selectedWorkspaceState.widget.set(widget);
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
                          background-image: url("${allThumbnails[key]}");
                        `}
                        child={
                          <button
                            visible={wallpaperType.get()}
                            className="delete-wallpaper"
                            halign={Gtk.Align.END}
                            valign={Gtk.Align.START}
                            label=""
                            onClicked={() => {
                              execAsync(
                                `bash -c "rm -f '${allThumbnails[key]}' '${wallpaper}'"`
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
                ))
            )
          )}
        </box>
      }
    />
  );

  const getCurrentWorkspaces = () => {
    const activeId = focusedWorkspace.as((workspace) => workspace.id || 1);
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
          className={activeId.as((i) => {
            return i === workspaceId
              ? "workspace-wallpaper focused"
              : "workspace-wallpaper";
          })}
          label={`${workspaceId}`}
          onClicked={(self) => {
            targetType.set("workspace");
            bottomRevealer.reveal_child = true;
            updateSelectedWorkspaceWidget(workspaceId, self);
          }}
          setup={(self) => {
            activeId.as((i) => {
              if (i === workspaceId) {
                updateSelectedWorkspaceWidget(workspaceId, self);
              }
            });
          }}
        />
      );
    });
  };

  let currentWorkspaces = getCurrentWorkspaces();
  focusedWorkspace.subscribe((workspace) => {
    if (workspace) {
      selectedWorkspaceState.id.set(workspace.id);
      selectedWorkspaceState.widget.set(
        currentWorkspaces[workspace.id - 1] as Button
      );
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
          allWallpapers.get()[
            Math.floor(Math.random() * allWallpapers.get().length)
          ];
        execAsync(
          `bash -c "$HOME/.config/hypr/hyprpaper/set-wallpaper.sh ${selectedWorkspaceState.id.get()} ${randomWallpaper} ${monitor}"`
        )
          .finally(() => {
            const newWallpaper = JSON.parse(
              exec(`bash ./scripts/get-wallpapers.sh --current ${monitor}`)
            )[selectedWorkspaceState.id.get() - 1];
            const widget = selectedWorkspaceState.widget.get();
            widget.css = `background-image: url('${newWallpaper}');`;
            selectedWorkspaceState.widget.set(widget);
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
      onToggled={(self, on) => {
        wallpaperType.set(on);
        self.label = on ? "custom" : "all";
      }}
    />
  );

  const revealButton = (
    <ToggleButton
      className="bottom-revealer-button"
      label=""
      onToggled={(self, on) => {
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
          state={bind(targetType).as((t) => t === type)}
          onToggled={() => targetType.set(type)}
        />
      ))}
    </box>
  );

  const selectedWorkspaceLabel = (
    <label
      className="button selected-workspace"
      label={bind(
        Variable.derive(
          [bind(selectedWorkspaceState.id), bind(targetType)],
          (workspace, targetType) =>
            `Wallpaper -> ${targetType} ${
              targetType === "workspace" ? workspace : ""
            }`
        )
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
      transition_duration={globalTransition}
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
wallpaperType.subscribe(FetchWallpapers);

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
