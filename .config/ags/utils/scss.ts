import { execAsync } from "ags/process";
import { monitorFile } from "ags/file";
import App from "ags/gtk3/app";
import {
  globalFontSize,
  globalIconSize,
  globalOpacity,
  globalScale,
} from "../variables";
import { notify } from "./notification";

// target css file
const tmpCss = `/tmp/tmp-style.css`;
const tmpScss = `/tmp/tmp-style.scss`;
const scss_dir = `./scss`;

const walColors = `./../../.cache/wal/colors.scss`;
const defaultColors = `./scss/defaultColors.scss`;

export const getCssPath = () => {
  refreshCss();
  return tmpCss;
};

export async function refreshCss() {
  const scss = `./scss/style.scss`;

  try {
    await execAsync(`bash -c "echo '
        $OPACITY: ${globalOpacity};
        $ICON-SIZE: ${globalIconSize}px;
        $FONT-SIZE: ${globalFontSize}px;
        $SCALE: ${globalScale}px;
        ' | cat - ${defaultColors} ${walColors} ${scss} > ${tmpScss} && sassc ${tmpScss} ${tmpCss} -I ${scss_dir}"`);

    // App.reset_css();
    // App.apply_css(tmpCss);
  } catch (e) {
    notify({ summary: `Error while generating css`, body: String(e) });
    console.error(e);
  }
}

monitorFile(
  // directory that contains the scss files
  `./scss`,
  () => refreshCss()
);

monitorFile(
  // directory that contains pywal colors
  `./../../.cache/wal/colors.scss`,
  () => refreshCss()
);
