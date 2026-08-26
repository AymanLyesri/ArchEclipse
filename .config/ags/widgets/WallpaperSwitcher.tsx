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
  KirieItem,
  kirieCurrentItem,
  kirieInstalled,
  kirieList,
  kirieWorkshopUnsubscribe,
} from "../services/kirie";
import WallpaperEngineProperties from "./WallpaperEngineProperties";
import WorkshopBrowser from "./WorkshopBrowser";

// Wallpaper Engine items are directories rather than files, so they are kept
// beside the folder wallpapers under their own category and looked up by the
// path that gets stored as the wallpaper.
export const engineCategory = "wallpaper engine";
// GtkPicture hands back a placeholder for the animated previews these items
// ship, so those get a still frame cached beside the folder thumbnails.
const engineThumbnails = `${GLib.get_home_dir()}/.config/ags/cache/thumbnails/wallpaper-engine`;
const isAnimated = (preview: string) => preview.toLowerCase().endsWith(".gif");
const engineThumbnail = (item: KirieItem) =>
  item.preview && isAnimated(item.preview)
    ? `${engineThumbnails}/${item.id}.jpg`
    : (item.preview ?? "");

/** Make the still frames the animated previews need, once per item. */
async function makeEngineThumbnails(items: KirieItem[]) {
  const missing = items.filter(
    (item) =>
      item.preview &&
      isAnimated(item.preview) &&
      !GLib.file_test(engineThumbnail(item), GLib.FileTest.EXISTS),
  );
  if (missing.length === 0) return;

  const jobs = missing
    .map(
      (item) =>
        `magick ${JSON.stringify(`${item.preview}[0]`)} -resize 256x256 ` +
        `-quality 85 -strip ${JSON.stringify(engineThumbnail(item))} &`,
    )
    .join("\n");

  await execAsync([
    "bash",
    "-c",
    `mkdir -p ${JSON.stringify(engineThumbnails)}\n${jobs}\nwait`,
  ]).catch((err) => print("Error making engine thumbnails: " + String(err)));
}
const [engineItems, setEngineItems] = createState<Record<string, KirieItem>>({});
export const engineItem = (path: string): KirieItem | undefined =>
  engineItems.peek()[path];

/** The installed engine items as a wallpaper category, empty when kirie is
 * not installed or has nothing this build can render. */
async function fetchEngineWallpapers(): Promise<Record<string, string[]>> {
  if (!kirieInstalled()) return {};
  try {
    const items = (await kirieList()).filter((item) => item.renderable);
    await makeEngineThumbnails(items);
    setEngineItems(Object.fromEntries(items.map((item) => [item.dir, item])));
    return items.length ? { [engineCategory]: items.map((item) => item.dir) } : {};
  } catch (err) {
    print("Error listing wallpaper engine items: " + String(err));
    return {};
  }
}

export function toThumbnailPath(file: string) {
  const item = engineItem(file);
  if (item) return engineThumbnail(item);

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

  // In global mode one wallpaper covers every workspace, so the wallpaper is
  // stored under the daemon's `global` slot instead of a workspace one.
  const wallpaperMode = globalSettings(({ wallpaper }) => wallpaper.mode.value);
  const isGlobal = () => wallpaperMode.peek() === "global";
  const wallpaperTarget = () =>
    isGlobal() ? "global" : String(selectedWorkspaceId.peek());

  // The engine item whose settings the properties popover is showing.
  const [propertiesItem, setPropertiesItem] = createState<KirieItem | null>(
    null,
  );
  let propertiesButton: Gtk.MenuButton | null = null;
  // Set when a right-click picked the item, so opening the button on its own
  // still falls back to whatever is on this monitor.
  let pickedItem = false;

  /// How the strip is ordered. "Newest" is what a growing library wants —
  /// something just subscribed to is at the end of a scan and off the side of
  /// the screen otherwise.
  const ORDERS = ["Newest", "Oldest", "Name", "Type"] as const;
  const [order, setOrder] = createState<(typeof ORDERS)[number]>("Newest");

  /// When the file (or item directory) was last written, as a Unix time.
  ///
  /// Steam writes the directory as it downloads, so for a Workshop item this
  /// is when it arrived on this machine, which is what "newest" should mean
  /// here — not when its author last published it.
  const writtenAt = (path: string): number => {
    try {
      return (
        Gio.File.new_for_path(path)
          .query_info("time::modified", Gio.FileQueryInfoFlags.NONE, null)
          .get_attribute_uint64("time::modified") || 0
      );
    } catch (_err) {
      return 0;
    }
  };

  const nameOf = (path: string) =>
    (engineItem(path)?.title ?? path.split("/").pop() ?? path).toLowerCase();

  const selectedWallpapers = createComputed(() => {
    const paths = [
      ...(wallpapers()[
        globalSettings(({ wallpaperSwitcher }) => wallpaperSwitcher.category)()
      ] || []),
    ];

    switch (order()) {
      case "Newest":
        return paths.sort((a, b) => writtenAt(b) - writtenAt(a));
      case "Oldest":
        return paths.sort((a, b) => writtenAt(a) - writtenAt(b));
      case "Name":
        return paths.sort((a, b) => nameOf(a).localeCompare(nameOf(b)));
      case "Type":
        // Group the engine's kinds together, then name within each kind.
        return paths.sort((a, b) => {
          const kind = (path: string) =>
            engineItem(path)?.type ?? path.split(".").pop() ?? "";
          return (
            kind(a).localeCompare(kind(b)) || nameOf(a).localeCompare(nameOf(b))
          );
        });
      default:
        return paths;
    }
  });

  async function FetchWallpapers() {
    try {
      // Added await so that the function actually waits for the bash script to complete.
      const output = await execAsync(
        `bash ${GLib.get_home_dir()}/.config/ags/scripts/get-wallpapers.sh`,
      );
      const wallpapers = readJson(output);
      setWallpapers({ ...wallpapers, ...(await fetchEngineWallpapers()) });
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
      print("Error fetching wallpapers: " + String(err));
    }
  }

  /// Drop one wallpaper from the list without waiting for a rescan.
  ///
  /// Unsubscribing tells Steam to let go; Steam then deletes the files when it
  /// gets to it, usually seconds later. Rescanning immediately therefore finds
  /// the item still on disk and puts it straight back — it took a second
  /// unsubscribe to make it go, which was the shell lagging behind the user
  /// rather than anything being wrong.
  const forget = (path: string) => {
    const next: Record<string, string[]> = {};
    for (const [category, paths] of Object.entries(wallpapers.peek())) {
      next[category] = paths.filter((entry) => entry !== path);
    }
    setWallpapers(next);
  };

  /// Rescan once the directory has actually gone, so the list settles on the
  /// truth rather than on the optimistic removal above. Gives up after 15s;
  /// Steam has its own ideas about when to tidy up.
  const rescanWhenGone = (path: string, attemptsLeft = 15) => {
    if (attemptsLeft <= 0 || !GLib.file_test(path, GLib.FileTest.EXISTS)) {
      FetchWallpapers();
      return;
    }
    // Steam deletes the files it owns and stops there, so an item kirie has
    // rendered keeps its directory alive through the shader cache kirie left
    // inside it. That ghost is ours to clear — but only once nothing of the
    // wallpaper itself is left, which is what the missing project.json says.
    if (
      !GLib.file_test(`${path}/project.json`, GLib.FileTest.EXISTS) &&
      GLib.file_test(`${path}/.kirie-cache`, GLib.FileTest.IS_DIR)
    ) {
      execAsync(["rm", "-rf", "--", path])
        .catch(() => {})
        .finally(() => FetchWallpapers());
      return;
    }
    timeout(1000, () => rescanWhenGone(path, attemptsLeft - 1));
  };

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
          {(fetched) => {
            // One wallpaper covers every workspace in global mode, so it is
            // drawn once. Slicing here (rather than trusting the fetch) means
            // the row is right the moment the mode changes, before the daemon
            // has rewritten its config.
            const wallpapers =
              wallpaperMode.peek() === "global" ? fetched.slice(0, 1) : fetched;
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
                      // The single global tile is always the live one; keying
                      // it off the focused workspace would light it up only on
                      // workspace 1.
                      const isCurrent =
                        wallpaperMode.peek() === "global" || i === workspaceId + 1;
                      return isCurrent
                        ? "wallpaper-button focused"
                        : "wallpaper-button";
                    })}
                    css={wallpaper == "" ? "background-color: black" : ""}
                    onClicked={(self) => {
                      setTargetType("workspace");
                      setSelectedWorkspaceId(workspaceId + 1);
                    }}
                    tooltipMarkup={
                      wallpaperMode.peek() === "global"
                        ? "The <b>global</b> wallpaper, used on every workspace"
                        : `Set wallpaper for <b>Workspace ${workspaceId + 1}</b>`
                    }
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
                          wallpaperMode.peek() === "global"
                            ? "global"
                            : String(workspaceId + 1),
                          engineItem(wallpaper)?.type ||
                            wallpaper.split(".").pop() ||
                            "unknown",
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
                    sddm: [
                      "pkexec",
                      "bash",
                      "-c",
                      `sed -i "s|^background=.*|background=${wallpaper}|" /usr/share/sddm/themes/where_is_my_sddm_theme/theme.conf`,
                    ],
                    lockscreen: [
                      "bash",
                      "-c",
                      `mkdir -p \$HOME/.config/wallpapers/lockscreen && cp "${wallpaper}" \$HOME/.config/wallpapers/lockscreen/wallpaper`,
                    ],
                    workspace: [
                      `${GLib.get_home_dir()}/.config/hypr/wallpaper-daemon/set-wallpaper.sh`,
                      wallpaperTarget(),
                      String((self.get_root() as any).monitorName),
                      wallpaper,
                    ],
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

                // Right-click used to mean two different things depending on
                // what was under the cursor — settings for an engine item,
                // and an *unconfirmed delete* for anything else. It opens a
                // menu instead: the destructive entries are then something
                // chosen rather than something triggered.
                const deleteWallpaper = () => {
                  setProgressStatus("loading");
                  execAsync([
                    "bash",
                    "-c",
                    `rm -f '${toThumbnailPath(wallpaper)}' && rm -f '${wallpaper}'`,
                  ])
                    .then(() =>
                      notify({ summary: "Wallpaper", body: "Deleted." }),
                    )
                    .catch((err) => {
                      setProgressStatus("error");
                      notify({ summary: "Error", body: String(err) });
                    })
                    .finally(() => {
                      FetchWallpapers();
                      setProgressStatus("success");
                    });
                };

                const copy = (text: string, what: string) =>
                  execAsync(["wl-copy", text])
                    .then(() => notify({ summary: what, body: text }))
                    .catch((err) =>
                      notify({ summary: "Error", body: String(err) }),
                    );

                const menuEntry = (
                  label: string,
                  action: () => void,
                  cssClass = "",
                ) =>
                  (
                    <button
                      class={cssClass}
                      label={label}
                      onClicked={(self: Gtk.Button) => {
                        (
                          self.get_ancestor(Gtk.Popover) as Gtk.Popover
                        )?.popdown();
                        action();
                      }}
                    />
                  ) as Gtk.Widget;

                /// The menu for one wallpaper, built on first right-click.
                const buildMenu = (button: Gtk.Widget) => {
                  const item = engineItem(wallpaper);
                  const entries: Gtk.Widget[] = [];

                  if (item) {
                    entries.push(
                      menuEntry("Settings", () => {
                        pickedItem = true;
                        setPropertiesItem(item);
                        propertiesButton?.popup();
                      }),
                      menuEntry("Copy Workshop link", () =>
                        copy(
                          `https://steamcommunity.com/sharedfiles/filedetails/?id=${item.id}`,
                          "Workshop link",
                        ),
                      ),
                      menuEntry("Open in Steam", () =>
                        execAsync([
                          "xdg-open",
                          `steam://url/CommunityFilePage/${item.id}`,
                        ]).catch((err) =>
                          notify({ summary: "Error", body: String(err) }),
                        ),
                      ),
                    );
                  }

                  entries.push(
                    menuEntry("Copy path", () => copy(wallpaper, "Path")),
                    menuEntry("Open folder", () =>
                      execAsync([
                        "xdg-open",
                        item ? wallpaper : wallpaper.split("/").slice(0, -1).join("/"),
                      ]).catch((err) =>
                        notify({ summary: "Error", body: String(err) }),
                      ),
                    ),
                  );

                  if (item) {
                    // Steam owns these files; unsubscribing is how they go,
                    // and Steam removes them on its own schedule afterwards.
                    entries.push(
                      menuEntry(
                        "Unsubscribe",
                        () => {
                          setProgressStatus("loading");
                          kirieWorkshopUnsubscribe(item.id)
                            .then(() => {
                              // Gone from the list now, gone from disk when
                              // Steam catches up.
                              forget(wallpaper);
                              rescanWhenGone(wallpaper);
                              notify({
                                summary: "Unsubscribed",
                                body: item.title,
                              });
                            })
                            .catch((err) => {
                              notify({ summary: "Error", body: String(err) });
                              FetchWallpapers();
                            })
                            .finally(() => setProgressStatus("success"));
                        },
                        "destructive",
                      ),
                    );
                  } else {
                    entries.push(
                      menuEntry("Delete", deleteWallpaper, "destructive"),
                    );
                  }

                  const popover = new Gtk.Popover({
                    cssClasses: ["wallpaper-menu"],
                    position: Gtk.PositionType.TOP,
                  });
                  const box = new Gtk.Box({
                    orientation: Gtk.Orientation.VERTICAL,
                    cssClasses: ["popover"],
                  });
                  for (const entry of entries) box.append(entry);
                  popover.set_child(box);
                  popover.set_parent(button);
                  return popover;
                };

                let menu: Gtk.Popover | null = null;
                const handleRightClick = (button: Gtk.Widget) => {
                  menu ??= buildMenu(button);
                  menu.popup();
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
                        handleRightClick(self);
                      });

                      self.add_controller(gesture);
                    }}
                    tooltipMarkup={targetType((type) => {
                      const item = engineItem(wallpaper);
                      if (item)
                        return (
                          `Click to set as <b>${type}</b> wallpaper.` +
                          "\nRight-click to manage it." +
                          `\n ${item.title}` +
                          `\n Wallpaper Engine ${item.type}`
                        );

                      return (
                        "Click to set as <b>" +
                        type +
                        "</b> wallpaper.\nRight-click to manage it." +
                        // get filename from path
                        `\n ${wallpaper.split("/").pop()}` +
                        // file size
                        `\n Size: ${fileSize(wallpaper)}`
                      );
                    })}
                  >
                    <Picture
                      class="wallpaper"
                      file={toThumbnailPath(wallpaper)}
                      info={[
                        engineItem(wallpaper)?.type ||
                          wallpaper.split(".").pop() ||
                          "unknown",
                      ]}
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
          execAsync([
            `${GLib.get_home_dir()}/.config/hypr/wallpaper-daemon/set-wallpaper.sh`,
            wallpaperTarget(),
            String((self.get_root() as any).monitorName),
            randomWallpaper,
          ])
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
            targetType() !== "workspace"
              ? `Wallpaper -> ${targetType()}`
              : wallpaperMode() === "global"
                ? "Wallpaper -> global"
                : `Wallpaper -> workspace ${selectedWorkspaceId()}`,
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

    const propertiesSelector = (
      <menubutton
        class="wallpaper-properties"
        valign={Gtk.Align.CENTER}
        visible={kirieInstalled()}
        tooltipMarkup="<b>Wallpaper Engine</b> settings for this wallpaper"
        $={(self) => {
          propertiesButton = self;
          self.connect("notify::active", () => {
            if (!self.active) {
              pickedItem = false;
              return;
            }
            if (pickedItem) return;
            kirieCurrentItem(monitorName).then((dir) =>
              setPropertiesItem(engineItem(dir) ?? null),
            );
          });
        }}
      >
        <label label="󰒓" />
        <popover>
          <With value={propertiesItem}>
            {(item) =>
              item ? (
                <WallpaperEngineProperties monitor={monitorName} item={item} />
              ) : (
                <label
                  class="popover"
                  wrap
                  label={
                    "No Wallpaper Engine wallpaper here.\n" +
                    "Right-click one to edit its settings."
                  }
                />
              )
            }
          </With>
        </popover>
      </menubutton>
    );

    // Browse the Workshop for wallpapers this machine does not have yet — the
    // one thing the rest of this switcher cannot show, since it lists what is
    // installed. Subscribing puts the item exactly where `kirie list` looks.
    const workshopSelector = (
      <menubutton
        class="workshop"
        visible={kirieInstalled()}
        tooltipMarkup="Browse the <b>Steam Workshop</b>"
      >
        {/* Steam's own mark, alone. A download arrow said "fetch something"
            rather than "go and look through the Workshop", but pairing the
            mark with a magnifier just made two small glyphs fight for the
            same button — the tooltip can carry the rest. */}
        <label class="workshop-icon" label={"\u{f1b6}"} />
        <popover position={Gtk.PositionType.TOP}>
          <WorkshopBrowser
            onInstalled={() => FetchWallpapers()}
            onApply={(dir) => {
              setProgressStatus("loading");
              execAsync([
                `${GLib.get_home_dir()}/.config/hypr/wallpaper-daemon/set-wallpaper.sh`,
                wallpaperTarget(),
                monitorName,
                dir,
              ])
                .then(() => FetchCurrentWallpapers(monitorName))
                .finally(() => setProgressStatus("success"))
                .catch((err) => {
                  setProgressStatus("error");
                  notify({ summary: "Error", body: String(err) });
                });
            }}
          />
        </popover>
      </menubutton>
    );

    const orderSelector = (
      <menubutton class="order-selector" tooltipMarkup="Order the wallpapers">
        <box spacing={4}>
          <label label={order((o) => o)} />
          <label class="chevron" label="▾" />
        </box>
        <popover position={Gtk.PositionType.TOP}>
          <box orientation={Gtk.Orientation.VERTICAL} class="popover">
            {ORDERS.map((option) => (
              <button
                class={order((o) => (o === option ? "selected" : ""))}
                label={option}
                onClicked={(self: Gtk.Button) => {
                  (self.get_ancestor(Gtk.Popover) as Gtk.Popover)?.popdown();
                  setOrder(option);
                }}
              />
            ))}
          </box>
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
        {orderSelector}
        {propertiesSelector}
        {workshopSelector}
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
        spacing={5}
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
        // The engine items have to be known before the current wallpapers are
        // drawn, or the ones set from an item render without their preview.
        await FetchWallpapers();
        FetchCurrentWallpapers(monitorName);

        // Switching the mode writes the daemon's config from a script that is
        // still running when the setting itself changes, so refetching on the
        // setting alone reads the OLD layout and sticks there — ten workspace
        // tiles labelled "global". Follow the file the daemon actually writes:
        // it also covers wallpapers changed by anything other than this panel.
        monitorFile(
          `${GLib.get_home_dir()}/.config/hypr/wallpaper-daemon/config/${monitorName}/defaults.conf`,
          () => FetchCurrentWallpapers(monitorName),
        );
        wallpaperMode.subscribe(() => FetchCurrentWallpapers(monitorName));

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
