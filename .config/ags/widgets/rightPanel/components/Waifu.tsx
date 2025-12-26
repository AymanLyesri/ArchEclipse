import { createState, createComputed, createBinding, With } from "ags";
import { execAsync, exec } from "ags/process";
import {
  waifuApi,
  setWaifuApi,
  globalSettings,
  globalTransition,
  rightPanelWidth,
  waifuCurrent,
  setWaifuCurrent,
  setGlobalSettings,
} from "../../../variables";
import Gtk from "gi://Gtk?version=4.0";
import { getSetting, setSetting } from "../../../utils/settings";
import { notify } from "../../../utils/notification";
import { Api } from "../../../interfaces/api.interface";
import { Waifu } from "../../../interfaces/waifu.interface";
import { readJson } from "../../../utils/json";
import { booruApis } from "../../../constants/api.constants";
import {
  fetchImage,
  PinImageToTerminal,
  previewFloatImage,
} from "../../../utils/image";
import Picture from "../../Picture";
import { Progress } from "../../Progress";
import GLib from "gi://GLib?version=2.0";
import Gio from "gi://Gio?version=2.0";
import Video from "../../Video";
import { Eventbox } from "../../Custom/Eventbox";
import { booruPath } from "../../../constants/path.constants";
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");

const GetImageByid = async (id: number) => {
  setProgressStatus("loading");
  try {
    const res = await execAsync(
      `python ./scripts/search-booru.py 
    --api ${waifuApi.get().value} 
    --id ${id}`
    );

    const image: Waifu = readJson(res)[0] as Waifu;
    image.api = waifuApi.get();

    fetchImage(image)
      .then(() => {
        setWaifuCurrent({
          ...image,
          api: waifuApi.get(),
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

const OpenInBrowser = (image: Waifu) =>
  execAsync(
    `bash -c "xdg-open '${image.api.idSearchUrl}${
      waifuCurrent.get().id
    }' && xdg-settings get default-web-browser | sed 's/\.desktop$//'"`
  )
    .then((browser) =>
      notify({ summary: "Waifu", body: `opened in ${browser}` })
    )
    .catch((err) => notify({ summary: "Error", body: err }));

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
      text={getSetting("waifu.input_history", globalSettings.get()) || ""}
      onActivate={(self) => {
        setSetting(
          "waifu.input_history",
          self.text,
          globalSettings,
          setGlobalSettings
        );
        GetImageByid(Number(self.text));
      }}
    />
  );

  return (
    <Eventbox
      class={"bottom"}
      onHover={(self) => {
        const revealer = self.get_last_child() as Gtk.Revealer;
        revealer.reveal_child = true;
      }}
      onHoverLost={(self) => {
        const revealer = self.get_last_child() as Gtk.Revealer;
        revealer.reveal_child = false;
      }}
    >
      <revealer
        revealChild={false}
        transitionDuration={globalTransition}
        transition_type={Gtk.RevealerTransitionType.SWING_UP}
      >
        <box
          class="actions"
          valign={Gtk.Align.END}
          orientation={Gtk.Orientation.VERTICAL}
          spacing={5}
        >
          <Progress status={progressStatus} />
          <box class="section">
            <button
              label=""
              class="open"
              hexpand
              onClicked={() => OpenImage(waifuCurrent.get())}
            />
            <button
              label=""
              hexpand
              class="browser"
              onClicked={() => OpenInBrowser(waifuCurrent.get())}
            />
            <button
              label=""
              hexpand
              class="pin"
              onClicked={() => PinImageToTerminal(waifuCurrent.get())}
            />
            <button
              label=""
              hexpand
              class="copy"
              onClicked={() => CopyImage(waifuCurrent.get())}
            />
          </box>
          <box class="section">
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

                  const file: Gio.File = await new Promise(
                    (resolve, reject) => {
                      dialog.open(root, null, (dlg, res) => {
                        try {
                          resolve(dlg!.open_finish(res));
                        } catch (e) {
                          reject(e);
                        }
                      });
                    }
                  );

                  if (!file) return;

                  const filename = file.get_path();
                  if (!filename) return;

                  const [height, width] = exec(
                    `identify -format "%h %w" "${filename}"`
                  ).split(" ");

                  await execAsync(
                    `cp "${filename}" "${booruPath}/custom/-1.${filename
                      .split(".")
                      .pop()!}"`
                  ).catch((err) =>
                    notify({
                      summary: "Error",
                      body: String(err),
                    })
                  );

                  setWaifuCurrent({
                    id: -1,
                    height: Number(height) || 0,
                    width: Number(width) || 0,
                    api: {} as Api,
                    extension: filename.split(".").pop()!,
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
          <box class="section">
            {booruApis.map((api) => (
              <togglebutton
                hexpand
                class="api"
                label={api.name}
                active={waifuApi((_api) => _api.value === api.value)}
                onToggled={({ active }) => {
                  if (active) {
                    setWaifuApi(api);
                    setSetting(
                      "waifu.api",
                      api,
                      globalSettings,
                      setGlobalSettings
                    );
                  }
                }}
              />
            ))}
          </box>
        </box>
      </revealer>
    </Eventbox>
  );
}

function Image() {
  const imageHeight = createComputed(
    [waifuCurrent, rightPanelWidth],
    (current, width) =>
      current.width && current.height
        ? (current.height / current.width) * width
        : width
  );

  return (
    <overlay class="overlay">
      <With value={waifuCurrent}>
        {(w) => {
          return w.extension === "mp4" ||
            w.extension === "webm" ||
            w.extension === "mkv" ||
            w.extension === "gif" ||
            w.extension === "zip" ? (
            <Video
              class="image"
              width={rightPanelWidth}
              file={`${booruPath}/${w.api.value}/images/${w.id}.${w.extension}`}
            />
          ) : (
            <Picture
              class="image"
              height={imageHeight}
              file={`${booruPath}/${w.api.value}/images/${w.id}.${w.extension}`}
              contentFit={Gtk.ContentFit.COVER}
            />
          );
        }}
      </With>

      <Actions $type="overlay" />
    </overlay>
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
      onToggled={({ active }) =>
        setSetting(
          "waifu.visibility",
          active,
          globalSettings,
          setGlobalSettings
        )
      }
      label="󰉣"
      class="waifu icon"
    />
  );
}
