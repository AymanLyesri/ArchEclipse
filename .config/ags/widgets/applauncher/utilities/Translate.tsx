import { execAsync } from "ags/process";
import GLib from "gi://GLib";

import { LauncherApp } from "../../../interfaces/app.interface";

const escapeSingleQuotes = (value: string) => value.replace(/'/g, `'"'"'`);

export const parseTranslateQuery = (
  value: string,
): { sourceText: string; language: string } | null => {
  const normalized = value.trimStart();
  if (!/^translate /i.test(normalized)) return null;

  const withoutPrefix = normalized.slice("translate".length).trim();
  if (!withoutPrefix) return null;

  const [sourcePart, targetPart] = withoutPrefix
    .split(">", 2)
    .map((part) => part.trim());

  return {
    sourceText: sourcePart,
    language: targetPart || "en",
  };
};

export const getTranslateResults = async (
  sourceText: string,
  language: string,
): Promise<LauncherApp[]> => {
  const escapedSource = escapeSingleQuotes(sourceText);
  const escapedLanguage = escapeSingleQuotes(language);

  const translation = await execAsync(
    `bash ${GLib.get_home_dir()}/.config/ags/scripts/translate.sh '${escapedSource}' '${escapedLanguage}'`,
  );

  return [
    {
      app_name: translation,
      app_launch: () => execAsync(["wl-copy", translation]),
    },
  ];
};
