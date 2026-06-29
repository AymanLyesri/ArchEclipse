import { exec, execAsync } from "ags/process";
import { monitorFile } from "ags/file";
import App from "ags/gtk4/app";
import { notify } from "./notification";
import { globalSettings } from "../variables";
import GLib from "gi://GLib";
import { timeout } from "ags/time";

// target css file
const tmpDir = `/tmp/ags-${GLib.get_user_name()}`;
const tmpCss = `${tmpDir}/tmp-style.css`;
const tmpScss = `${tmpDir}/tmp-style.scss`;
const scss_dir = `${GLib.get_home_dir()}/.config/ags/scss`;

const walScssColors = `${GLib.get_home_dir()}/.cache/cwal/colors.scss`;
const walCssColors = `${GLib.get_home_dir()}/.cache/cwal/colors.css`;
const defaultColors = `${GLib.get_home_dir()}/.config/ags/scss/defaultColors.scss`;

export const getCssPath = () => {
  refreshCss();
  return tmpCss;
};

export function refreshCss() {
  const scss = `${scss_dir}/style.scss`;

  exec(`bash -c "mkdir -p ${tmpDir} && echo '
        $OPACITY: ${globalSettings.peek().ui.opacity.value};
        $FONT-SIZE: ${globalSettings.peek().ui.fontSize.value}px;
        $SCALE: ${globalSettings.peek().ui.scale.value}px;
        ' | cat - ${defaultColors} \
        $([ -f ${walScssColors} ] && echo ${walScssColors}) \
        $([ -f ${walCssColors} ] && echo ${walCssColors}) \
        ${scss} > ${tmpScss} && sassc ${tmpScss} ${tmpCss} -I ${scss_dir}"`);

  App.reset_css();
  App.apply_css(tmpCss);

  // reset_css() transiently drops the styled sizes (font-size/scale/padding); GTK4 can
  // then leave a scrolledwindow's content clipped at the wrong height. Force every window
  // to re-measure so the layout settles to the freshly-applied CSS (this is what a manual
  // restart was doing — fixing the Super+L settings cutoff after a wallpaper/theme change).
  for (const win of App.get_windows()) {
    (win as any).queue_resize?.();
  }
}

// A wallpaper change rewrites the wal colors, which can fire the watcher several times in
// a burst; coalesce them so we don't thrash reset_css/apply_css (and the layout) repeatedly.
let cssReloadTimer: ReturnType<typeof timeout> | null = null;
function scheduleCssRefresh() {
  cssReloadTimer?.cancel?.();
  cssReloadTimer = timeout(250, () => {
    cssReloadTimer = null;
    refreshCss();
  });
}

monitorFile(
  // directory that contains the scss files
  `${scss_dir}`,
  () => scheduleCssRefresh(),
);

monitorFile(
  // directory that contains pywal colors
  `${GLib.get_home_dir()}/.cache/cwal/colors.scss`,
  () => scheduleCssRefresh(),
);
