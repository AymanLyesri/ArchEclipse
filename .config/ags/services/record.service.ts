import { execAsync } from "ags/process";
import GLib from "gi://GLib";
import { createState } from "gnim";
import { notify } from "../utils/notification";

export const [isRecording, setIsRecording] = createState(false);

const SCRIPT = `${GLib.get_home_dir()}/.config/hypr/scripts/screenrecord.sh`;

async function syncRecordingState() {
  const running = await execAsync(["pgrep", "-x", "wf-recorder"])
    .then(() => true)
    .catch(() => false);
  if (running !== isRecording.peek()) setIsRecording(running);
}

syncRecordingState();

// Poll the actual recorder state instead of maintaining it manually.
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, () => {
  syncRecordingState();
  return GLib.SOURCE_CONTINUE;
});

export async function toggleRecording(
  mode: "now" | "area" = "now",
): Promise<"started" | "stopped"> {
  if (isRecording.peek()) {
    try {
      await execAsync([SCRIPT, "stop"]);
      return "stopped";
    } catch {
      notify({
        summary: "ScreenRecord Error",
        body: "Failed to stop screen recording.",
      });
      return "started";
    }
  }

  execAsync([SCRIPT, "start", ...(mode === "area" ? ["--area"] : [])]).catch(
    () => {
      notify({
        summary: "ScreenRecord Error",
        body: "Failed to start screen recording.",
      });
    },
  );

  return "started";
}
