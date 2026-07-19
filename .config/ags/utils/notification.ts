import { execAsync } from "ags/process";
import GLib from "gi://GLib";

export function notify({
  summary = "",
  body = "",
}: {
  summary: string;
  body: string;
}) {
  execAsync(["notify-send", summary, body])
      .catch((err) => print("Failed to send notification:", err));
  print(`Notification Sent: ${summary} - ${body}`);
}
