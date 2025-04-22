import { bind, exec, execAsync, Variable } from "astal";
import {
  waifuApi,
  globalSettings,
  globalTransition,
  rightPanelWidth,
  waifuCurrent,
} from "../../../variables";
import { Gtk } from "astal/gtk3";
import ToggleButton from "../../toggleButton";
import { getSetting, setSetting } from "../../../utils/settings";
import { notify } from "../../../utils/notification";

import { closeProgress, openProgress } from "../../Progress";
import { Api } from "../../../interfaces/api.interface";
import hyprland from "gi://AstalHyprland";
const Hyprland = hyprland.get_default();

import { Waifu } from "../../../interfaces/waifu.interface";
import { readJson } from "../../../utils/json";
import { booruApis } from "../../../constants/api.constants";
import { PinImageToTerminal, previewFloatImage } from "../../../utils/image";
const waifuDir = "./assets/booru/waifu";

const terminalWaifuPath = `./assets/terminal/icon.webp`;

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
    --api ${waifuApi.get().value} 
    --id ${id}`
    );

    const image: Waifu = readJson(res)[0];

    fetchImage(image, waifuDir).then((image: Waifu) => {
      waifuCurrent.set({
        ...image,
        url_path: waifuDir + "/waifu.webp",
        api: waifuApi.get(),
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
        <box className={"actions"} vertical>
          <box className={"top"}>
            <button
              label=""
              className="open"
              hexpand
              onClicked={() => OpenImage(waifuCurrent.get())}
            />
            <button
              label=""
              hexpand
              className="browser"
              onClicked={() => OpenInBrowser(waifuCurrent.get())}
            />
            <button
              label=""
              hexpand
              className="pin"
              onClicked={() => PinImageToTerminal(waifuCurrent.get())}
            />
            <button
              label=""
              hexpand
              className="copy"
              onClicked={() => CopyImage(waifuCurrent.get())}
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
                  let [height, width] = exec(
                    `identify -format "%h %w" ${filename}`
                  ).split(" ");
                  execAsync(`cp ${filename} ${waifuCurrent.get().url_path}`)
                    .then(() =>
                      waifuCurrent.set({
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
          <box className={"bottom"}>
            {booruApis.map((api) => (
              <ToggleButton
                hexpand
                className={"api"}
                label={api.name}
                state={bind(waifuApi).as(
                  (current) => current.value === api.value
                )}
                onToggled={(self, on) => waifuApi.set(api)}
              />
            ))}
          </box>
        </box>
      }></revealer>
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
          heightRequest={bind(
            Variable.derive(
              [waifuCurrent, rightPanelWidth],
              (waifuCurrent, width) =>
                (Number(waifuCurrent.height) / Number(waifuCurrent.width)) *
                width
            )
          )}
          css={bind(waifuCurrent).as(
            (waifuCurrent) =>
              `background-image: url("${waifuCurrent.url_path}");`
          )}
          child={Actions()}></box>
      }></eventbox>
  );
}

export default () => {
  return (
    <revealer
      transitionDuration={globalTransition}
      transition_type={Gtk.RevealerTransitionType.SLIDE_DOWN}
      revealChild={globalSettings.get().waifu.visibility}
      child={
        <eventbox
          className="waifu-event"
          child={
            <box className="waifu" vertical child={Image()}></box>
          }></eventbox>
      }></revealer>
  );
};

export function WaifuVisibility() {
  return ToggleButton({
    state: bind(globalSettings).as((s) => s.waifu.visibility),
    onToggled: (self, on) => setSetting("waifu.visibility", on),
    label: "󱙣",
    className: "waifu icon",
  });
}
