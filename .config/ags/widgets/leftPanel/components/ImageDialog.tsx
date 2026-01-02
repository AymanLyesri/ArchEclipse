import { exec, execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import { Waifu } from "../../../interfaces/waifu.interface";

import {
  bookMarkExists,
  bookMarkImage,
  fetchImage,
  OpenInBrowser,
  PinImageToTerminal,
  previewFloatImage,
  removeBookMarkImage,
} from "../../../utils/image";
import Gtk from "gi://Gtk?version=4.0";
import Gio from "gi://Gio";
import Picture from "../../Picture";
import { Accessor, createState } from "gnim";
import { Eventbox } from "../../Custom/Eventbox";
import { booruPath } from "../../../constants/path.constants";
import Pango from "gi://Pango";
import { setGlobalSetting } from "../../../variables";

export default ({ image }: { image: Waifu }) => {
  const checkImageDownloaded = (image: Waifu): boolean => {
    const result = exec(
      `bash -c "[ -e '${booruPath}/${image.api.value}/images/${image.id}.${image.extension}' ] && echo 'exists' || echo 'not-exists'"`
    );
    return result.trim() === "exists";
  };

  const [isDownloaded, setIsDownloaded] = createState<boolean>(
    checkImageDownloaded(image)
  );
  const [isBookmarked, setIsBookmarked] = createState<boolean>(
    bookMarkExists(image)
  );

  const waifuThisImage = async (image: Waifu) => {
    print(
      "Set waifu to",
      image.id,
      `${booruPath}/${image.api.value}/images/${image.id}.${image.extension}`
    );
    setGlobalSetting("waifu.current", { ...image });
  };

  const CopyImage = (image: Waifu) =>
    execAsync(
      `bash -c "wl-copy --type image/png < ${booruPath}/${image.api.value}/images/${image.id}.${image.extension}"`
    ).catch((err) => notify({ summary: "Error", body: err }));

  const OpenImage = (image: Waifu) => {
    previewFloatImage(
      `${booruPath}/${image.api.value}/images/${image.id}.${image.extension}`
    );
  };

  const addToWallpapers = (image: Waifu) => {
    // copy image to wallpapers folder
    execAsync(
      `bash -c "cp ${booruPath}/${image.api.value}/images/${image.id}.${image.extension} ~/.config/wallpapers/custom/${image.id}.${image.extension}"`
    )
      .then(() =>
        notify({ summary: "Success", body: "Image added to wallpapers" })
      )
      .catch((err) => notify({ summary: "Error", body: String(err) }));
  };

  const Tags = () => {
    return (
      <Gtk.FlowBox
        class="tags"
        // orientation={Gtk.Orientation.HORIZONTAL}
        rowSpacing={5}
        columnSpacing={5}
      >
        {image.tags !== undefined &&
          image.tags.slice(0, 10).map((tag) => (
            <button
              class="tag"
              tooltipText={tag}
              onClicked={() => {
                execAsync(`bash -c "echo -n '${tag}' | wl-copy"`).catch((err) =>
                  notify({ summary: "Error", body: String(err) })
                );
              }}
            >
              <label
                ellipsize={Pango.EllipsizeMode.END}
                maxWidthChars={10}
                label={tag}
              ></label>
            </button>
          ))}
      </Gtk.FlowBox>
    );
  };

  function Actions() {
    return (
      <box
        class={"actions"}
        spacing={10}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <box class={"section"}>
          <button
            label=""
            tooltip-text="Open in browser"
            sensitive={true}
            onClicked={() => OpenInBrowser(image)}
            hexpand
          />
          <togglebutton
            class={"button"}
            label={isBookmarked((bookmarked) => (bookmarked ? "󰧌" : ""))}
            tooltip-text="Bookmark image"
            active={isBookmarked}
            onClicked={(self) => {
              if (self.active) {
                bookMarkImage(image);
                setIsBookmarked(true);
              } else {
                removeBookMarkImage(image);
                setIsBookmarked(false);
              }
            }}
            hexpand
          />
        </box>
        <box class={"section"}>
          <button
            label=""
            tooltip-text="Download image"
            sensitive={isDownloaded((is) => !is)}
            onClicked={() =>
              fetchImage(image)
                .then(() => setIsDownloaded(true))
                .catch((err) => notify({ summary: "Error", body: String(err) }))
            }
            hexpand
          />
          <button
            label=""
            tooltip-text="Copy image"
            sensitive={isDownloaded}
            onClicked={() => CopyImage(image)}
            hexpand
          />
          <button
            label=""
            tooltip-text="Waifu this image"
            sensitive={isDownloaded}
            onClicked={() => waifuThisImage(image)}
            hexpand
          />
          <button
            label=""
            tooltip-text="Open image"
            sensitive={isDownloaded}
            onClicked={() => OpenImage(image)}
            hexpand
          />
          <button
            label=""
            tooltip-text="Pin to terminal"
            sensitive={isDownloaded}
            onClicked={() => PinImageToTerminal(image)}
            hexpand
          />
          <button
            label="󰸉"
            tooltip-text="Add to wallpapers"
            sensitive={isDownloaded}
            onClicked={() => addToWallpapers(image)}
            hexpand
          />
        </box>
      </box>
    );
  }

  const imageRatio = image.width / image.height;
  const mainBox = (
    <box
      class="image-dialog"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
      $={async (self) => {
        setIsDownloaded(await checkImageDownloaded(image));
      }}
    >
      <overlay
        widthRequest={imageRatio >= 1 ? 300 * imageRatio : 300}
        heightRequest={imageRatio >= 1 ? 300 : 300 / imageRatio}
      >
        <Picture
          file={isDownloaded((is) =>
            is
              ? `${booruPath}/${image.api.value}/images/${image.id}.${image.extension}`
              : `${booruPath}/${image.api.value}/previews/${image.id}.${image.extension}`
          )}
          height={imageRatio >= 1 ? 300 : 300 / imageRatio}
          width={imageRatio >= 1 ? 300 * imageRatio : 300}
          class="image"
        />
        <box
          $type="overlay"
          orientation={Gtk.Orientation.VERTICAL}
          widthRequest={imageRatio >= 1 ? 300 * imageRatio : 300}
          heightRequest={imageRatio >= 1 ? 300 : 300 / imageRatio}
        >
          <Tags />
          <box vexpand />
          <Actions />
        </box>
      </overlay>
    </box>
  );
  return mainBox;
};
