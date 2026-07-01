import { execAsync } from "ags/process";
import GLib from "gi://GLib";

export function notify({
  summary = "",
  body = "",
}: {
  summary: string;
  body: string;
}) {
  // Escape ampersands and other special markup characters
  const safeSummary = GLib.markup_escape_text(summary, -1);
  const safeBody = GLib.markup_escape_text(body, -1);

  execAsync(`notify-send "${safeSummary}" "${safeBody}"`).catch((err) => print(err));
  print(`Notification Sent: ${summary} - ${body}`);
}
