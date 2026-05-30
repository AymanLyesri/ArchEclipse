import { fetch } from "ags/fetch";
import { execAsync } from "ags/process";
import { notify } from "../utils/notification";
import GLib from "gi://GLib";

export interface SupabaseAuthUser {
  id: string;
  email: string;
  [key: string]: unknown;
}

export interface User {
  id: string;
  email: string;
  username: string | null;
  avatar: string | null;
  is_supporter: boolean | null;
}

export interface SupabaseSettingsRow {
  id: string;
  settings: Record<string, unknown>;
  updated_at: string | null;
}

export class Supabase {
  SUPABASE_URL = "https://skekmjmsgcbfhbwgpzkp.supabase.co";
  SUPABASE_PUB_KEY = "sb_publishable_PLXFIwBsb79Gfu3YkW5B-w_rHozkZ1y";
  HOME_FACE_ICON = `${GLib.get_home_dir()}/.face.icon`;

  /**
   * Request Supabase to send a magic link email to the user.
   * This uses the GoTrue /auth/v1/otp endpoint (POST). Requires `apikey` header.
   * Returns true if the request succeeded (email accepted by Supabase).
   */
  async sendMagicLinkEmail(
    email: string,
    redirectTo?: string,
  ): Promise<{ ok: boolean; error?: string }> {
    const url = `${this.SUPABASE_URL}/auth/v1/otp`;
    const body: Record<string, unknown> = {
      email,
      options: {
        shouldCreateUser: true,
        ...(redirectTo ? { emailRedirectTo: redirectTo } : {}),
      },
    };
    const res = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: this.SUPABASE_PUB_KEY,
        Authorization: `Bearer ${this.SUPABASE_PUB_KEY}`,
      },
      body: JSON.stringify(body),
    });

    if (res.ok) return { ok: true };

    let error = `HTTP ${res.status}`;
    try {
      const parsed = await res.json();
      error =
        parsed?.msg || parsed?.error_description || parsed?.error || error;
    } catch {
      try {
        const text = await res.text();
        if (text.trim()) error = text.trim();
      } catch {
        // keep fallback error
      }
    }

    return { ok: false, error };
  }

  async fetchCurrentUser(accessToken: string) {
    const res = await fetch(`${this.SUPABASE_URL}/auth/v1/user`, {
      headers: {
        apikey: this.SUPABASE_PUB_KEY,
        Authorization: `Bearer ${accessToken}`,
      },
    });

    if (!res.ok) {
      notify({
        summary: "Error fetching user",
        body: `HTTP ${res.status} - Failed to fetch current user. Check network and API key.`,
      });
      return null;
    }

    return await res.json();
  }

  async fetchCurrentUserProfile(accessToken: string): Promise<User | null> {
    const user = (await this.fetchCurrentUser(
      accessToken,
    )) as SupabaseAuthUser | null;

    if (!user?.id) return null;

    const [profileRes, supporterStatus] = await Promise.all([
      fetch(
        `${this.SUPABASE_URL}/rest/v1/user_profiles?select=id,username,avatar&id=eq.${encodeURIComponent(user.id)}`,
        {
          headers: {
            apikey: this.SUPABASE_PUB_KEY,
            Authorization: `Bearer ${accessToken}`,
          },
        },
      ),
      this.fetchSupporterStatus(accessToken, user.id),
    ]);

    if (!profileRes.ok) {
      return {
        id: user.id,
        email: user.email,
        username: null,
        avatar: null,
        is_supporter: supporterStatus,
      };
    }

    const profiles = (await profileRes.json()) as Array<{
      id: string;
      username: string | null;
      avatar: string | null;
    }>;

    const profile = profiles[0];

    if (!profile) {
      return {
        id: user.id,
        email: user.email,
        username: null,
        avatar: null,
        is_supporter: supporterStatus,
      };
    }

    return {
      id: profile.id,
      email: user.email,
      username: profile.username,
      avatar: profile.avatar,
      is_supporter: supporterStatus,
    };
  }

  async fetchSupporterStatus(
    accessToken: string,
    userId: string,
  ): Promise<boolean | null> {
    const res = await fetch(
      `${this.SUPABASE_URL}/rest/v1/supporters?select=id&id=eq.${encodeURIComponent(userId)}`,
      {
        headers: {
          apikey: this.SUPABASE_PUB_KEY,
          Authorization: `Bearer ${accessToken}`,
        },
      },
    );

    if (!res.ok) return null;

    const rows = (await res.json()) as Array<{ id: string }>;
    return rows.length > 0;
  }

  async syncAvatarToFaceIcon(avatarUrl: string) {
    if (!avatarUrl.trim()) return;

    try {
      await execAsync(["curl", "-fsSL", avatarUrl, "-o", this.HOME_FACE_ICON]);
    } catch (error) {
      notify({
        summary: "Avatar sync failed",
        body: String(error),
      });
    }
  }

  async updateCurrentUserProfile(
    accessToken: string,
    data: {
      username?: string;
      avatar?: string;
    },
  ): Promise<{ ok: boolean; error?: string }> {
    const user = (await this.fetchCurrentUser(
      accessToken,
    )) as SupabaseAuthUser | null;

    if (!user?.id) {
      return {
        ok: false,
        error: "Failed to fetch current user",
      };
    }

    const updateData: Record<string, unknown> = {};

    if (data.username !== undefined) {
      updateData.username = data.username;
    }
    if (data.avatar !== undefined) {
      updateData.avatar = data.avatar;
    }
    const res = await fetch(
      `${this.SUPABASE_URL}/rest/v1/user_profiles?id=eq.${encodeURIComponent(user.id)}`,
      {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          apikey: this.SUPABASE_PUB_KEY,
          Authorization: `Bearer ${accessToken}`,
          Prefer: "return=representation",
        },
        body: JSON.stringify(updateData),
      },
    );

    if (!res.ok) {
      let error = `HTTP ${res.status}`;

      try {
        const parsed = await res.json();

        error =
          parsed?.message ||
          parsed?.error_description ||
          parsed?.error ||
          error;
      } catch {
        try {
          const text = await res.text();

          if (text.trim()) error = text.trim();
        } catch {
          // ignore
        }
      }

      return {
        ok: false,
        error,
      };
    }

    return {
      ok: true,
    };
  }

  async uploadCurrentUserAvatar(
    accessToken: string,
    localFilePath: string,
    contentType: string,
  ): Promise<{ ok: boolean; avatarUrl?: string; error?: string }> {
    const user = (await this.fetchCurrentUser(
      accessToken,
    )) as SupabaseAuthUser | null;

    if (!user?.id) {
      return {
        ok: false,
        error: "Failed to fetch current user",
      };
    }

    // Prefer converting non-PNG inputs to PNG, but keep original behaviour as a
    // fallback: if conversion is not available or fails, upload the original file.
    const tmpDir = GLib.get_tmp_dir();
    const tmpJpg = `${tmpDir}/${user.id}-avatar.jpg`;

    // By default upload the original file. If conversion succeeds, upload the tmp PNG.
    let uploadSourcePath = localFilePath;
    let converted = false;

    // If the input already looks like a JPEG, skip conversion.
    if (!/\.jpe?g$/i.test(localFilePath)) {
      try {
        await execAsync(["magick", localFilePath, tmpJpg]);
        uploadSourcePath = tmpJpg;
        converted = true;
      } catch {
        try {
          await execAsync(["convert", localFilePath, tmpJpg]);
          uploadSourcePath = tmpJpg;
          converted = true;
        } catch (convErr) {
          notify({
            summary: "Image conversion warning",
            body: "Conversion failed, uploading original file.",
          });
          // fallback to original file
          uploadSourcePath = localFilePath;
          converted = false;
        }
      }
    }

    const extension = converted
      ? "jpg"
      : localFilePath.split(".").pop() || "bin";
    const filePath = `${user.id}.${extension}`;
    const uploadUrl = `${this.SUPABASE_URL}/storage/v1/object/avatars/${filePath}`;

    // Determine content-type header based on what we are uploading
    const contentTypeHeader = converted
      ? "image/jpeg"
      : contentType || "application/octet-stream";

    try {
      await execAsync([
        "curl",
        "-sS",
        "-X",
        "PUT",
        "-H",
        `Content-Type: ${contentTypeHeader}`,
        "-H",
        `apikey: ${this.SUPABASE_PUB_KEY}`,
        "-H",
        `Authorization: Bearer ${accessToken}`,
        "-H",
        "x-upsert: true",
        "--data-binary",
        `@${uploadSourcePath}`,
        uploadUrl,
      ]);
    } catch (error) {
      // attempt cleanup of tmp if created
      if (converted) {
        try {
          await execAsync(["rm", "-f", tmpJpg]);
        } catch {}
      }
      return {
        ok: false,
        error: String(error),
      };
    }

    // remove temp file if we created one
    if (converted) {
      try {
        await execAsync(["rm", "-f", tmpJpg]);
      } catch {}
    }

    const avatarUrl = `${this.SUPABASE_URL}/storage/v1/object/public/avatars/${filePath}`;

    const updateRes = await this.updateCurrentUserProfile(accessToken, {
      avatar: avatarUrl,
    });

    if (!updateRes.ok) {
      return {
        ok: false,
        error: updateRes.error,
      };
    }

    return {
      ok: true,
      avatarUrl,
    };
  }

  async fetchCurrentUserSettings(
    accessToken: string,
  ): Promise<SupabaseSettingsRow | null> {
    const user = (await this.fetchCurrentUser(
      accessToken,
    )) as SupabaseAuthUser | null;

    if (!user?.id) return null;

    const res = await fetch(
      `${this.SUPABASE_URL}/rest/v1/user_settings?select=id,settings,updated_at&id=eq.${encodeURIComponent(user.id)}`,
      {
        headers: {
          apikey: this.SUPABASE_PUB_KEY,
          Authorization: `Bearer ${accessToken}`,
        },
      },
    );

    if (!res.ok) return null;

    const rows = (await res.json()) as SupabaseSettingsRow[];
    return rows[0] ?? null;
  }

  async upsertCurrentUserSettings(
    accessToken: string,
    settings: Record<string, unknown>,
  ): Promise<{ ok: boolean; updated_at?: string; error?: string }> {
    const user = (await this.fetchCurrentUser(
      accessToken,
    )) as SupabaseAuthUser | null;

    if (!user?.id) {
      return {
        ok: false,
        error: "Failed to fetch current user",
      };
    }

    const payload = {
      id: user.id,
      settings,
      updated_at: new Date().toISOString(),
    };

    const res = await fetch(
      `${this.SUPABASE_URL}/rest/v1/user_settings?on_conflict=id`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          apikey: this.SUPABASE_PUB_KEY,
          Authorization: `Bearer ${accessToken}`,
          Prefer: "resolution=merge-duplicates,return=representation",
        },
        body: JSON.stringify(payload),
      },
    );

    if (!res.ok) {
      let error = `HTTP ${res.status}`;

      try {
        const parsed = await res.json();

        error =
          parsed?.message ||
          parsed?.error_description ||
          parsed?.error ||
          error;
      } catch {
        try {
          const text = await res.text();

          if (text.trim()) error = text.trim();
        } catch {
          // ignore
        }
      }

      return {
        ok: false,
        error,
      };
    }

    const rows = (await res.json()) as SupabaseSettingsRow[];
    return {
      ok: true,
      updated_at: rows[0]?.updated_at || payload.updated_at,
    };
  }
}
