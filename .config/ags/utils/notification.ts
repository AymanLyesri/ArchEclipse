import { execAsync } from "ags/file";

export function notify({
  summary = "",
  body = "",
}: {
  summary: string;
  body: string;
}) {
  execAsync(`notify-send "${summary}" "${body}"`).catch((err) => print(err));
  print(`Notification Sent: ${summary} - ${body}`);
}
