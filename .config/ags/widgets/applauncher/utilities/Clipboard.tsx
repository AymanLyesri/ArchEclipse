import { execAsync } from "ags/process";
import GLib from "gi://GLib";

import { LauncherApp } from "../../../interfaces/app.interface";
import { readJSONFile } from "../../../utils/json";
import { notify } from "../../../utils/notification";

const CLIPBOARD_HISTORY_PATH = `${GLib.get_home_dir()}/.config/ags/cache/launcher/clipboard-history.json`;
const CLIPBOARD_PREVIEW_MAX_LENGTH = 120;

type ClipboardHistoryEntry = {
  id?: number;
  timestamp?: number;
  type?: string;
  content?: string;
  mimeType?: string;
};

type NormalizedClipboardEntry = {
  id: number;
  timestamp: number;
  type: string;
  content: string;
  mimeType: string;
  preview: string;
  searchableText: string;
};

const stripHtml = (value: string): string =>
  value
    .replace(/<[^>]*>/g, " ")
    .replace(/\s+/g, " ")
    .trim();

const truncateText = (value: string, maxLength: number): string => {
  if (value.length <= maxLength) return value;
  return `${value.slice(0, maxLength - 1)}…`;
};

export const parseClipboardQuery = (value: string): string | null => {
  const normalized = value.trimStart();
  if (!/^cb /i.test(normalized)) return null;
  return normalized.slice(3).trim();
};

const normalizeClipboardEntries = (
  entries: unknown,
  maxItems: number,
): NormalizedClipboardEntry[] => {
  if (!Array.isArray(entries)) return [];

  return entries
    .map((entry: ClipboardHistoryEntry, index) => {
      const content =
        typeof entry.content === "string" ? entry.content.trim() : "";
      if (!content) return null;

      const type =
        typeof entry.type === "string" && entry.type.trim()
          ? entry.type.trim().toLowerCase()
          : "text";
      const mimeType =
        typeof entry.mimeType === "string" && entry.mimeType.trim()
          ? entry.mimeType.trim().toLowerCase()
          : "text/plain";

      const fallbackTimestamp = Math.max(0, entries.length - index);
      const timestamp =
        typeof entry.timestamp === "number"
          ? entry.timestamp
          : fallbackTimestamp;
      const id = typeof entry.id === "number" ? entry.id : fallbackTimestamp;

      const isImage = type === "image" || mimeType.startsWith("image/");
      const basename = GLib.path_get_basename(content) || content;

      const textPreview = mimeType.includes("html")
        ? stripHtml(content)
        : content;
      const preview = isImage
        ? truncateText(`🖼 ${basename}`, CLIPBOARD_PREVIEW_MAX_LENGTH)
        : truncateText(textPreview || "(empty)", CLIPBOARD_PREVIEW_MAX_LENGTH);

      const searchableText = isImage
        ? `${content} ${basename} ${mimeType} ${type} image`
        : `${textPreview} ${content} ${mimeType} ${type} text html`;

      return {
        id,
        timestamp,
        type,
        content,
        mimeType,
        preview,
        searchableText: searchableText.toLowerCase(),
      };
    })
    .filter((entry): entry is NormalizedClipboardEntry => Boolean(entry))
    .sort((a, b) => b.timestamp - a.timestamp)
    .slice(0, maxItems);
};

const copyClipboardEntry = (entry: NormalizedClipboardEntry) => {
  const isImage = entry.type === "image" || entry.mimeType.startsWith("image/");

  if (isImage) {
    const quotedPath = `'${entry.content.replace(/'/g, `"'"'`)}'`;
    const quotedMime = `'${entry.mimeType.replace(/'/g, `"'"'`)}'`;

    execAsync([
      "bash",
      "-lc",
      `if [ -f ${quotedPath} ]; then wl-copy --type ${quotedMime} < ${quotedPath}; else echo "Missing image file"; exit 1; fi`,
    ])
      .then(() => {
        notify({
          summary: "Clipboard",
          body: `Copied image (${entry.mimeType}) to clipboard`,
        });
      })
      .catch((err) => {
        notify({
          summary: "Clipboard",
          body: err instanceof Error ? err.message : String(err),
        });
      });

    return;
  }

  execAsync(["wl-copy", "--type", entry.mimeType, entry.content]).catch(
    (err) => {
      notify({
        summary: "Clipboard",
        body: err instanceof Error ? err.message : String(err),
      });
    },
  );
};

export const getClipboardResults = (
  clipboardQuery: string,
  maxItems: number,
): LauncherApp[] => {
  const clipboardEntries = normalizeClipboardEntries(
    readJSONFile(CLIPBOARD_HISTORY_PATH, []),
    maxItems,
  );
  const searchTerm = clipboardQuery.toLowerCase();
  const filteredEntries = searchTerm
    ? clipboardEntries.filter((entry) =>
        entry.searchableText.includes(searchTerm),
      )
    : clipboardEntries;

  return filteredEntries.map((entry) => ({
    app_name: entry.preview,
    app_description: `${entry.mimeType} • ${entry.type}`,
    app_type: "clipboard",
    app_launch: () => copyClipboardEntry(entry),
  }));
};
