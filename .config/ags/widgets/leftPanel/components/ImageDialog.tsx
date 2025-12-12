import { closeProgress, openProgress } from "../../Progress";
import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import { booruApi, waifuCurrent, setWaifuCurrent } from "../../../variables";
import { Waifu } from "../../../interfaces/waifu.interface";

import { PinImageToTerminal, previewFloatImage } from "../../../utils/image";
import Gtk from "gi://Gtk?version=4.0";
import Gio from "gi://Gio";
const waifuPath = "./assets/booru/waifu";
const imageUrlPath = "./assets/booru/images";

const fetchImage = async (
  image: Waifu,
  savePath: string,
  name: string = ""
) => {
  // openProgress();
  const url = image.url!;
  name = name || String(image.id);
  image.url_path = `${savePath}/${name}.jpg`;

  await execAsync(`bash -c "mkdir -p ${savePath}"`).catch((err) =>
    notify({ summary: "Error", body: String(err) })
  );

  await execAsync(
    `bash -c "[ -e "${imageUrlPath}/${image.id}.jpg" ] || curl -o ${savePath}/${name}.jpg ${url}"`
  ).catch((err) => notify({ summary: "Error", body: String(err) }));
  // closeProgress();
};

const waifuThisImage = async (image: Waifu) => {
  execAsync(
    `bash -c "mkdir -p ${waifuPath} && cp ${image.url_path} ${waifuPath}/waifu.jpg"`
  )
    .then(() =>
      setWaifuCurrent({ ...image, url_path: waifuPath + "/waifu.jpg" })
    )
    .catch((err) =>
      notify({
        summary: "Error",
        body:
          String(err) +
          `bash -c "mkdir -p ${waifuPath} && cp ${image.url_path} ${waifuPath}/waifu.jpg"`,
      })
    );
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

const checkImageDownloaded = async (img: Waifu): Promise<boolean> => {
  try {
    const result = await execAsync(
      `bash -c "[ -e '${imageUrlPath}/${img.id}.jpg' ] && echo 'exists' || echo 'not-exists'"`
    );
    return result.trim() === "exists";
  } catch {
    return false;
  }
};

export class ImageDialog {
  private dialog: Gtk.Window | null = null;
  private imageDownloaded: boolean = false;
  private image: Waifu;
  private buttons: { button: Gtk.Revealer; needDownload: boolean }[] = [];

  constructor(img: Waifu) {
    this.image = img;

    // Check if image is already downloaded
    checkImageDownloaded(img).then((downloaded) => {
      this.imageDownloaded = downloaded;
      this.updateButtonStates();
    });
  }

  private createLayout(includeCloseButton: boolean = false): Gtk.Box {
    const buttonRefs: { button: Gtk.Revealer; needDownload: boolean }[] = [];

    // Create main vertical box to hold everything
    const mainBox = new Gtk.Box({
      cssClasses: ["dialog"],
      orientation: Gtk.Orientation.VERTICAL,
    });
    mainBox.set_margin_start(5);
    mainBox.set_margin_end(5);
    mainBox.set_margin_top(5);
    mainBox.set_margin_bottom(5);

    // create button box (only for window mode)
    if (includeCloseButton) {
      const buttonBoxTop = new Gtk.Box({
        orientation: Gtk.Orientation.HORIZONTAL,
        halign: Gtk.Align.END,
        spacing: 10,
      });
      const closeButton = new Gtk.Button({
        label: "",
        halign: Gtk.Align.CENTER,
        valign: Gtk.Align.CENTER,
      });
      closeButton.connect("clicked", () => {
        if (this.dialog && this.dialog.get_visible()) {
          this.dialog.close();
        }
      });
      buttonBoxTop.append(closeButton);
      mainBox.append(buttonBoxTop);
    }

    // Add image
    const image = new Gtk.Picture({
      file: Gio.File.new_for_path(this.image.preview_path!),
      cssClasses: ["image"],
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
    const buttonsDTO = [
      {
        icon: "",
        needImageDownload: false,
        tooltip: "Open in browser",
        response: 1,
      },
      {
        icon: "",
        needImageDownload: false,
        tooltip: "Download image",
        response: 2,
      },
      {
        icon: "",
        needImageDownload: true,
        tooltip: "Copy image",
        response: 3,
      },
      {
        icon: "",
        needImageDownload: true,
        tooltip: "Waifu this image",
        response: 4,
      },
      {
        icon: "",
        needImageDownload: true,
        tooltip: "Open image",
        response: 5,
      },
      {
        icon: "",
        needImageDownload: true,
        tooltip: "Pin to terminal",
        response: 6,
      },
      {
        icon: "󰸉",
        needImageDownload: true,
        tooltip: "Add to wallpapers",
        response: 7,
      },
    ];

    buttonsDTO.forEach((btnDTO) => {
      const btn = new Gtk.Button({
        label: btnDTO.icon,
        halign: Gtk.Align.CENTER,
        valign: Gtk.Align.CENTER,
      });

      const revealer = new Gtk.Revealer({
        transition_type: Gtk.RevealerTransitionType.SWING_RIGHT,
        transition_duration: 200,
        reveal_child: !btnDTO.needImageDownload,
      });

      btn.set_tooltip_text(btnDTO.tooltip);
      revealer.set_child(btn);

      if (btnDTO.needImageDownload) {
        buttonRefs.push({ button: revealer, needDownload: true });
      }

      btn.connect("clicked", () => {
        this.handleResponse(btnDTO.response, this.image);
      });

      buttonBox.append(revealer);
    });
    this.buttons = buttonRefs;

    mainBox.append(buttonBox);

    return mainBox;
  }

  public showAsWindow() {
    // Create window with close button
    this.dialog = new Gtk.Window({
      title: "booru-image",
      modal: false,
    });

    const layout = this.createLayout(true);
    this.dialog.set_child(layout);
    this.dialog.present();
  }

  public getBox(): Gtk.Box {
    // Create layout without close button for popover
    return this.createLayout(false);
  }

  private updateButtonStates() {
    this.buttons.forEach(({ button }) => {
      button.revealChild = this.imageDownloaded;
    });
  }

  private handleResponse(responseId: number, img: Waifu) {
    switch (responseId) {
      case 1:
        OpenInBrowser(img);
        break;
      case 2:
        fetchImage(img, imageUrlPath).finally(() => {
          print("Image downloaded", img.id);
          this.imageDownloaded = true;
          this.updateButtonStates();
        });
        break;
      case 3:
        CopyImage(img);
        break;
      case 4:
        waifuThisImage(img);
        break;
      case 5:
        OpenImage(img);
        break;
      case 6:
        PinImageToTerminal(img);
        break;
      case 7:
        addToWallpapers(img);
        break;
    }
  }
}
