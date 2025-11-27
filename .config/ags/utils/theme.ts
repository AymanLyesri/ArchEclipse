import { execAsync } from "ags/process";
import { globalTheme, setGlobalTheme } from "../variables";

// export const getGlobalTheme = async () =>
//   execAsync([
//     "bash",
//     "-c",
//     "$HOME/.config/hypr/theme/scripts/system-theme.sh get",
//   ]).then((theme) => setThemeState(theme.includes("light")));

export const switchGlobalTheme = async (theme: boolean) =>
  execAsync([
    "bash",
    "-c",
    `$HOME/.config/hypr/theme/scripts/set-global-theme.sh switch ${
      theme ? "light" : "dark"
    }`,
  ]);
