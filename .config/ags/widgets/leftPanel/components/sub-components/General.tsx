import { Gtk } from "ags/gtk4";
import { createState, For, With, onCleanup } from "ags";
import { execAsync, exec } from "ags/process";
import { notify } from "../../../../utils/notification";
import GLib from "gi://GLib";

import Hyprland from "gi://AstalHyprland";
import Picture from "../../../Picture";
import { globalSettings } from "../../../../variables";
import { UserProfile } from "../UserProfile";
const hyprland = Hyprland.get_default();

// General information section (version, github link, etc.)
const GeneralInfo = () => {
  const [currentVersion, setCurrentVersion] = createState("");
  const [remoteVersion, setRemoteVersion] = createState("");
  const [isCheckingVersion, setIsCheckingVersion] = createState(true);
  const [isUpdating, setIsUpdating] = createState(false);
  const [updateStatus, setUpdateStatus] = createState("");

  const configDir = GLib.getenv("HOME") + "/.config/ags";

  const checkVersions = async () => {
    setIsCheckingVersion(true);
    try {
      // Get current local commit
      const localHash = exec(
        `git -C ${configDir} rev-parse --short HEAD`,
      ).trim();
      setCurrentVersion(localHash);

      // Fetch and get remote commit
      await execAsync(`git -C ${configDir} fetch origin master`);
      const remoteHash = await execAsync(
        `git -C ${configDir} rev-parse --short origin/master`,
      );
      setRemoteVersion(remoteHash.trim());
      setUpdateStatus("");
    } catch (e) {
      console.error("Failed to check versions:", e);
      setCurrentVersion("Unknown");
      setRemoteVersion("Unknown");
    } finally {
      setIsCheckingVersion(false);
    }
  };

  const updateVersion = async () => {
    try {
      hyprland.dispatch(
        "hl.dsp.exec_cmd('kitty zsh -ic \"clear; archeclipse\"')",
        "",
      );
    } catch (e) {
      console.error("Failed to launch update command:", e);
      const errorMessage = (e instanceof Error ? e.message : String(e))
        .replace(/['"\\`\n\r]/g, " ")
        .replace(/\s+/g, " ")
        .trim();
      notify({
        summary: "Launch Error",
        body: errorMessage || "Could not open kitty with archeclipse.",
      });
    }
  };

  const isOutdated = () => {
    return (
      currentVersion() &&
      remoteVersion() &&
      currentVersion() !== remoteVersion() &&
      currentVersion() !== "Unknown"
    );
  };

  const links = [
    {
      description: "GitHub Repository",
      url: "https://github.com/AymanLyesri/ArchEclipse",
      icon: "",
    },
    {
      description: "Issues Tracker",
      url: "https://github.com/AymanLyesri/ArchEclipse/issues",
      icon: "",
    },
    {
      description: "Discord Community",
      url: "https://discord.gg/fMGt4vH6s5",
      icon: "",
    },
  ];

  return (
    <box class={"info"} orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      <box halign={Gtk.Align.CENTER}>
        <Picture
          file={`${GLib.get_home_dir()}/.config/ags/assets/userpanel/archeclipse_default_pfp.jpg`}
          width={globalSettings(({ leftPanel }) => leftPanel.width / 2)}
          height={globalSettings(({ leftPanel }) => leftPanel.width / 2)}
        />
      </box>
      <box spacing={10} halign={Gtk.Align.CENTER}>
        <label class={"config-title"} label="ArchEclipse" />
        {/* github stars */}
        <label
          class={"config-stars"}
          $={(self) => {
            execAsync(
              `bash -c "curl -s https://api.github.com/repos/AymanLyesri/ArchEclipse | jq '.stargazers_count'"`,
            ).then((result) => {
              const stars = result.trim();
              self.label = `  ${stars}`;
            });
          }}
        />
      </box>
      <box spacing={10} halign={Gtk.Align.CENTER}>
        {links.map((link) => (
          <button
            class={"link-button"}
            onClicked={() => execAsync(`xdg-open "${link.url}"`)}
            tooltipText={link.description}
          >
            <label label={link.icon} />
          </button>
        ))}
      </box>
      <box
        class={"section version-section"}
        orientation={Gtk.Orientation.VERTICAL}
        $={() => {
          checkVersions();
        }}
      >
        <With value={isCheckingVersion}>
          {(isChecking) =>
            isChecking ? (
              <label
                class={"version-status loading"}
                label="🔄 Checking for updates..."
              />
            ) : (
              <box
                class={"version-container"}
                orientation={Gtk.Orientation.VERTICAL}
                spacing={8}
              >
                {/* Version Info Row */}
                {remoteVersion() && (
                  <box spacing={10} halign={Gtk.Align.CENTER}>
                    <box
                      orientation={Gtk.Orientation.VERTICAL}
                      spacing={5}
                      hexpand
                    >
                      <label class={"version-label"} label="Current Version" />
                      <label
                        class={"version-value"}
                        label={currentVersion() || "Unknown"}
                      />
                    </box>

                    <box
                      orientation={Gtk.Orientation.VERTICAL}
                      spacing={5}
                      hexpand
                    >
                      <label class={"version-label"} label="Latest Version" />
                      <label class={"version-value"} label={remoteVersion()} />
                    </box>
                  </box>
                )}

                {/* Status Row */}
                <box spacing={8}>
                  {isOutdated() ? (
                    <box spacing={10} halign={Gtk.Align.CENTER}>
                      <label
                        class={"version-status outdated"}
                        label="⚠️ Update available"
                        hexpand
                      />
                      <button
                        class={`update-button ${isUpdating() ? "updating" : ""}`}
                        sensitive={!isUpdating()}
                        onClicked={updateVersion}
                        tooltipText="Click to update to the latest version"
                      >
                        <box spacing={5}>
                          {isUpdating() && (
                            <label label="⟳" class={"spinner"} />
                          )}
                          {!isUpdating() && <label label="⬇" />}
                          <label
                            label={isUpdating() ? "Updating..." : "Update"}
                          />
                        </box>
                      </button>
                    </box>
                  ) : (
                    <box spacing={10} halign={Gtk.Align.CENTER} hexpand>
                      <label
                        class={"version-status uptodate"}
                        label={`✓ Up to date${updateStatus() ? ` - ${updateStatus()}` : ""}`}
                        hexpand
                      />
                      {/* Manual update check button */}
                      {!isUpdating() && (
                        <button
                          class="update-button secondary"
                          onClicked={checkVersions}
                          tooltipText="Manually check for updates"
                        >
                          <box spacing={5}>
                            <label label="" />
                            <label label="Check Update" />
                          </box>
                        </button>
                      )}
                    </box>
                  )}
                </box>
              </box>
            )
          }
        </With>
      </box>
    </box>
  );
};

export default () => {
  return (
    <box
      class="general"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      spacing={15}
    >
      {GeneralInfo()}
    </box>
  );
};
