import Gtk from "gi://Gtk?version=4.0";
import { createState, For, With } from "ags";
import { execAsync, exec } from "ags/process";
import { notify } from "../../../utils/notification";
import GLib from "gi://GLib?version=2.0";

import Hyprland from "gi://AstalHyprland";
import Picture from "../../Picture";
import { globalSettings } from "../../../variables";
const hyprland = Hyprland.get_default();

interface DonationOption {
  name: string;
  description?: string;
  icon: string;
  type: "crypto" | "paypal";
  address?: string;
  url?: string;
  color: string;
}

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
      await execAsync(`git -C ${configDir} fetch origin`);
      const remoteHash = await execAsync(
        `git -C ${configDir} rev-parse --short origin/HEAD`,
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
    setIsUpdating(true);
    setUpdateStatus("Updating...");
    try {
      // Pull latest changes
      await execAsync(`git -C ${configDir} pull origin HEAD`);

      // Refresh version info after update
      const localHash = exec(
        `git -C ${configDir} rev-parse --short HEAD`,
      ).trim();
      setCurrentVersion(localHash);

      setUpdateStatus("Updated!");
      notify({
        summary: "Update Complete",
        body: "ArchEclipse has been updated successfully!",
      });

      // Clear status after 2 seconds
      await new Promise((resolve) => setTimeout(resolve, 2000));
      setUpdateStatus("");
    } catch (e) {
      console.error("Failed to update:", e);
      setUpdateStatus("Update Failed");
      notify({
        summary: "Update Error",
        body: "Failed to update ArchEclipse. Make sure git is installed.",
      });

      // Clear status after 3 seconds
      await new Promise((resolve) => setTimeout(resolve, 3000));
      setUpdateStatus("");
    } finally {
      setIsUpdating(false);
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
      <box spacing={10} halign={Gtk.Align.CENTER}>
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
                    <label
                      class={"version-status uptodate"}
                      label={`✓ Up to date${updateStatus() ? ` - ${updateStatus()}` : ""}`}
                      hexpand
                    />
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
  const [donationOptions] = createState<DonationOption[]>([
    {
      name: "PayPal",
      icon: "",
      type: "paypal",
      url: "https://paypal.me/LyesriAyman", // Replace with actual PayPal link
      color: "#00457C",
    },
    {
      name: "Bitcoin",
      icon: "",
      type: "crypto",
      address: "1JisW9xeatCFadtgsenjbpCcFePZGPyXow", // Replace with actual BTC address
      color: "#F7931A",
    },
    {
      name: "Ethereum",
      icon: "",
      type: "crypto",
      address: "0x52d06d47bb9dc75eaf027f18cb197d5817989a96", // Replace with actual ETH address
      color: "#627EEA",
    },
    {
      name: "BSC",
      description: "BNB Smart Chain (BEP20)",
      icon: "",
      type: "crypto",
      address: "0x52d06d47bb9dc75eaf027f18cb197d5817989a96", // Replace with actual BSC address
      color: "#F3BA2F",
    },
  ]);

  // Copy address to clipboard and show notification
  const copyToClipboard = (text: string, name: string) => {
    execAsync(`bash -c "echo -n '${text}' | wl-copy"`)
      .then(() => {
        notify({
          summary: "Copied to Clipboard",
          body: `${name} address copied successfully!`,
        });
      })
      .catch(() => {
        notify({
          summary: "Error",
          body: "Failed to copy to clipboard",
        });
      });
  };

  // Open URL in default browser
  const openUrl = (url: string) => {
    execAsync(`xdg-open "${url}"`)
      .then(() => {
        notify({
          summary: "Opening PayPal",
          body: "Opening donation page in browser...",
        });
      })
      .catch(() => {
        notify({
          summary: "Error",
          body: "Failed to open URL",
        });
      });
  };

  // Generate QR code for crypto address
  const showQRCode = (address: string, name: string) => {
    const qrPath = `/tmp/donation_qr_${name.toLowerCase()}.png`;

    // Generate QR code using qrencode
    execAsync(`qrencode -o "${qrPath}" "${address}"`)
      .then(() => {
        hyprland.dispatch(
          `exec`,
          `bash -c "swayimg '${qrPath}' 2>/dev/null || eog '${qrPath}' 2>/dev/null || gwenview '${qrPath}' 2>/dev/null || xdg-open '${qrPath}'"`,
        );

        notify({
          summary: "QR Code Generated",
          body: `Scan the QR code to donate ${name}`,
        });
      })
      .catch(() => {
        notify({
          summary: "Error",
          body: "QR code generation failed. Install 'qrencode' package.",
        });
      });
  };

  return (
    <scrolledwindow hexpand vexpand>
      <box
        class="donations-widget"
        orientation={Gtk.Orientation.VERTICAL}
        hexpand
        spacing={15}
      >
        {/* Version Info */}
        {GeneralInfo()}

        {/* Header */}
        <box
          orientation={Gtk.Orientation.VERTICAL}
          spacing={10}
          class="donation-header"
        >
          <label
            class="donation-title"
            label="Support the Project"
            halign={Gtk.Align.CENTER}
            wrap
          />
          <label
            class="donation-subtitle"
            label="Your donations help keep this project alive and maintained"
            halign={Gtk.Align.CENTER}
            wrap
            wrapMode={Gtk.WrapMode.WORD_CHAR}
          />
        </box>

        {/* Donation Options */}
        <For each={donationOptions}>
          {(option) => (
            <box
              class="donation-option"
              orientation={Gtk.Orientation.VERTICAL}
              spacing={8}
            >
              {/* Option Header */}
              <box spacing={10} halign={Gtk.Align.START}>
                <label
                  class="donation-icon"
                  label={option.icon}
                  halign={Gtk.Align.START}
                />
                <label
                  class="donation-name"
                  label={option.name}
                  halign={Gtk.Align.START}
                  hexpand
                />
                <label
                  class="donation-description"
                  label={option.description}
                  halign={Gtk.Align.START}
                  hexpand
                />
              </box>

              {/* Action Buttons */}
              {option.type === "crypto" && option.address && (
                <box spacing={5}>
                  <button
                    class="donation-button primary"
                    hexpand
                    onClicked={() =>
                      copyToClipboard(option.address!, option.name)
                    }
                    tooltipText={option.address}
                  >
                    <box spacing={5}>
                      <label label="" />
                      <label label="Copy Address" />
                    </box>
                  </button>
                  <button
                    class="donation-button secondary"
                    onClicked={() => showQRCode(option.address!, option.name)}
                    tooltipText="Show QR Code"
                  >
                    <label label="" />
                  </button>
                </box>
              )}

              {option.type === "paypal" && option.url && (
                <button
                  class="donation-button paypal"
                  hexpand
                  onClicked={() => openUrl(option.url!)}
                  tooltipText={option.url}
                >
                  <box spacing={5}>
                    <label label="" />
                    <label label="Donate via PayPal" />
                  </box>
                </button>
              )}
            </box>
          )}
        </For>

        {/* Footer Message */}
        <box class="donation-footer" orientation={Gtk.Orientation.VERTICAL}>
          <label
            class="donation-thankyou"
            label="Thank you for your support! 💖"
            halign={Gtk.Align.CENTER}
            wrap
          />
        </box>
      </box>
    </scrolledwindow>
  );
};
