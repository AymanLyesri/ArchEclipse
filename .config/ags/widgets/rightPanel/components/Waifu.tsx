import { createBinding, execAsync, createState, createComputed } from "ags";
import {
  waifuApi,
  setWaifuApi,
  globalSettings,
  globalTransition,
  rightPanelWidth,
  waifuCurrent,
  setWaifuCurrent,
} from "../../../variables";
import Gtk from "gi://Gtk?version=3.0";
import GLib from "gi://GLib";
import ToggleButton from "../../toggleButton";
import { getSetting, setSetting } from "../../../utils/settings";
import { notify } from "../../../utils/notification";

import { closeProgress, openProgress } from "../../Progress";
import { Api } from "../../../interfaces/api.interface";
import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();

import { Waifu } from "../../../interfaces/waifu.interface";
import { readJson } from "../../../utils/json";
import { booruApis } from "../../../constants/api.constants";
import { PinImageToTerminal, previewFloatImage } from "../../../utils/image";
const waifuDir = "./assets/booru/waifu";

const fetchImage = async (image: Waifu, saveDir: string) => {
  const url = image.url!;
  image.url_path = `${saveDir}/waifu.webp`;

  await execAsync(`bash -c "mkdir -p ${saveDir}"`).catch((err) =>
    notify({ summary: "Error", body: String(err) })
  );

  await execAsync(`curl -o ${image.url_path} ${url}`).catch((err) =>
    notify({ summary: "Error", body: String(err) })
  );
  return image;
};

const GetImageByid = async (id: number) => {
  openProgress();
  try {
    const res = await execAsync(
      `python ./scripts/search-booru.py 
    --api ${waifuApi().value} 
    --id ${id}`
    );

    const image: Waifu = readJson(res)[0];

    fetchImage(image, waifuDir).then((image: Waifu) => {
      setWaifuCurrent({
        ...image,
        url_path: waifuDir + "/waifu.webp",
        api: waifuApi(),
      });
    });
    closeProgress();
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
  }
};

const OpenInBrowser = (image: Waifu) =>
  execAsync(
    `bash -c "xdg-open '${image.api.idSearchUrl}${
      waifuCurrent().id
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
      className="input"
      placeholderText="enter post ID"
      text={getSetting("waifu.input_history")}
      onActivate={(self) => {
        setSetting("waifu.input_history", self.text);
        GetImageByid(Number(self.text));
      }}
    />
  );

  const actions = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transition_type={Gtk.RevealerTransitionType.SLIDE_UP}
      child={
        <eventbox
          className="bottom-eventbox"
          child={
            <box className={"bottom-bar"} vertical>
              <box className={"top"}>
                <button
                  label=""
                  className="open"
                  hexpand
                  onClicked={() => OpenImage(waifuCurrent())}
                />
                <button
                  label=""
                  hexpand
                  className="browser"
                  onClicked={() => OpenInBrowser(waifuCurrent())}
                />
                <button
                  label=""
                  hexpand
                  className="pin"
                  onClicked={() => PinImageToTerminal(waifuCurrent())}
                />
                <button
                  label=""
                  hexpand
                  className="copy"
                  onClicked={() => CopyImage(waifuCurrent())}
                />
              </box>
              <box>
                <button
                  hexpand
                  label=""
                  className="entry-search"
                  onClicked={() => Entry.activate()}
                />
                {Entry}
                <button
                  hexpand
                  label={""}
                  className={"upload"}
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
                      // Use GLib.spawn_command_line_sync instead of exec
                      const [res, stdout, stderr, status] =
                        GLib.spawn_command_line_sync(
                          `identify -format "%h %w" ${filename}`
                        );
                      let [height, width] = new TextDecoder()
                        .decode(stdout)
                        .trim()
                        .split(" ");

                      execAsync(`cp ${filename} ${waifuCurrent().url_path}`)
                        .then(() =>
                          setWaifuCurrent({
                            id: 0,
                            preview: waifuCurrent().url_path,
                            height: Number(height) ?? 0,
                            width: Number(width) ?? 0,
                            api: {} as Api,
                            url_path: waifuCurrent().url_path,
                          })
                        )
                        .finally(() =>
                          notify({
                            summary: "Waifu",
                            body: "Custom image set",
                          })
                        )
                        .catch((err) =>
                          notify({ summary: "Error", body: err })
                        );
                    }
                    dialog.destroy();
                  }}
                />
              </box>
              <box className={"bottom"}>
                {booruApis.map((api) => (
                  <ToggleButton
                    hexpand
                    className={"api"}
                    label={api.name}
                    state={createComputed(() => waifuApi().value === api.value)}
                    onToggled={(self, on) => setWaifuApi(api)}
                  />
                ))}
              </box>
            </box>
          }
        />
      }
    ></revealer>
  );

  const bottom = (
    <box className="bottom" vertical vexpand valign={Gtk.Align.END}>
      {
        <ToggleButton
          label=""
          className="action-trigger"
          halign={Gtk.Align.END}
          onToggled={(self, on) => {
            actions.reveal_child = on;
            self.label = on ? "" : "";
            actions.reveal_child = on;
          }}
        />
      }
      {actions}
    </box>
  );

  return (
    <box className="layout" vertical child={bottom}>
      {/* {top} */}
    </box>
  );
}

function Image() {
  return (
    <eventbox
      // onClicked={OpenInBrowser}
      child={
        <box
          className="image"
          hexpand={false}
          vexpand={false}
          heightRequest={createComputed(
            () =>
              (Number(waifuCurrent().height) / Number(waifuCurrent().width)) *
              rightPanelWidth()
          )}
          css={createComputed(
            () => `background-image: url("${waifuCurrent().url_path}");`
          )}
          child={Actions()}
        ></box>
      }
    ></eventbox>
  );
}

export default () => {
  return (
    <revealer
      transitionDuration={globalTransition}
      transition_type={Gtk.RevealerTransitionType.SLIDE_DOWN}
      revealChild={createComputed(() => globalSettings().waifu.visibility)}
      child={<box className="waifu" vertical child={Image()}></box>}
    ></revealer>
  );
};

export function WaifuVisibility() {
  return ToggleButton({
    state: createComputed(() => globalSettings().waifu.visibility),
    onToggled: (self, on) => setSetting("waifu.visibility", on),
    label: "󱙣",
    className: "waifu icon",
  });
}
