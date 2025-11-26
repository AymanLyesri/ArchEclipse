import { execAsync } from "ags/process";
import { globalTheme, setGlobalTheme as setThemeState } from "../variables";

export const getGlobalTheme = async () =>
  execAsync([
    "bash",
    "-c",
    "$HOME/.config/hypr/theme/scripts/system-theme.sh get",
  ]).then((theme) => setThemeState(theme.includes("light")));

export const switchGlobalTheme = async () =>
  execAsync([
    "bash",
    "-c",
    "$HOME/.config/hypr/theme/scripts/set-global-theme.sh switch",
  ])
    .then(() => setThemeState(!globalTheme()))
    .catch(() => setThemeState(false));

export const setGlobalTheme = async (theme: string) =>
  execAsync([
    "bash",
    "-c",
    `$HOME/.config/hypr/theme/scripts/set-global-theme.sh switch ${theme}`,
  ])
    .then(() => setThemeState(theme.includes("light")))
    .catch(() => setThemeState(false));
