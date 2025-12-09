import { createState, createComputed, createBinding } from "ags";
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
import { closeProgress, openProgress } from "../../Progress";
import { Api } from "../../../interfaces/api.interface";
import hyprland from "gi://AstalHyprland";
import { Waifu } from "../../../interfaces/waifu.interface";
import { readJson } from "../../../utils/json";
import { booruApis } from "../../../constants/api.constants";
import { PinImageToTerminal, previewFloatImage } from "../../../utils/image";
import { Eventbox } from "../../Custom/Eventbox";
import Gio from "gi://Gio?version=2.0";
import Picture from "../../Picture";
const waifuDir = "./assets/booru/waifu";

const fetchImage = async (image: Waifu, saveDir: string) => {
  const url = image.url!;
  image.url_path = `${saveDir}/waifu.webp`;

  await execAsync(`bash -c "mkdir -p ${saveDir}"`).catch((err) => {
    print("Error creating waifu directory:", err);
    notify({ summary: "Error", body: String(err) });
  });

  await execAsync(`curl -o ${image.url_path} ${url}`).catch((err) => {
    print("Error downloading waifu image:", err);
    notify({ summary: "Error", body: String(err) });
  });
  return image;
};

const GetImageByid = async (id: number) => {
  // openProgress();
  try {
    const res = await execAsync(
      `python ./scripts/search-booru.py 
    --api ${waifuApi.get().value} 
    --id ${id}`
    );

    const image: Waifu = readJson(res)[0];

    fetchImage(image, waifuDir)
      .then((image: Waifu) => {
        setWaifuCurrent({
          ...image,
          url_path: waifuDir + "/waifu.webp",
          api: waifuApi.get(),
        });
      })
      .catch(() => {
        print("Failed to fetch image");
      });
    // closeProgress();
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    print("Error fetching waifu by ID:", err);
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
  execAsync(`bash -c "wl-copy --type image/png < ${image.url_path}"`).catch(
    (err) => notify({ summary: "Error", body: err })
  );

const OpenImage = (image: Waifu) => previewFloatImage(image.url_path!);

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

  const actions = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transition_type={Gtk.RevealerTransitionType.SLIDE_UP}
    >
      <box
        class="bottom-bar"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
      >
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
            onClicked={() => Entry.activate()}
          />
          {Entry}
          <button
            hexpand
            label={""}
            class="upload"
            onClicked={() => {
              let dialog = new Gtk.FileChooserDialog({
                title: "Open Image",
                action: Gtk.FileChooserAction.OPEN,
              });
              dialog.add_button("Open", Gtk.ResponseType.OK);
              dialog.add_button("Cancel", Gtk.ResponseType.CANCEL);
              let response = dialog.run();
              if (response == Gtk.ResponseType.OK) {
                let filename = dialog.get_filename();
                let [height, width] = exec(
                  `identify -format "%h %w" ${filename}`
                ).split(" ");
                execAsync(`cp ${filename} ${waifuCurrent.get().url_path}`)
                  .then(() =>
                    setWaifuCurrent({
                      id: 0,
                      preview: waifuCurrent.get().url_path,
                      height: Number(height) ?? 0,
                      width: Number(width) ?? 0,
                      api: {} as Api,
                      url_path: waifuCurrent.get().url_path,
                    })
                  )
                  .finally(() =>
                    notify({
                      summary: "Waifu",
                      body: "Custom image set",
                    })
                  )
                  .catch((err) => notify({ summary: "Error", body: err }));
              }
              dialog.destroy();
            }}
          />
        </box>
        <box class="section">
          {booruApis.map((api) => (
            <togglebutton
              hexpand
              class="api"
              label={api.name}
              active={waifuApi((current) => current.value === api.value)}
              onToggled={({ active }) => setWaifuApi(api)}
            />
          ))}
        </box>
      </box>
    </revealer>
  );

  const bottom = (
    <box
      class="bottom"
      orientation={Gtk.Orientation.VERTICAL}
      vexpand
      valign={Gtk.Align.END}
    >
      {
        <togglebutton
          label=""
          class="action-trigger"
          halign={Gtk.Align.END}
          onToggled={(self) => {
            actions.reveal_child = self.active;
            self.label = self.active ? "" : "";
            actions.reveal_child = self.active;
          }}
        />
      }
      {actions}
    </box>
  );

  return (
    <box class="layout" orientation={Gtk.Orientation.VERTICAL}>
      {bottom}
    </box>
  );
}

function Image() {
  const imageHeight = createComputed(
    [waifuCurrent, rightPanelWidth],
    (current, width) => {
      print("Waifu Image Dimensions:", current.width, "x", current.height);
      return (Number(current.height) / Number(current.width)) * (width - 50);
    }
  );

  return (
    <overlay class={"overlay"}>
      <Picture
        class="image"
        height={imageHeight}
        file={waifuCurrent((w) => w.url_path || "")}
        contentFit={Gtk.ContentFit.COVER}
      />
      <Actions $type="overlay" />
    </overlay>
  );
}

export default () => {
  return (
    <revealer
      transitionDuration={globalTransition}
      transition_type={Gtk.RevealerTransitionType.SLIDE_DOWN}
      revealChild={globalSettings((s) => s.waifu.visibility)}
    >
      <box class="waifu" orientation={Gtk.Orientation.VERTICAL}>
        {Image()}
      </box>
    </revealer>
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
