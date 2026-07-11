import { execAsync } from "ags/process";
import GLib from "gi://GLib";
import { createState } from "gnim";
import { notify } from "../utils/notification";

export const [isRecording, setIsRecording] = createState(false);

const SCRIPT = `${GLib.get_home_dir()}/.config/hypr/scripts/screenrecord.sh`;

// resync on module load — covers AGS restarts/reloads while wf-recorder is still running
async function syncRecordingState() {
  const running = await execAsync(["pgrep", "-x", "wf-recorder"])
    .then(() => true)
    .catch(() => false);
  setIsRecording(running);
}
syncRecordingState();

export async function toggleRecording(
  mode: "now" | "area" = "now",
): Promise<"started" | "stopped"> {
  if (isRecording.peek()) {
    setIsRecording(false);
    try {
      await execAsync([SCRIPT, "stop"]);
    } catch {
      notify({
        summary: "ScreenRecord Error",
        body: "Failed to stop screen recording. Please check the script.",
      });
      setIsRecording(true);
    }
    return "stopped";
  } else {
    setIsRecording(true);
    try {
      await execAsync([
        SCRIPT,
        "start",
        ...(mode === "area" ? ["--area"] : []),
      ]);
      return "started";
    } catch {
      notify({
        summary: "ScreenRecord Error",
        body: "Failed to start screen recording. Please check the script.",
      });
      setIsRecording(false);
      return "stopped";
    }
  }
}
