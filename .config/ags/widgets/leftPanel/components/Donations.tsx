// =============================================================================
// DONATIONS WIDGET
// =============================================================================
// This widget displays donation options for crypto and PayPal
//
// CUSTOMIZATION:
// 1. Replace PayPal URL with your actual PayPal.me link (line 22)
// 2. Replace crypto addresses with your actual wallet addresses (lines 27-47)
// 3. Add or remove donation options by modifying the donationOptions array
// 4. Customize colors by changing the 'color' property for each option
//
// DEPENDENCIES:
// - qrencode: Required for QR code generation (install: yay -S qrencode)
// - wl-clipboard: Required for clipboard operations (install: yay -S wl-clipboard)
// - xdg-utils: Required for opening URLs (usually pre-installed)
// - Image viewer (feh/eog/gwenview): For displaying QR codes
// =============================================================================

import Gtk from "gi://Gtk?version=4.0";
import { createState, For } from "ags";
import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import GLib from "gi://GLib?version=2.0";

import Hyprland from "gi://AstalHyprland";
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
        // Display QR code in a notification or viewer
        // execAsync(`bash -c "swayimg '${qrPath}' 2>/dev/null ||
        //                   eog '${qrPath}' 2>/dev/null ||
        //                   gwenview '${qrPath}' 2>/dev/null ||
        //                   xdg-open '${qrPath}'"`);
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

              {/* Address display for crypto (read-only) */}
              {option.type === "crypto" && option.address && (
                <entry
                  class="donation-address"
                  text={option.address}
                  editable={false}
                  canFocus={false}
                  hexpand
                />
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
