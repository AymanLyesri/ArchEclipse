import { exec, execAsync } from "ags/process";
import { monitorFile } from "ags/file";
import App from "ags/gtk4/app";
import { notify } from "./notification";
import { globalSettings } from "../variables";
import GLib from "gi://GLib";

// target css file
const tmpCss = `/tmp/tmp-style.css`;
const tmpScss = `/tmp/tmp-style.scss`;
const scss_dir = `${GLib.get_home_dir()}/.config/ags/scss`;

const walScssColors = `${GLib.get_home_dir()}/.cache/wal/colors.scss`;
const walCssColors = `${GLib.get_home_dir()}/.cache/wal/colors.css`;
const defaultColors = `${GLib.get_home_dir()}/.config/ags/scss/defaultColors.scss`;

export const getCssPath = () => {
  refreshCss();
  return tmpCss;
};

export function refreshCss() {
  const scss = `${scss_dir}/style.scss`;

  execAsync(`bash -c "echo '
        $OPACITY: ${globalSettings.peek().ui.opacity.value};
        $FONT-SIZE: ${globalSettings.peek().ui.fontSize.value}px;
        $SCALE: ${globalSettings.peek().ui.scale.value}px;
        ' | cat - ${defaultColors} ${walScssColors} ${walCssColors} ${scss} > ${tmpScss} && sassc ${tmpScss} ${tmpCss} -I ${scss_dir}"`)
    .then(() => {
      App.reset_css();
      App.apply_css(tmpCss);
    })
    .catch((e) => {
      notify({ summary: `Error while generating css`, body: String(e) });
      console.error(e);
    });

  // App.reset_css();
  // App.apply_css(tmpCss);
}

monitorFile(
  // directory that contains the scss files
  `${scss_dir}`,
  () => refreshCss(),
);

monitorFile(
  // directory that contains pywal colors
  `${GLib.get_home_dir()}/.cache/wal/colors.scss`,
  () => refreshCss(),
);
