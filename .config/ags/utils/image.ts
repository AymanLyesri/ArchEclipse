import { exec, execAsync } from "ags/process";
import { notify } from "./notification";
import { Waifu } from "../interfaces/waifu.interface";

import GdkPixbuf from "gi://GdkPixbuf";

const terminalWaifuPath = `$HOME/.config/fastfetch/assets/logo.webp`;

export function getDominantColor(imagePath: string) {
  return exec(`bash ./scripts/get-image-color.sh ${imagePath}`);
}

export function previewFloatImage(imagePath: string) {
  execAsync(`swayimg -w 690,690 --class 'preview-image' ${imagePath}`).catch(
    (err) => notify({ summary: "Error", body: err })
  );
}

export const PinImageToTerminal = (image: Waifu) => {
  execAsync(
    `bash -c "[ -f ${terminalWaifuPath} ] && { rm ${terminalWaifuPath}; echo 1; } || { cwebp -q 75 ${image.url_file_path} -o ${terminalWaifuPath}; echo 0; } && pkill -SIGUSR1 zsh"`
  )
    .then((output) =>
      notify({
        summary: "Waifu",
        body: `${
          Number(output) == 0 ? "Pinned To Terminal" : "UN-Pinned from Terminal"
        }`,
      })
    )
    .catch((err) => notify({ summary: "Error", body: err }));
};

export function getImageRatio(path: string): number {
  try {
    const pixbuf = GdkPixbuf.Pixbuf.new_from_file(path);
    return pixbuf.get_height() / pixbuf.get_width();
  } catch {
    return 1;
  }
}
