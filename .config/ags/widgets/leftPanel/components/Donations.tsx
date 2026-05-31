import { Gtk } from "ags/gtk4";
import { createState } from "ags";
import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";

import Hyprland from "gi://AstalHyprland";
import { UserProfile } from "./UserProfile";
import General from "./sub-components/General";
const hyprland = Hyprland.get_default();

interface DonationOption {
  name: string;
  description?: string;
  icon: string;
  type: "crypto" | "third-party";
  class?: string;
  address?: string;
  url?: string;
  color: string;
}

export default () => {
  const [donationOptions] = createState<DonationOption[]>([
    {
      name: "Ko-fi",
      icon: "",
      class: "kofi",
      type: "third-party",
      url: "https://ko-fi.com/aymanlyesri", // Replace with actual Ko-fi link
      color: "#29ABE0",
    },
    {
      name: "PayPal",
      icon: "",
      type: "third-party",
      class: "paypal",
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
  const openUrl = (option: DonationOption) => {
    execAsync(`xdg-open "${option.url}"`)
      .then(() => {
        notify({
          summary: `Opening ${option.name}`,
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
  const showQRCode = ({
    url,
    address,
    name,
  }: {
    address?: string;
    url?: string;
    name: string;
  }) => {
    const qrPath = `/tmp/donation_qr_${name.toLowerCase()}.png`;

    // Generate QR code using qrencode
    execAsync(`qrencode -o "${qrPath}" "${address || url}"`)
      .then(() => {
        hyprland.dispatch(
          `hl.dsp.exec_cmd('bash -c "swayimg \\'${qrPath}\\' 2>/dev/null || eog \\'${qrPath}\\' 2>/dev/null || gwenview \\'${qrPath}\\' 2>/dev/null || xdg-open \\'${qrPath}\\'"')`,
          "",
        );

        notify({
          summary: "QR Code Generated",
          body: `Scan the QR code to get ${name} ${address ? "address" : "link"}!`,
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
        {General()}

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
            label="Your donations help keep this project alive"
            halign={Gtk.Align.CENTER}
          />
        </box>

        {/* Render donation options two-by-two */}
        {(() => {
          const arr = donationOptions();
          const pairs: DonationOption[][] = [];
          for (let i = 0; i < arr.length; i += 2) {
            pairs.push(arr.slice(i, i + 2));
          }

          return pairs.map((pair) => (
            <box class="donation-row" spacing={10} hexpand>
              {pair.map((option) => (
                <box class="donation-option" hexpand spacing={5}>
                  <button
                    class={`donation-button ${option.class || "third-party"}`}
                    onClicked={() => {
                      if (option.type === "crypto" && option.address) {
                        copyToClipboard(option.address, option.name);
                      } else if (option.url) {
                        openUrl(option);
                      }
                    }}
                    tooltipMarkup={
                      option.type === "crypto"
                        ? `<b>Copy ${option.name} address</b>\n${option.address}`
                        : `<b>Donate via ${option.name}</b>\n${option.url}`
                    }
                    hexpand
                  >
                    <box spacing={5}>
                      <label
                        class="donation-icon"
                        label={option.icon}
                        halign={Gtk.Align.START}
                      />
                      <label label={option.name} />
                    </box>
                  </button>
                  <button
                    class="donation-button secondary"
                    onClicked={() =>
                      showQRCode({
                        url: option.url,
                        name: option.name,
                      })
                    }
                    tooltipText="Show QR Code"
                  >
                    <label label="" />
                  </button>
                </box>
              ))}
            </box>
          ));
        })()}

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
