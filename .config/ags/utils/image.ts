import { exec, execAsync } from "ags/process";
import { notify } from "./notification";
import GdkPixbuf from "gi://GdkPixbuf";
import GLib from "gi://GLib";

export function getDominantColor(imagePath: string) {
  return exec(
    `bash ${GLib.get_home_dir()}/.config/ags/scripts/get-image-color.sh ${imagePath}`,
  );
}

export function previewFloatImage(imagePath: string) {
  execAsync(`swayimg -w 690,690 --class 'preview-image' ${imagePath}`).catch(
    (err) => notify({ summary: "Error", body: err }),
  );
}

export function getImageRatio(path: string): number {
  try {
    const pixbuf = GdkPixbuf.Pixbuf.new_from_file(path);
    return pixbuf.get_height() / pixbuf.get_width();
  } catch {
    return 1;
  }
}
