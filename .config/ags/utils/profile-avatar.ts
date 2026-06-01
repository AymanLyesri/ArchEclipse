import { execAsync } from "ags/process";
import { timeout } from "ags/time";
import GLib from "gi://GLib";
import Gio from "gi://Gio";
import { Supabase } from "../class/Supabase.class";
import { MAXAVATARSIZE } from "../constants/profile.constants";
import { refreshAuthSession } from "./auth-session";
import { notify } from "./notification";

type AvatarProgressStatus = "loading" | "error" | "success" | "idle";

type AvatarProgressHandler = (
  status: AvatarProgressStatus,
  text: string,
) => void;

const avatarContentTypeByPath = (path: string) => {
  const extension = path.split(".").pop()?.toLowerCase();

  switch (extension) {
    case "png":
      return "image/png";
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "webp":
      return "image/webp";
    default:
      return null;
  }
};

export const setProfileAvatarFromPath = async (
  path: string,
  options?: {
    onProgress?: AvatarProgressHandler;
    thumbnailPath?: string;
  },
): Promise<{ ok: boolean; localOnly?: boolean; avatarUrl?: string }> => {
  const onProgress = options?.onProgress;
  const setProgress = (status: AvatarProgressStatus, text: string) => {
    onProgress?.(status, text);
  };

  const getFileSize = (filePath: string): number | null => {
    try {
      const file = Gio.File.new_for_path(filePath);
      if (!file.query_exists(null)) return null;
      const info = file.query_info(
        "standard::size",
        Gio.FileQueryInfoFlags.NONE,
        null,
      );
      return Number(info.get_size());
    } catch {
      return null;
    }
  };

  const normalizedSize = (size: number) => {
    if (size < 1024) return `${size} B`;
    if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
    return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  };

  const thumbnailPath = options?.thumbnailPath;
  const fileSize = getFileSize(path);
  const thumbnailSize = thumbnailPath ? getFileSize(thumbnailPath) : null;
  if (
    typeof fileSize === "number" &&
    fileSize > MAXAVATARSIZE &&
    typeof thumbnailSize !== "number"
  ) {
    notify({
      summary: "Avatar too large",
      body: `Image exceeds ${normalizedSize(MAXAVATARSIZE)}`,
    });
    return { ok: false };
  }
  const useThumbnail =
    typeof fileSize === "number" &&
    fileSize > MAXAVATARSIZE &&
    typeof thumbnailSize === "number";
  const avatarPath = useThumbnail ? thumbnailPath! : path;

  const contentType = avatarContentTypeByPath(avatarPath);
  if (!contentType) {
    notify({
      summary: "Invalid image",
      body: "Pick a PNG, JPG, or WebP file.",
    });
    return { ok: false };
  }

  const session = await refreshAuthSession();

  if (!session?.access_token) {
    setProgress("loading", "Updating local avatar...");
    notify({
      summary: "Not signed in",
      body: "Updating local avatar only. Sign in to sync across devices.",
    });

    try {
      await execAsync(["cp", avatarPath, `${GLib.get_home_dir()}/.face.icon`]);

      setProgress("success", "Avatar updated locally");
      notify({
        summary: "Avatar updated",
        body: "Using the selected picture locally.",
      });
      return { ok: true, localOnly: true };
    } catch (copyError) {
      setProgress("error", "Local update failed");
      notify({
        summary: "Local update failed",
        body: String(copyError),
      });
      return { ok: false };
    }
  }

  setProgress("loading", "Uploading avatar...");

  const supabaseClient = new Supabase();
  const result = await supabaseClient.uploadCurrentUserAvatar(
    session.access_token,
    avatarPath,
    contentType,
  );

  if (result.ok) {
    setProgress("success", "Avatar updated");
    notify({
      summary: "Avatar updated",
      body: "Your profile picture has been uploaded.",
    });
    notify({
      summary: "Syncing avatar",
      body: "Updating your profile picture (10s). This may take a few seconds.",
    });
    timeout(10000, () => {
      supabaseClient.syncAvatarToFaceIcon(result.avatarUrl!);
    });
    return { ok: true, avatarUrl: result.avatarUrl };
  }

  setProgress("error", "Upload failed");
  notify({
    summary: "Upload failed",
    body: result.error || "Failed to upload profile picture.",
  });
  return { ok: false };
};
