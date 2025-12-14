import Gtk from "gi://Gtk?version=4.0";
import { Accessor } from "ags";
import { globalTransition } from "../variables";
import { createState } from "ags";
import GLib from "gi://GLib?version=2.0";

const BLOCKS = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"];

const LoadingBarsLabel = ({
  barCount = 10,
  maxLevel = 5, // numeric "5"
  interval = 50,
  className = "loading-bars",
}: {
  barCount?: number;
  maxLevel?: number;
  interval?: number;
  className?: string;
}) => {
  const [getText, setText] = createState("");

  let pos = 0;
  let dir = 1; // 1 → right, -1 → left
  let timeoutId: number | null = null;

  const tick = () => {
    const bars = new Array(barCount);

    for (let i = 0; i < barCount; i++) {
      const dist = Math.abs(i - pos);
      const level = Math.max(0, maxLevel - dist);
      const idx = Math.min(level, BLOCKS.length - 1);
      bars[i] = BLOCKS[idx];
    }

    setText(bars.join(""));

    // ping-pong movement
    if (pos === barCount - 1) dir = -1;
    else if (pos === 0) dir = 1;
    pos += dir;

    return GLib.SOURCE_CONTINUE;
  };

  return (
    <label
      class={className}
      label={getText}
      $={() => {
        timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, interval, tick);
      }}
      onDestroy={() => {
        if (timeoutId) {
          try {
            GLib.source_remove(timeoutId);
          } catch {}
          timeoutId = null;
        }
      }}
    />
  );
};

export const Progress = ({
  text = "Loading...",
  revealed = false,
  custom_class = "",
  transitionType = Gtk.RevealerTransitionType.SLIDE_DOWN,
}: {
  text: string | Accessor<string>;
  revealed: boolean | Accessor<boolean>;
  custom_class?: string;
  transitionType?: Gtk.RevealerTransitionType;
}) => {
  return (
    <revealer
      class={`progress-widget ${custom_class}`}
      revealChild={revealed}
      transitionDuration={globalTransition}
      transitionType={transitionType}
    >
      <box class="progress" spacing={5}>
        <box class="progress-content">
          <label class="progress-text" label=">>" />
          <label class="progress-text" label={text} />
          <label class="progress-text" label="<<" />
        </box>
        <LoadingBarsLabel />
      </box>
    </revealer>
  );
};
