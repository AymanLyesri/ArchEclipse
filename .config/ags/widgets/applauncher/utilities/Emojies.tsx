import { execAsync } from "ags/process";
import GLib from "gi://GLib";

import { LauncherApp } from "../../../interfaces/app.interface";
import { readJSONFile } from "../../../utils/json";

type EmojiEntry = {
  app_tags: string;
  app_name: string;
};

const EMOJIS_PATH = `${GLib.get_home_dir()}/.config/ags/assets/emojis/emojis.json`;

export const parseEmojiQuery = (value: string): string | null => {
  const normalized = value.trimStart();
  if (!/^emoji /i.test(normalized)) return null;
  return normalized.slice(6).trim().toLowerCase();
};

export const getEmojiResults = (query: string): LauncherApp[] => {
  const emojis: EmojiEntry[] = readJSONFile(EMOJIS_PATH, []);

  return emojis
    .filter((emoji) => emoji.app_tags.toLowerCase().includes(query))
    .map((emoji) => ({
      app_name: emoji.app_name,
      app_icon: emoji.app_name,
      app_type: "emoji",
      app_launch: () => execAsync(["wl-copy", emoji.app_name]),
    }));
};
