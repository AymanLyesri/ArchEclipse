import { createState } from "ags";
import { Gtk } from "ags/gtk4";
import { interval } from "ags/time";
import { isRecording } from "../../../../services/record.service";

function formatElapsed(ms: number) {
  const totalSeconds = Math.floor(ms / 1000);
  const mins = Math.floor(totalSeconds / 60)
    .toString()
    .padStart(2, "0");
  const secs = (totalSeconds % 60).toString().padStart(2, "0");
  return `${mins}:${secs}`;
}

export default ({ widthRequest }: { widthRequest: any }) => {
  const [elapsed, setElapsed] = createState("00:00");
  let timer: ReturnType<typeof interval> | null = null;

  isRecording.subscribe(() => {
    timer?.cancel();
    timer = null;

    if (isRecording.peek()) {
      const start = Date.now(); // captured fresh, right here, every time it starts
      setElapsed("00:00");
      timer = interval(1000, () => {
        setElapsed(formatElapsed(Date.now() - start));
      });
    } else {
      setElapsed("00:00");
    }
  });

  return (
    <box
      class="recording"
      spacing={6}
      halign={Gtk.Align.CENTER}
      widthRequest={widthRequest}
    >
      <label label="•" class="recording-dot" />
      <label label="Recording" class="recording-label" />
      <label label={elapsed} class="recording-time" />
    </box>
  ) as Gtk.Widget;
};
