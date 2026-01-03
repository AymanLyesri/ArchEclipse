import { createState, createComputed, createBinding, With } from "ags";
import { execAsync, exec } from "ags/process";
import {
  globalSettings,
  setGlobalSetting,
  setGlobalSettings,
} from "../../../variables";
import Gtk from "gi://Gtk?version=4.0";
import { notify } from "../../../utils/notification";
import { Api } from "../../../interfaces/api.interface";
import { Waifu } from "../../../interfaces/waifu.interface";
import { readJson } from "../../../utils/json";
import { booruApis } from "../../../constants/api.constants";
import {
  bookMarkExists,
  bookMarkImage,
  fetchImage,
  OpenInBrowser,
  PinImageToTerminal,
  previewFloatImage,
  removeBookMarkImage,
} from "../../../utils/image";
import Picture from "../../Picture";
import { Progress } from "../../Progress";
import GLib from "gi://GLib?version=2.0";
import Gio from "gi://Gio?version=2.0";
import Video from "../../Video";

import { booruPath } from "../../../constants/path.constants";
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");

const GetImageByid = async (id: number) => {
  setProgressStatus("loading");
  try {
    const res = await execAsync(
      `python ./scripts/search-booru.py 
    --api ${globalSettings.peek().waifu.api.value} 
    --id ${id}`
    );

    const image: Waifu = readJson(res)[0] as Waifu;
    image.api = globalSettings.peek().waifu.api;

    fetchImage(image)
      .then(() => {
        setGlobalSetting("waifu", {
          ...image,
          api: globalSettings.peek().waifu.api,
        });
        setProgressStatus("success");
      })
      .catch(() => {
        print("Failed to fetch image");
        setProgressStatus("error");
      });
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    print("Error fetching waifu by ID:", err);
    setProgressStatus("error");
  }
};

const CopyImage = (image: Waifu) =>
  execAsync(
    `bash -c "wl-copy --type image/png < ${booruPath}/${image.api.value}/images/${image.id}.jpg"`
  ).catch((err) => notify({ summary: "Error", body: err }));

const OpenImage = (image: Waifu) =>
  previewFloatImage(`${booruPath}/${image.api.value}/images/${image.id}.jpg`);

function Actions() {
  const Entry = (
    <entry
      class="input"
      placeholderText="enter post ID"
      text={globalSettings.peek().waifu.input_history || ""}
      onActivate={(self) => {
        setGlobalSetting("waifu.input_history", self.text);
        GetImageByid(Number(self.text));
      }}
    />
  );

  return (
    <box
      class="actions"
      valign={Gtk.Align.END}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
    >
      <Progress status={progressStatus} />
      <box class="section">
        <togglebutton
          class={"button"}
          label={globalSettings(({ waifu }) =>
            bookMarkExists(waifu.current!) ? "" : ""
          )}
          tooltip-text="Bookmark image"
          active={globalSettings(({ waifu }) => bookMarkExists(waifu.current!))}
          onClicked={(self) => {
            if (self.active) {
              bookMarkImage(globalSettings.peek().waifu.current!);
            } else {
              removeBookMarkImage(globalSettings.peek().waifu.current!);
            }
          }}
          hexpand
        />
        <button
          label=""
          hexpand
          class="pin"
          onClicked={() =>
            PinImageToTerminal(globalSettings.peek().waifu.current!)
          }
        />
      </box>
      <box class="section">
        <button
          label=""
          class="open"
          hexpand
          onClicked={() => OpenImage(globalSettings.peek().waifu.current!)}
        />
        <button
          label=""
          hexpand
          class="browser"
          onClicked={() => OpenInBrowser(globalSettings.peek().waifu.current!)}
        />

        <button
          label=""
          hexpand
          class="copy"
          onClicked={() => CopyImage(globalSettings.peek().waifu.current!)}
        />
      </box>
      <box class="section" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
        <box>
          <button
            hexpand
            label=""
            class="entry-search"
            onClicked={() => (Entry as Gtk.Entry).activate()}
          />
          {Entry}
          <button
            hexpand
            label={""}
            class="upload"
            onClicked={async (self) => {
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

              // dialog.set_filters([filter]);
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

                const [height, width] = exec(
                  `identify -format "%h %w" "${filename}"`
                ).split(" ");

                // create custom booru directory if not exists
                await execAsync(`mkdir -p "${booruPath}/custom/images"`).catch(
                  (err) =>
                    notify({
                      summary: "Error",
                      body: String(err),
                    })
                );
                await execAsync(
                  `cp "${filename}" "${booruPath}/custom/images/-1.${filename
                    .split(".")
                    .pop()!}"`
                ).catch((err) =>
                  notify({
                    summary: "Error",
                    body: String(err),
                  })
                );

                setGlobalSetting("waifu.current", {
                  id: -1,
                  height: Number(height) || 0,
                  width: Number(width) || 0,
                  api: {
                    name: "Custom",
                    value: "custom",
                  } as Api,
                  extension: filename.split(".").pop()!,
                  tags: ["custom"],
                });

                notify({
                  summary: "Waifu",
                  body: "Custom image set",
                });
              } catch (err) {
                // Gtk.FileDialog throws on cancel — ignore silently
                if (
                  err instanceof GLib.Error &&
                  err.matches(
                    Gtk.dialog_error_quark(),
                    Gtk.DialogError.CANCELLED
                  )
                )
                  return;

                notify({
                  summary: "Error",
                  body: String(err),
                });
              }
            }}
          />
        </box>
        <box>
          {booruApis.map((api) => (
            <togglebutton
              hexpand
              class="api"
              label={api.name}
              active={globalSettings(
                ({ waifu }) => waifu.api.value === api.value
              )}
              onToggled={({ active }) => {
                if (active) {
                  setGlobalSetting("waifu.api", api);
                }
              }}
            />
          ))}
        </box>
      </box>
    </box>
  );
}

function Image() {
  const imageHeight = globalSettings((settings) =>
    settings.waifu.current.width && settings.waifu.current.height
      ? (settings.waifu.current.height / settings.waifu.current.width) *
        settings.rightPanel.width
      : settings.rightPanel.width
  );

  return (
    <With value={globalSettings(({ waifu }) => waifu.current)}>
      {(w: Waifu) => {
        return w.id ? (
          <overlay class="overlay">
            {w.extension === "mp4" ||
            w.extension === "webm" ||
            w.extension === "mkv" ||
            w.extension === "gif" ||
            w.extension === "zip" ? (
              <Video
                class="image"
                width={globalSettings(({ rightPanel }) => rightPanel.width)}
                file={`${booruPath}/${w.api.value}/images/${w.id}.${w.extension}`}
              />
            ) : (
              <Picture
                class="image"
                height={imageHeight}
                file={`${booruPath}/${w.api.value}/images/${w.id}.${w.extension}`}
                contentFit={Gtk.ContentFit.COVER}
              />
            )}
            <Actions $type="overlay" />
          </overlay>
        ) : (
          <box
            halign={Gtk.Align.CENTER}
            valign={Gtk.Align.CENTER}
            class="no-image"
          >
            <label label="No image selected" />
          </box>
        );
      }}
    </With>
  );
}

export default () => {
  return (
    <box class="waifu" orientation={Gtk.Orientation.VERTICAL}>
      {Image()}
    </box>
  );
};

export function WaifuVisibility() {
  return (
    <togglebutton
      active={globalSettings((s) => s.waifu.visibility)}
      onToggled={({ active }) => setGlobalSetting("waifu.visibility", active)}
      label="󰉣"
      class="waifu icon"
    />
  );
}
