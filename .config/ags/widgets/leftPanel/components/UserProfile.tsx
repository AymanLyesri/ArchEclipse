import { createState, With } from "gnim";
import { authSessionPath } from "../../../utils/auth-session";
import Picture from "../../Picture";
import { Gtk } from "ags/gtk4";
import { Supabase, User } from "../../../class/Supabase.class";
import { notify } from "../../../utils/notification";
import { refreshAuthSession } from "../../../utils/auth-session";
import { syncSettingsWithSupabase } from "../../../utils/settings-sync";
import { execAsync } from "ags/process";
import { timeout } from "ags/time";
import { globalSettings, profilePicturePath } from "../../../variables";
import { monitorFile } from "ags/file";
import { Progress } from "../../Progress";
import GLib from "gi://GLib";

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
      <box class="auth-cta" spacing={6} hexpand>
        {emailEntry}

        {sendButton}
      </box>
    </box>
  );

  return box;
};

export const UserProfile = () => {
  const supabaseClient = new Supabase();
  const [profile, setProfile] = createState<User | null>(null);
  const [progressStatus, setProgressStatus] = createState<
    "loading" | "error" | "success" | "idle"
  >("idle");
  const [progressText, setProgressText] = createState("Not signed in");
  const [isSyncing, setIsSyncing] = createState(false);

  const loadProfile = async () => {
    const session = await refreshAuthSession();

    if (!session?.access_token) {
      setProfile(null);
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

      setProfile(fetchedProfile);

      if (!fetchedProfile) {
        setProgressStatus("error");
        setProgressText("Signed in, but profile not found");
        return;
      }

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

  return (
    <box
      spacing={10}
      class="user-profile"
      orientation={Gtk.Orientation.VERTICAL}
      $={() => {
        loadProfile();

        monitorFile(`${GLib.get_home_dir()}/.config/ags/cache/auth`, () => {
          loadProfile();
        });
      }}
    >
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

              const contentType = avatarContentTypeByPath(cleanPath);

              if (!contentType) {
                notify({
                  summary: "Invalid image",
                  body: "Pick a PNG, JPG, or WebP file.",
                });
                return;
              }

              const session = await refreshAuthSession();

              if (!session?.access_token) {
                notify({
                  summary: "Not signed in",
                  body: "Please sign in to update your profile picture.",
                });
                return;
              }

              setProgressStatus("loading");
              setProgressText("Uploading avatar...");

              const result = await supabaseClient.uploadCurrentUserAvatar(
                session.access_token,
                cleanPath,
                contentType,
              );

              if (result.ok) {
                setProgressStatus("success");
                setProgressText("Avatar updated");
                notify({
                  summary: "Avatar updated",
                  body: "Your profile picture has been uploaded.",
                });
                notify({
                  summary: "Syncing avatar",
                  body: "Updating your profile picture. This may take a few seconds.",
                });
                timeout(5000, () => {
                  supabaseClient.syncAvatarToFaceIcon(result.avatarUrl!);
                });
              } else {
                setProgressStatus("error");
                setProgressText("Upload failed");
                notify({
                  summary: "Upload failed",
                  body: result.error || "Failed to upload profile picture.",
                });
              }
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
        spacing={8}
        halign={Gtk.Align.CENTER}
        sensitive={profile((p) => !!p)}
      >
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

        <box class="profile-form" orientation={Gtk.Orientation.VERTICAL}>
          <entry
            placeholderText="Username"
            hexpand
            xalign={0.5}
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

        <box class="profile-actions" spacing={5}>
          <button
            class="update"
            label="Update Profile"
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

              setProgressStatus("success");
              setProgressText(`Settings sync: ${directionText}`);
              notify({
                summary: "Settings Sync",
                body: directionText,
              });
            }}
          />
        </box>
        <button
          class="update danger"
          label="Logout"
          onClicked={async () => {
            await execAsync(["rm", "-f", authSessionPath]);
            setProfile(null);
            setProgressStatus("idle");
            setProgressText("Signed out");
            notify({
              summary: "Signed out",
              body: "Your session has been cleared.",
            });
          }}
        />
      </box>

      <With value={profile}>
        {(p) => {
          if (!p) return <MagicLinkEmail />;
          return null;
        }}
      </With>
      <Progress
        status={progressStatus}
        text={progressText}
        custom_class="profile-progress"
        showWhenIdle
      />
    </box>
  );
};
