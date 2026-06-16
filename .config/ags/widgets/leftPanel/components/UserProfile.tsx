import { createState, With } from "gnim";
import { authSessionPath } from "../../../utils/auth-session";
import Picture from "../../Picture";
import { Gtk } from "ags/gtk4";
import { Supabase, User } from "../../../class/Supabase.class";
import { notify } from "../../../utils/notification";
import { refreshAuthSession } from "../../../utils/auth-session";
import {
  readSettingsSyncMeta,
  settingsSyncMetaPath,
  SettingsSyncDirection,
  syncSettingsWithSupabase,
} from "../../../utils/settings-sync";
import { execAsync } from "ags/process";
import { globalSettings, profilePicturePath } from "../../../variables";
import { monitorFile } from "ags/file";
import { Progress } from "../../Progress";
import GLib from "gi://GLib";
import { booruApis } from "../../../constants/api.constants";
import Gio from "gi://Gio";
import {
  clearUserProfile,
  updateUserProfile,
} from "../../../utils/user-profile";
import { setProfileAvatarFromPath } from "../../../utils/profile-avatar";

export default (minimal?: boolean) => {
  const supabaseClient = new Supabase();
  const [profile, setProfile] = createState<User | null>(null);
  const [progressStatus, setProgressStatus] = createState<
    "loading" | "error" | "success" | "idle"
  >("idle");
  const [progressText, setProgressText] = createState("Not signed in");
  const [isSyncing, setIsSyncing] = createState(false);
  const [isRefreshing, setIsRefreshing] = createState(false);
  const [pinnedCount, setPinnedCount] = createState(0);
  const [lastSyncAt, setLastSyncAt] = createState<string | null>(null);
  const [lastSyncDirection, setLastSyncDirection] =
    createState<SettingsSyncDirection | null>(null);
  const [lastRemoteUpdatedAt, setLastRemoteUpdatedAt] = createState<
    string | null
  >(null);

  const fastfetchCacheDir = `${GLib.get_home_dir()}/.config/fastfetch/cache`;

  const updatePinnedCount = () => {
    try {
      const cacheDir = Gio.File.new_for_path(fastfetchCacheDir);

      if (!cacheDir.query_exists(null)) {
        setPinnedCount(0);
        return;
      }

      const enumerator = cacheDir.enumerate_children(
        "standard::name,standard::type",
        Gio.FileQueryInfoFlags.NONE,
        null,
      );
      let count = 0;
      for (
        let info = enumerator.next_file(null);
        info !== null;
        info = enumerator.next_file(null)
      ) {
        if (info.get_file_type() === Gio.FileType.REGULAR) {
          count += 1;
        }
      }
      enumerator.close(null);
      setPinnedCount(count);
    } catch {
      setPinnedCount(0);
    }
  };

  const loadProfile = async () => {
    const session = await refreshAuthSession();

    if (!session?.access_token) {
      setProfile(null);
      clearUserProfile();
      setProgressStatus("idle");
      setProgressText("Not signed in");
      return;
    }

    setProgressStatus("loading");
    setProgressText("Loading profile...");

    try {
      const fetchedProfile = await supabaseClient.fetchCurrentUserProfile(
        session.access_token,
      );

      if (!fetchedProfile) {
        setProgressStatus("error");
        setProgressText("Signed in, but profile not found");
        return;
      }

      setProfile(fetchedProfile);
      updateUserProfile(fetchedProfile);

      if (fetchedProfile.avatar) {
        supabaseClient.syncAvatarToFaceIcon(fetchedProfile.avatar);
      }

      setProgressStatus("idle");
      setProgressText(
        `${fetchedProfile.username ?? "No username"} • ${fetchedProfile.is_supporter ? "Supporter" : "Member"}`,
      );
    } catch (error) {
      console.error("Failed to load profile:", error);
      setProfile(null);
      setProgressStatus("error");
      setProgressText("Failed to load profile");
    }
  };

  const emailLabel = profile((p) => {
    const email = p?.email ?? "No email";
    const [localPart, domain] = email.split("@");

    if (!localPart || !domain) return email;

    return `${localPart[0]}***@${domain}`;
  });

  const booruFavoriteCounts = globalSettings(({ booru }) => {
    const counts: Record<string, number> = Object.fromEntries(
      booruApis.map((api) => [api.value, 0]),
    );

    for (const bookmark of booru.bookmarks ?? []) {
      const apiValue = bookmark?.api?.value;
      if (apiValue && typeof counts[apiValue] === "number") {
        counts[apiValue] += 1;
      }
    }

    return counts;
  });

  const formatTimestamp = (value: string | null) => {
    if (!value) return "Never";
    const parsed = Date.parse(value);
    if (Number.isNaN(parsed)) return "Never";
    const timestamp = Math.floor(parsed / 1000);
    const dateTime = GLib.DateTime.new_from_unix_local(timestamp);
    return dateTime.format("%Y-%m-%d %H:%M");
  };

  const applySettingsSyncMeta = () => {
    const meta = readSettingsSyncMeta();
    setLastSyncAt(meta?.lastSyncAt ?? null);
    setLastSyncDirection(meta?.lastDirection ?? null);
    setLastRemoteUpdatedAt(meta?.lastRemoteUpdatedAt ?? null);
  };

  const lastSyncLabel = lastSyncAt(
    (value) => `Last sync: ${formatTimestamp(value)}`,
  );
  const lastSyncResult = lastSyncDirection((direction) => {
    if (!direction) return "Last result: -";
    if (direction === "noop") return "Last result: Up to date";
    if (direction === "download") return "Last result: Downloaded";
    return "Last result: Uploaded";
  });
  const lastRemoteUpdatedLabel = lastRemoteUpdatedAt(
    (value) => `Remote updated: ${formatTimestamp(value)}`,
  );

  const MagicLinkEmail = () => {
    const emailEntry = (
      <entry
        placeholderText="you@example.com"
        hexpand
        $={(self) => {
          self.text = "";
        }}
        onActivate={(self) => {
          const entryText = self.text.trim();
          sendMagicLink(entryText);
        }}
      />
    ) as Gtk.Entry;

    const sendButton = (
      <button
        class="donation-button primary auth-submit"
        label="Sign up / Login"
        onClicked={() => {
          const entryText = emailEntry.text.trim();
          sendMagicLink(entryText);
        }}
      />
    ) as Gtk.Button;

    const sendMagicLink = async (email: string) => {
      if (!email) {
        notify({ summary: "Email", body: "Enter a valid email" });
        return;
      }

      const supabaseClient = new Supabase();

      const result = await supabaseClient.sendMagicLinkEmail(
        email,
        "http://127.0.0.1:53100/callback",
      );
      if (result.ok) {
        notify({
          summary: "Magic link sent",
          body: `Check ${email} and open the link to complete sign-in.`,
        });
        sendButton.label = "Check email...";
      } else {
        notify({
          summary: "Error",
          body:
            result.error ||
            "Failed to send magic link. Check network and API key.",
        });
      }
    };

    const box = (
      <box
        class="auth-section"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        hexpand
        visible={!minimal}
      >
        <box
          class="auth-info"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={6}
          halign={Gtk.Align.START}
        >
          <label class="auth-title" label="Login to sync:" xalign={0} />
          <box
            class="auth-list"
            orientation={Gtk.Orientation.VERTICAL}
            spacing={4}
          >
            <label class="auth-item" label="- Profile picture" xalign={0} />
            <label class="auth-item" label="- Settings" xalign={0} />
            <label class="auth-note" label="More to come" xalign={0} />
          </box>
        </box>
        <box
          class="auth-cta"
          spacing={6}
          hexpand
          orientation={Gtk.Orientation.VERTICAL}
        >
          {emailEntry}
          {sendButton}
        </box>
      </box>
    );

    return box;
  };

  return (
    <box
      spacing={10}
      class="user-profile"
      orientation={Gtk.Orientation.VERTICAL}
      $={() => {
        loadProfile();
        updatePinnedCount();
        applySettingsSyncMeta();

        monitorFile(`${GLib.get_home_dir()}/.config/ags/cache/auth`, () => {
          loadProfile();
        });
        monitorFile(fastfetchCacheDir, () => {
          updatePinnedCount();
        });
        monitorFile(settingsSyncMetaPath, () => {
          applySettingsSyncMeta();
        });
      }}
    >
      <box class="main" spacing={10} orientation={Gtk.Orientation.VERTICAL}>
        <box halign={Gtk.Align.CENTER}>
          <button
            class="profile-picture"
            tooltipMarkup={"Click to set up profile picture"}
            onClicked={async () => {
              try {
                const filename = await execAsync(
                  'zenity --file-selection --title="Select Profile Picture" --file-filter="Images (png, jpg, webp) | *.png *.jpg *.jpeg *.webp"',
                );

                if (!filename || filename.trim() === "") return;

                const cleanPath = filename.trim();

                await setProfileAvatarFromPath(cleanPath, {
                  onProgress: (status, text) => {
                    setProgressStatus(status);
                    setProgressText(text);
                  },
                });
              } catch (err) {
                const errorStr = String(err);
                if (errorStr.includes("exit status 1")) return;

                notify({
                  summary: "Error",
                  body: errorStr,
                });
              }
            }}
          >
            <Picture
              width={globalSettings(({ leftPanel }) => leftPanel.width / 2)}
              height={globalSettings(({ leftPanel }) => leftPanel.width / 2)}
              file={profilePicturePath}
            />
          </button>
        </box>
        <box
          class="profile-card"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={5}
          halign={Gtk.Align.CENTER}
          sensitive={profile((p) => !!p)}
        >
          <box class="profile-form" orientation={Gtk.Orientation.VERTICAL}>
            <entry
              class="profile-username"
              placeholderText={GLib.get_user_name()}
              hexpand
              xalign={0.5}
              tooltipMarkup={"Click to edit username"}
              text={profile((p) => p?.username ?? "")}
              $={(self: Gtk.Entry) => {
                self.connect("changed", () => {
                  setProfile((p) => {
                    if (!p) return p;
                    return { ...p, username: self.text };
                  });
                });
              }}
            />
          </box>
          <box class="profile-header" spacing={5} halign={Gtk.Align.CENTER}>
            <label label={emailLabel} xalign={0.5} />
            <label label="|" />
            <label
              class="profile-meta"
              label={profile(
                (p) => `Supporter: ${p?.is_supporter ? "Yes" : "No"}`,
              )}
              xalign={0.5}
            />
          </box>

          <box class="profile-actions" spacing={5}>
            <button
              class="update"
              label="Update Profile"
              hexpand
              onClicked={async () => {
                const session = await refreshAuthSession();
                if (!session?.access_token) {
                  notify({
                    summary: "Not signed in",
                    body: "Please sign in to update profile.",
                  });
                  return;
                }

                setProgressStatus("loading");
                setProgressText("Updating profile...");

                const result = await supabaseClient.updateCurrentUserProfile(
                  session.access_token,
                  { username: profile()!.username || "" },
                );

                if (result.ok) {
                  setProgressStatus("success");
                  setProgressText("Profile updated");
                  notify({
                    summary: "Profile updated",
                    body: "Your profile has been updated successfully.",
                  });
                  loadProfile(); // Refresh profile after update
                } else {
                  setProgressStatus("error");
                  setProgressText("Update failed");
                  notify({
                    summary: "Update failed",
                    body: result.error || "Failed to update profile.",
                  });
                }
              }}
            />
            <button
              class="update"
              label={""}
              tooltipMarkup={"Refresh profile"}
              sensitive={isRefreshing((refreshing) => !refreshing)}
              onClicked={async () => {
                if (isRefreshing()) return;
                setIsRefreshing(true);
                setProgressStatus("loading");
                setProgressText("Refreshing profile...");

                try {
                  await loadProfile();
                } finally {
                  setIsRefreshing(false);
                }
              }}
            />
          </box>
          <button
            class="update danger"
            label="Logout"
            onClicked={async () => {
              await execAsync(["rm", "-f", authSessionPath]);
              setProfile(null);
              clearUserProfile();
              setProgressStatus("idle");
              setProgressText("Signed out");
              notify({
                summary: "Signed out",
                body: "Your session has been cleared.",
              });
            }}
          />
        </box>
      </box>

      <box
        class="profile-info"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
        visible={!minimal}
        sensitive={profile((p) => !!p)}
      >
        <box
          class="section settings-sync"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={5}
        >
          <label class="settings-sync-header" label="Settings Sync" />
          <box
            class="settings-sync-info"
            spacing={5}
            orientation={Gtk.Orientation.VERTICAL}
          >
            <label class="settings-sync-meta" label={lastSyncLabel} />
            <label class="settings-sync-result" label={lastSyncResult} />
            <label
              class="settings-sync-remote"
              label={lastRemoteUpdatedLabel}
            />
          </box>
          <box class="settings-sync-actions" spacing={6}>
            <button
              class="sync"
              hexpand
              label={isSyncing() ? "Syncing settings..." : "Sync Settings"}
              onClicked={async () => {
                if (isSyncing()) return;
                setIsSyncing(true);
                setProgressStatus("loading");
                setProgressText("Syncing settings...");

                const result = await syncSettingsWithSupabase();

                setIsSyncing(false);

                if (!result.ok) {
                  setProgressStatus("error");
                  setProgressText("Settings sync failed");
                  notify({
                    summary: "Settings Sync",
                    body: result.error || "Failed to sync settings.",
                  });
                  return;
                }

                const directionText =
                  result.direction === "download"
                    ? "Downloaded from cloud"
                    : result.direction === "upload"
                      ? "Uploaded to cloud"
                      : "Already up to date";

                applySettingsSyncMeta();
                setProgressStatus("success");
                setProgressText(`Settings sync: ${directionText}`);
                notify({
                  summary: "Settings Sync",
                  body: directionText,
                });
              }}
            />
          </box>
        </box>
        <box
          class="section booru-favorites"
          orientation={Gtk.Orientation.VERTICAL}
        >
          <label class="booru-favorites-title" label="Booru Favorites" />
          <box class="booru-favorites-list" spacing={5}>
            {booruApis.map((api) => (
              <box class="booru-favorite-item" spacing={5} hexpand>
                <label class="booru-favorite-name" label={api.name} />
                <label
                  class="booru-favorite-badge"
                  label={booruFavoriteCounts((counts) =>
                    profile() ? `${counts[api.value] ?? 0}` : "",
                  )}
                />
              </box>
            ))}
          </box>
        </box>
        <box
          class="section pinned-images"
          orientation={Gtk.Orientation.VERTICAL}
        >
          <label class="pinned-images-title" label="Pinned Images" />
          <box class="pinned-images-row" spacing={6}>
            <label class="pinned-images-label" label="Fastfetch cache" />
            <label
              class="pinned-images-badge"
              label={pinnedCount((count) => (profile() ? `${count}` : ""))}
            />
          </box>
        </box>
        <Progress
          status={progressStatus}
          text={progressText}
          custom_class="profile-progress"
          showWhenIdle
        />
      </box>

      <With value={profile}>
        {(p) => {
          if (!p) return <MagicLinkEmail />;
          return null;
        }}
      </With>
    </box>
  );
};
