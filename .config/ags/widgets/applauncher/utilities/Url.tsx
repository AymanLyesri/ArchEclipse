import { execAsync } from "ags/process";

import { LauncherApp } from "../../../interfaces/app.interface";
import { notify } from "../../../utils/notification";
import {
  containsProtocolOrTLD,
  formatToURL,
  getDomainFromURL,
} from "../../../utils/url";

export const isUrlQuery = (value: string): boolean => {
  const firstToken = value.trim().split(/\s+/)[0] || "";
  return containsProtocolOrTLD(firstToken);
};

export const getUrlResults = (value: string): LauncherApp[] => [
  {
    app_name: getDomainFromURL(value),
    app_launch: async () => {
      await execAsync(`xdg-open ${formatToURL(value)}`);
      const browser = await execAsync(
        "bash -lc \"xdg-settings get default-web-browser | sed 's/\\.desktop$//'\"",
      );
      notify({
        summary: "URL",
        body: `Opening ${value} in ${browser}`,
      });
    },
  },
];
