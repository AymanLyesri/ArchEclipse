import { exec } from "ags/process";
import { monitorFile } from "ags/file";
import App from "ags/gtk4/app";
import { notify } from "./notification";
import { globalSettings } from "../variables";

// target css file
const tmpCss = `/tmp/tmp-style.css`;
const tmpScss = `/tmp/tmp-style.scss`;
const scss_dir = `./scss`;

const walScssColors = `./../../.cache/wal/colors.scss`;
const walCssColors = `./../../.cache/wal/colors.css`;
const defaultColors = `./scss/defaultColors.scss`;

export const getCssPath = () => {
  refreshCss();
  return tmpCss;
};

export function refreshCss() {
  const scss = `./scss/style.scss`;

  try {
    exec(`bash -c "echo '
        $OPACITY: ${globalSettings.peek().ui.opacity.value};
        $FONT-SIZE: ${globalSettings.peek().ui.fontSize.value}px;
        $SCALE: ${globalSettings.peek().ui.scale.value}px;
        ' | cat - ${defaultColors} ${walScssColors} ${walCssColors} ${scss} > ${tmpScss} && sassc ${tmpScss} ${tmpCss} -I ${scss_dir}"`);

    App.reset_css();
    App.apply_css(tmpCss);
  } catch (e) {
    notify({ summary: `Error while generating css`, body: String(e) });
    console.error(e);
  }
}

monitorFile(
  // directory that contains the scss files
  `./scss`,
  () => refreshCss(),
);

monitorFile(
  // directory that contains pywal colors
  `./../../.cache/wal/colors.scss`,
  () => refreshCss(),
);
