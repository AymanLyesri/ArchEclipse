import { closeProgress, openProgress } from "../../Progress";
import { bind, execAsync, Variable } from "astal";
import { notify } from "../../../utils/notification";
import { booruApi, waifuCurrent } from "../../../variables";
import { Waifu } from "../../../interfaces/waifu.interface";

import hyprland from "gi://AstalHyprland";
import { PinImageToTerminal, previewFloatImage } from "../../../utils/image";
import { Gdk, Gtk } from "astal/gtk3";
import { Button } from "astal/gtk3/widget";
const Hyprland = hyprland.get_default();

const waifuPath = "./assets/booru/waifu";
const imageUrlPath = "./assets/booru/images";

const fetchImage = async (
  image: Waifu,
  savePath: string,
  name: string = ""
) => {
  openProgress();
  const url = image.url!;
  name = name || String(image.id);
  image.url_path = `${savePath}/${name}.jpg`;

  await execAsync(`bash -c "mkdir -p ${savePath}"`).catch((err) =>
    notify({ summary: "Error", body: String(err) })
  );

  await execAsync(
    `bash -c "[ -e "${imageUrlPath}/${image.id}.jpg" ] || curl -o ${savePath}/${name}.jpg ${url}"`
  ).catch((err) => notify({ summary: "Error", body: String(err) }));
  closeProgress();
};

const waifuThisImage = async (image: Waifu) => {
  execAsync(
    `bash -c "mkdir -p ${waifuPath} && cp ${image.url_path} ${waifuPath}/waifu.jpg"`
  )
    .then(() =>
      waifuCurrent.set({ ...image, url_path: waifuPath + "/waifu.jpg" })
    )
    .catch((err) => notify({ summary: "Error", body: String(err) }));
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
    `bash -c "wl-copy --type image/png < ${imageUrlPath}/${image.id}.jpg"`
  ).catch((err) => notify({ summary: "Error", body: err }));

const OpenImage = (image: Waifu) => {
  previewFloatImage(`${imageUrlPath}/${image.id}.jpg`);
};

const addToWallpapers = (image: Waifu) => {
  // copy image to wallpapers folder
  execAsync(
    `bash -c "cp ${image.url_path} ~/.config/wallpapers/custom/${image.id}.jpg"`
  )
    .then(() =>
      notify({ summary: "Success", body: "Image added to wallpapers" })
    )
    .catch((err) => notify({ summary: "Error", body: String(err) }));
};

export class ImageDialog {
  private dialog: Gtk.Dialog;
  private imageDownloaded = Variable<boolean>(false);

  constructor(img: Waifu) {
    fetchImage(img, imageUrlPath).finally(() => this.imageDownloaded.set(true));
    // Create dialog without default action area
    this.dialog = new Gtk.Dialog({
      title: "booru-image",
      window_position: Gtk.WindowPosition.CENTER,
      modal: false,
    });

    // Get content area
    const contentArea = this.dialog.get_content_area();

    // Create main vertical box to hold everything
    const mainBox = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
      margin: 5,
    });
    // const ctx = mainBox.get_style_context();
    // ctx.add_class("module");
    contentArea.add(mainBox);

    // create button box
    const buttonBoxTop = new Gtk.Box({
      orientation: Gtk.Orientation.HORIZONTAL,
      halign: Gtk.Align.END,
      spacing: 10,
    });
    const closeButton = new Button({
      label: "",
      halign: Gtk.Align.CENTER,
      valign: Gtk.Align.CENTER,
    });
    closeButton.connect("clicked", () => {
      this.dialog.destroy();
    });
    buttonBoxTop.add(closeButton);
    mainBox.add(buttonBoxTop);

    // Add image
    const image = new Gtk.Image({
      file: img.preview_path,
      hexpand: false,
      vexpand: false,
      marginTop: 10,
    });
    mainBox.add(image);

    // Create centered button box
    const buttonBox = new Gtk.Box({
      orientation: Gtk.Orientation.HORIZONTAL,
      halign: Gtk.Align.CENTER,
      spacing: 10,
      marginTop: 10,
    });

    // Create buttons with icons
    const buttons = [
      {
        icon: "",
        needImageDownload: false,
        tooltip: "Open in browser",
        response: 1,
      },
      {
        icon: "",
        needImageDownload: true,
        tooltip: "Copy image",
        response: 2,
      },
      {
        icon: "",
        needImageDownload: true,
        tooltip: "Waifu this image",
        response: 3,
      },
      {
        icon: "",
        needImageDownload: true,
        tooltip: "Open image",
        response: 4,
      },
      {
        icon: "",
        needImageDownload: true,
        tooltip: "Pin to terminal",
        response: 5,
      },
      {
        icon: "󰸉",
        needImageDownload: true,
        tooltip: "Add to wallpapers",
        response: 6,
      },
    ];

    buttons.forEach((btn) => {
      const button = new Button({
        label: btn.icon,
        halign: Gtk.Align.CENTER, // Center horizontally
        valign: Gtk.Align.CENTER, // Center vertically
        sensitive: btn.needImageDownload ? bind(this.imageDownloaded) : true,
      });

      // Add CSS class for styling
      // const ctx = button.get_style_context();
      // ctx.add_class("image-dialog-button");

      button.connect("clicked", () => {
        this.handleResponse(btn.response, img);
        // this.dialog.destroy();
      });

      buttonBox.add(button);
    });

    mainBox.add(buttonBox);

    this.dialog.show_all();
  }

  private handleResponse(responseId: number, img: Waifu) {
    switch (responseId) {
      case 1:
        OpenInBrowser(img);
        break;
      case 2:
        CopyImage(img);
        break;
      case 3:
        waifuThisImage(img);
        break;
      case 4:
        OpenImage(img);
        break;
      case 5:
        PinImageToTerminal(img);
        break;
      case 6:
        addToWallpapers(img);
        break;
    }
  }
}
