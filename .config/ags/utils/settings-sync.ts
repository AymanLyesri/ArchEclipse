import Gio from "gi://Gio";
import GLib from "gi://GLib";
import { Supabase } from "../class/Supabase.class";
import { defaultSettings } from "../constants/settings.constants";
import { Settings } from "../interfaces/settings.interface";
import { globalSettings, setGlobalSettings } from "../variables";
import { refreshAuthSession } from "./auth-session";
import { readJSONFile, writeJSONFile } from "./json";
import { autoCreateSettings, settingsPath } from "./settings";

export type SettingsSyncDirection = "upload" | "download" | "noop";

export interface SettingsSyncResult {
  ok: boolean;
  direction?: SettingsSyncDirection;
  error?: string;
}

interface SettingsSyncMeta {
  lastSyncAt?: string;
  lastDirection?: SettingsSyncDirection;
  lastRemoteUpdatedAt?: string;
}

const settingsSyncMetaPath = `${GLib.get_home_dir()}/.config/ags/cache/settings/settings-sync.json`;

const sanitizeSettings = (settings: Settings): Settings => {
  const cloned = JSON.parse(JSON.stringify(settings)) as Settings;

  if (cloned.apiKeys) {
    for (const provider of Object.keys(cloned.apiKeys)) {
      const entry = (cloned.apiKeys as any)[provider];
      if (entry?.user) entry.user.value = "";
      if (entry?.key) entry.key.value = "";
    }
  }

  return cloned;
};

const readLocalSettings = (): Settings =>
  readJSONFile<Settings>(settingsPath, defaultSettings);

const getLocalSettingsModifiedAt = (): Date | null => {
  try {
    const file = Gio.File.new_for_path(settingsPath);

    if (!file.query_exists(null)) return null;

    const info = file.query_info(
      "time::modified",
      Gio.FileQueryInfoFlags.NONE,
      null,
    );
    const seconds = info.get_attribute_uint64("time::modified");

    return new Date(Number(seconds) * 1000);
  } catch {
    return null;
  }
};

const persistSyncMeta = (meta: SettingsSyncMeta) => {
  writeJSONFile(settingsSyncMetaPath, meta);
};

const applyRemoteSettings = (remote: Settings) => {
  const local = readLocalSettings();
  const merged = {
    ...remote,
    apiKeys: local.apiKeys,
  };

  writeJSONFile(settingsPath, merged);
  autoCreateSettings(globalSettings.peek(), setGlobalSettings);
};

export const syncSettingsWithSupabase =
  async (): Promise<SettingsSyncResult> => {
    const session = await refreshAuthSession();

    if (!session?.access_token) {
      return {
        ok: false,
        error: "Not signed in",
      };
    }

    const supabase = new Supabase();
    const remoteRow = await supabase.fetchCurrentUserSettings(
      session.access_token,
    );

    const localSettings = readLocalSettings();
    const localModifiedAt = getLocalSettingsModifiedAt();
    const remoteUpdatedAt = remoteRow?.updated_at
      ? new Date(remoteRow.updated_at)
      : null;

    if (!remoteRow?.settings) {
      const upload = await supabase.upsertCurrentUserSettings(
        session.access_token,
        sanitizeSettings(localSettings) as any as Record<string, unknown>,
      );

      if (!upload.ok) {
        return {
          ok: false,
          error: upload.error || "Failed to upload settings",
        };
      }

      persistSyncMeta({
        lastSyncAt: new Date().toISOString(),
        lastDirection: "upload",
        lastRemoteUpdatedAt: upload.updated_at,
      });

      return {
        ok: true,
        direction: "upload",
      };
    }

    const shouldDownload =
      !localModifiedAt ||
      (remoteUpdatedAt && remoteUpdatedAt > localModifiedAt);

    if (shouldDownload) {
      applyRemoteSettings(remoteRow.settings as any as Settings);

      persistSyncMeta({
        lastSyncAt: new Date().toISOString(),
        lastDirection: "download",
        lastRemoteUpdatedAt: remoteRow.updated_at || undefined,
      });

      return {
        ok: true,
        direction: "download",
      };
    }

    const upload = await supabase.upsertCurrentUserSettings(
      session.access_token,
      sanitizeSettings(localSettings) as any as Record<string, unknown>,
    );

    if (!upload.ok) {
      return {
        ok: false,
        error: upload.error || "Failed to upload settings",
      };
    }

    persistSyncMeta({
      lastSyncAt: new Date().toISOString(),
      lastDirection: "upload",
      lastRemoteUpdatedAt: upload.updated_at,
    });

    return {
      ok: true,
      direction: "upload",
    };
  };
