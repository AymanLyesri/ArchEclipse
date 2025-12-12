import { closeProgress, openProgress } from "../../Progress";
import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import { booruApi, waifuCurrent, setWaifuCurrent } from "../../../variables";
import { Waifu } from "../../../interfaces/waifu.interface";
import { createState } from "ags";
import hyprland from "gi://AstalHyprland";
import { PinImageToTerminal, previewFloatImage } from "../../../utils/image";
import Gdk from "gi://Gdk?version=4.0";
import Gtk from "gi://Gtk?version=4.0";
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
      setWaifuCurrent({ ...image, url_path: waifuPath + "/waifu.jpg" })
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
  private dialog: Gtk.Window;
  private imageDownloaded: boolean = false;

  constructor(img: Waifu) {
    fetchImage(img, imageUrlPath).finally(() => {
      this.imageDownloaded = true;
      this.updateButtonStates();
    });
    // Create window (GTK 4 doesn't have Dialog with window_position)
    this.dialog = new Gtk.Window({
      title: "booru-image",
      modal: false,
    });

    // Create main vertical box to hold everything
    const mainBox = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
    });
    mainBox.set_margin_start(5);
    mainBox.set_margin_end(5);
    mainBox.set_margin_top(5);
    mainBox.set_margin_bottom(5);
    this.dialog.set_child(mainBox);

    // create button box
    const buttonBoxTop = new Gtk.Box({
      orientation: Gtk.Orientation.HORIZONTAL,
      halign: Gtk.Align.END,
      spacing: 10,
    });
    const closeButton = new Gtk.Button({
      label: "",
      halign: Gtk.Align.CENTER,
      valign: Gtk.Align.CENTER,
    });
    closeButton.connect("clicked", () => {
      this.dialog.close();
    });
    buttonBoxTop.append(closeButton);
    mainBox.append(buttonBoxTop);

    // Add image
    const image = new Gtk.Image({
      file: img.preview_path,
      hexpand: false,
      vexpand: false,
    });
    image.set_margin_top(10);
    mainBox.append(image);

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

    const buttonRefs: { button: Gtk.Button; needDownload: boolean }[] = [];
    buttons.forEach((btn) => {
      const button = new Gtk.Button({
        label: btn.icon,
        halign: Gtk.Align.CENTER,
        valign: Gtk.Align.CENTER,
        sensitive: btn.needImageDownload ? this.imageDownloaded : true,
      });

      if (btn.needImageDownload) {
        buttonRefs.push({ button, needDownload: true });
      }

      button.connect("clicked", () => {
        this.handleResponse(btn.response, img);
      });

      buttonBox.append(button);
    });
    this.buttons = buttonRefs;

    mainBox.append(buttonBox);

    this.dialog.present();
  }

  private buttons: { button: Gtk.Button; needDownload: boolean }[] = [];

  private updateButtonStates() {
    this.buttons.forEach(({ button }) => {
      button.set_sensitive(this.imageDownloaded);
    });
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
