import { exec, execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import {
  booruApi,
  waifuCurrent,
  setWaifuCurrent,
  booruBookMarkWaifus,
  setBooruBookMarkWaifus,
} from "../../../variables";
import { Waifu } from "../../../interfaces/waifu.interface";

import { PinImageToTerminal, previewFloatImage } from "../../../utils/image";
import Gtk from "gi://Gtk?version=4.0";
import Gio from "gi://Gio";
import {
  booruImagesPath,
  booruPreviewPath,
} from "../../../constants/path.constants";
import Picture from "../../Picture";
import { Accessor, createState } from "gnim";
import { Eventbox } from "../../Custom/Eventbox";

export default ({ image }: { image: Waifu }) => {
  const checkImageDownloaded = (image: Waifu): boolean => {
    const result = exec(
      `bash -c "[ -e '${booruImagesPath}/${image.id}.${image.extension}' ] && echo 'exists' || echo 'not-exists'"`
    );
    return result.trim() === "exists";
  };

  const bookMarkExists = (image: Waifu): boolean => {
    const currentBookmarks = booruBookMarkWaifus.get();
    return currentBookmarks.some(
      (img) => img.id === image.id && img.api.value === image.api.value
    );
  };

  const [isDownloaded, setIsDownloaded] = createState<boolean>(
    checkImageDownloaded(image)
  );
  const [isBookmarked, setIsBookmarked] = createState<boolean>(
    bookMarkExists(image)
  );

  // Create buttons with icons
  const buttonsDTO: {
    icon: string;
    sensitive: boolean | Accessor<boolean>;
    tooltip: string;
    response: (image: Waifu) => void;
  }[] = [
    {
      icon: "",
      sensitive: true,
      tooltip: "Open in browser",
      response: (image: Waifu) => OpenInBrowser(image),
    },
    {
      icon: "",
      sensitive: true,
      tooltip: "Download image",
      response: (image: Waifu) => fetchImage(image, booruImagesPath),
    },
    {
      icon: "",
      sensitive: isDownloaded,
      tooltip: "Copy image",
      response: (image: Waifu) => CopyImage(image),
    },
    {
      icon: "",
      sensitive: isDownloaded,
      tooltip: "Waifu this image",
      response: (image: Waifu) => waifuThisImage(image),
    },
    {
      icon: "",
      sensitive: isDownloaded,
      tooltip: "Open image",
      response: (image: Waifu) => OpenImage(image),
    },
    {
      icon: "",
      sensitive: isDownloaded,
      tooltip: "Pin to terminal",
      response: (image: Waifu) => PinImageToTerminal(image),
    },
    {
      icon: "󰸉",
      sensitive: isDownloaded,
      tooltip: "Add to wallpapers",
      response: (image: Waifu) => addToWallpapers(image),
    },
    {
      icon: "",
      sensitive: true,
      tooltip: "Bookmark image",
      response: (image: Waifu) => bookMarkImage(image),
    },
    // remove bookmark button
    {
      icon: "󰧌",
      sensitive: isBookmarked,
      tooltip: "Remove bookmark",
      response: (image: Waifu) => removeBookMarkImage(image),
    },
  ];

  const fetchImage = async (image: Waifu, savePath: string) => {
    // openProgress();
    const url = image.url!;

    await execAsync(`bash -c "mkdir -p ${savePath}"`).catch((err) =>
      notify({ summary: "Error", body: String(err) })
    );

    await execAsync(
      `bash -c "[ -e "${savePath}/${image.id}.${image.extension}" ] || curl -o ${savePath}/${image.id}.${image.extension} ${url}"`
    )
      .then(() => setIsDownloaded(true))
      .catch((err) => notify({ summary: "Error", body: String(err) }));
  };

  const waifuThisImage = async (image: Waifu) => {
    print(
      "Set waifu to",
      image.id,
      `${booruImagesPath}/${image.id}.${image.extension}`
    );
    setWaifuCurrent({ ...image });
  };

  const OpenInBrowser = (image: Waifu) =>
    execAsync(
      `bash -c "xdg-open '${booruApi.get().idSearchUrl}${
        image.id
      }' && xdg-settings get default-web-browser | sed 's/\.desktop$//'"`
    )
      .then((browser) =>
        notify({ summary: "Waifu", body: `opened in ${browser}` })
      )
      .catch((err) => notify({ summary: "Error", body: err }));

  const CopyImage = (image: Waifu) =>
    execAsync(
      `bash -c "wl-copy --type image/png < ${booruImagesPath}/${image.id}.${image.extension}"`
    ).catch((err) => notify({ summary: "Error", body: err }));

  const OpenImage = (image: Waifu) => {
    previewFloatImage(`${booruImagesPath}/${image.id}.${image.extension}`);
  };

  const addToWallpapers = (image: Waifu) => {
    // copy image to wallpapers folder
    execAsync(
      `bash -c "cp ${booruImagesPath}/${image.id}.${image.extension} ~/.config/wallpapers/custom/${image.id}.${image.extension}"`
    )
      .then(() =>
        notify({ summary: "Success", body: "Image added to wallpapers" })
      )
      .catch((err) => notify({ summary: "Error", body: String(err) }));
  };

  const bookMarkImage = (image: Waifu) => {
    const currentBookmarks = booruBookMarkWaifus.get();
    // check if image is already bookmarked
    const exists = bookMarkExists(image);
    if (exists) {
      notify({ summary: "Info", body: "Image already bookmarked" });
      return;
    }

    const updatedBookmarks = [...currentBookmarks, image];
    setBooruBookMarkWaifus(updatedBookmarks);
    setIsBookmarked(true);
    notify({ summary: "Success", body: "Image bookmarked" });
  };

  const removeBookMarkImage = (image: Waifu) => {
    const currentBookmarks = booruBookMarkWaifus.get();
    const updatedBookmarks = currentBookmarks.filter(
      (img) => !(img.id === image.id && img.api.value === image.api.value)
    );
    setBooruBookMarkWaifus(updatedBookmarks);
    setIsBookmarked(false);
    notify({ summary: "Success", body: "Bookmark removed" });
  };

  function Actions() {
    return (
      <Eventbox
        class={"actions"}
        onHover={(self) => {
          const revealer = self.get_first_child() as Gtk.Revealer;
          revealer.reveal_child = true;
        }}
        onHoverLost={(self) => {
          const revealer = self.get_first_child() as Gtk.Revealer;
          revealer.reveal_child = false;
        }}
      >
        <revealer
          class={"actions-revealer"}
          transition-type={Gtk.RevealerTransitionType.SWING_UP}
        >
          <box
            spacing={10}
            valign={Gtk.Align.END}
            orientation={Gtk.Orientation.VERTICAL}
          >
            <box class={"section"}>
              <button
                label=""
                tooltip-text="Open in browser"
                sensitive={true}
                onClicked={() => OpenInBrowser(image)}
              />
              <togglebutton
                class={"button"}
                label={isBookmarked((bookmarked) => (bookmarked ? "󰧌" : ""))}
                tooltip-text="Bookmark image"
                active={isBookmarked}
                onClicked={(self) => {
                  if (self.active) bookMarkImage(image);
                  else removeBookMarkImage(image);
                }}
              />
            </box>
            <box class={"section"}>
              <button
                label=""
                tooltip-text="Download image"
                sensitive={isDownloaded((is) => !is)}
                onClicked={() => fetchImage(image, booruImagesPath)}
              />
              <button
                label=""
                tooltip-text="Copy image"
                sensitive={isDownloaded}
                onClicked={() => CopyImage(image)}
              />
              <button
                label=""
                tooltip-text="Waifu this image"
                sensitive={isDownloaded}
                onClicked={() => waifuThisImage(image)}
              />
              <button
                label=""
                tooltip-text="Open image"
                sensitive={isDownloaded}
                onClicked={() => OpenImage(image)}
              />
              <button
                label=""
                tooltip-text="Pin to terminal"
                sensitive={isDownloaded}
                onClicked={() => PinImageToTerminal(image)}
              />
              <button
                label="󰸉"
                tooltip-text="Add to wallpapers"
                sensitive={isDownloaded}
                onClicked={() => addToWallpapers(image)}
              />
            </box>
          </box>
        </revealer>
      </Eventbox>
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
      <overlay>
        <Picture
          file={`${booruPreviewPath}/${image.id}.${image.extension}`}
          height={imageRatio >= 1 ? 300 : 300 / imageRatio}
          width={imageRatio >= 1 ? 300 * imageRatio : 300}
          class="image"
        />
        <Actions $type="overlay" />
      </overlay>
    </box>
  );
  return mainBox;
};
