import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();
import Cava from "gi://AstalCava";
const cava = Cava.get_default()!;

import { playerToColor } from "../../../utils/color";
import { lookupIcon, playerToIcon } from "../../../utils/icon";
import {
  date_less,
  date_more,
  dateFormat,
  setDateFormat,
  emptyWorkspace,
  focusedClient,
  globalTransition,
} from "../../../variables";
import { Accessor, createBinding, createComputed, createState, For } from "ags";
import { createPoll } from "ags/time";
import Gtk from "gi://Gtk?version=4.0";
import GLib from "gi://GLib?version=2.0";
import CustomRevealer from "../../CustomRevealer";
import { showWindow } from "../../../utils/window";
import { dateFormats } from "../../../constants/date.constants";
import AstalMpris from "gi://AstalMpris";
import AstalApps from "gi://AstalApps";
import Pango from "gi://Pango";
import { Eventbox } from "../../Custom/Eventbox";
import Player from "../../Player";
import Crypto from "../../Crypto";

// --- Tunable constants (change to lower CPU usage) ---
const CAVA_UPDATE_MS = 60; // coalesced update interval for audio visualizer (larger => less CPU)
const BANDWIDTH_POLL_MS = 2000; // bandwidth poll period (increase to reduce CPU)

// Small lightweight throttle/coalesce helper
function scheduleCoalesced(fn: () => void, delayMs: number) {
  let timeoutId: number | null = null;
  let pending = false;
  return (triggerFn?: () => void) => {
    if (triggerFn) triggerFn();
    if (pending) return; // already scheduled
    pending = true;
    timeoutId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delayMs, () => {
      pending = false;
      timeoutId = null;
      try {
        fn();
      } catch (e) {
        // swallow errors to avoid crashing the scheduler
        console.error(e);
      }
      return GLib.SOURCE_REMOVE;
    });
  };
}

function AudioVisualizer() {
  cava?.set_bars(12);
  const [getBars, setBars] = createState("");

  const BLOCKS = [
    "\u2581",
    "\u2582",
    "\u2583",
    "\u2584",
    "\u2585",
    "\u2586",
    "\u2587",
    "\u2588",
  ];
  const BLOCKS_LENGTH = BLOCKS.length;
  const BAR_COUNT = 12;
  const EMPTY_BARS = "".padEnd(BAR_COUNT, "\u2581");
  // Reuse buffer to avoid allocations on every update
  let barArray: string[] = new Array(BAR_COUNT);
  let lastBarString = "";

  // visibility hysteresis: ignore short silence gaps
  const REVEAL_SHOW_DELAY = 300; // ms before showing on non-empty
  const REVEAL_HIDE_DELAY = 700; // ms before hiding on empty
  let visible = false;
  let showTimeoutId: number | null = null;
  let hideTimeoutId: number | null = null;

  let revealerInstance: Gtk.Revealer | null = null;

  const revealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      $={(self) => (revealerInstance = self)}
    >
      <label
        class={"cava"}
        onDestroy={() => {
          // bars.drop(); // No drop in signals
          if (showTimeoutId) {
            try {
              GLib.source_remove(showTimeoutId);
            } catch (e) {}
            showTimeoutId = null;
          }
          if (hideTimeoutId) {
            try {
              GLib.source_remove(hideTimeoutId);
            } catch (e) {}
            hideTimeoutId = null;
          }
        }}
        label={getBars}
      />
    </revealer>
  );

  // Create coalesced updater so frequent "notify::values" calls are batched
  const doUpdate = () => {
    const values = lastValuesCache;
    // build barArray for current values; if no values treat as empty
    if (!values || values.length === 0) {
      // fill with empty blocks
      for (let j = 0; j < BAR_COUNT; j++) barArray[j] = BLOCKS[0];
    } else {
      if (barArray.length !== values.length)
        barArray = new Array(values.length);
      for (let i = 0; i < values.length && i < BAR_COUNT; i++) {
        const val = values[i];
        const idx = Math.min(
          Math.floor(val * BLOCKS_LENGTH),
          BLOCKS_LENGTH - 1
        );
        barArray[i] = BLOCKS[idx];
      }
      for (let j = values.length; j < BAR_COUNT; j++) barArray[j] = BLOCKS[0];
    }

    const b = barArray.join("");

    // if nothing changed, skip heavy work
    if (b === lastBarString) return;
    lastBarString = b;

    // update bound text (cheap) but control reveal/hide with timers (hysteresis)
    setBars(b);

    const isEmpty = b === EMPTY_BARS;

    if (!isEmpty) {
      // audio present -> ensure we will show, cancel any hide timer
      if (hideTimeoutId) {
        try {
          GLib.source_remove(hideTimeoutId);
        } catch (e) {}
        hideTimeoutId = null;
      }

      if (!visible && !showTimeoutId) {
        // schedule show after short delay (ignore brief silence gaps)
        showTimeoutId = GLib.timeout_add(
          GLib.PRIORITY_DEFAULT,
          REVEAL_SHOW_DELAY,
          () => {
            visible = true;
            if (revealerInstance) revealerInstance.reveal_child = true;
            showTimeoutId = null;
            return GLib.SOURCE_REMOVE;
          }
        );
      } else if (visible) {
        // already visible -- ensure revealer stays revealed
        if (revealerInstance) revealerInstance.reveal_child = true;
      }
    } else {
      // empty -> cancel any pending show and schedule hide if currently visible
      if (showTimeoutId) {
        try {
          GLib.source_remove(showTimeoutId);
        } catch (e) {}
        showTimeoutId = null;
      }

      if (visible && !hideTimeoutId) {
        // schedule hide after a longer delay (ignore short silence gaps)
        hideTimeoutId = GLib.timeout_add(
          GLib.PRIORITY_DEFAULT,
          REVEAL_HIDE_DELAY,
          () => {
            visible = false;
            if (revealerInstance) revealerInstance.reveal_child = false;
            hideTimeoutId = null;
            return GLib.SOURCE_REMOVE;
          }
        );
      } else if (!visible) {
        // already hidden
        if (revealerInstance) revealerInstance.reveal_child = false;
      }
    }
  };

  let lastValuesCache: number[] | null = null;
  const schedule = scheduleCoalesced(doUpdate, CAVA_UPDATE_MS);

  cava?.connect("notify::values", () => {
    // store latest values, schedule an update if not already scheduled
    lastValuesCache = cava.get_values() || null;
    schedule();
  });

  return revealer;
}

function Mpris() {
  const mpris = AstalMpris.get_default();
  const apps = new AstalApps.Apps();
  const players = createBinding(mpris, "players");

  return (
    <revealer
      revealChild={players((players) => players.length > 0)}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
    >
      <menubutton>
        <box>
          <For each={players}>
            {(player) => {
              const [app] = apps.exact_query(player.entry);
              return (
                <box spacing={5}>
                  <image visible={!!app.iconName} iconName={app?.iconName} />
                  <label label={createBinding(player, "title")} />
                </box>
              );
            }}
          </For>
        </box>
        <popover>
          <box spacing={4} orientation={Gtk.Orientation.VERTICAL}>
            <For each={players}>
              {(player) => <Player playerType="popup" player={player} />}
            </For>
          </box>
        </popover>
      </menubutton>
    </revealer>
  );
}

function Clock() {
  const revealer = <label class="revealer" label={date_more}></label>;

  const trigger = <label class="clock" label={date_less}></label>;

  return (
    <Eventbox
      onClick={() => {
        const currentFormat = dateFormat.get();
        const currentIndex = dateFormats.indexOf(currentFormat);
        setDateFormat(dateFormats[(currentIndex + 1) % dateFormats.length]);
      }}
    >
      <CustomRevealer trigger={trigger} child={revealer} custom_class="clock" />
    </Eventbox>
  );
}
function Bandwidth() {
  const bandwidth = createPoll(
    [],
    BANDWIDTH_POLL_MS,
    ["./assets/binaries/bandwidth"],
    (out) => {
      try {
        const parsed = JSON.parse(out);
        return [parsed[0], parsed[1], parsed[2], parsed[3]];
      } catch (e) {
        return [0, 0, 0, 0];
      }
    }
  );

  function formatKiloBytes(kb: number): string {
    if (kb === undefined || kb === null || isNaN(kb)) {
      return "0.0 KB";
    }
    const units = ["KB", "MB", "GB", "TB"];
    let idx = 0;
    let val = kb;
    while (val >= 1024 && idx < units.length - 1) {
      val /= 1024;
      idx++;
    }
    return `${val.toFixed(1)} ${units[idx]}`;
  }

  let uploadRevealerInstance: Gtk.Revealer | null = null;
  let downloadRevealerInstance: Gtk.Revealer | null = null;

  const uploadRevealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SWING_RIGHT}
      $={(self) => (uploadRevealerInstance = self)}
    >
      <label label={bandwidth((b) => `[${formatKiloBytes(b[2])}]`)} />
    </revealer>
  );

  const downloadRevealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SWING_RIGHT}
      $={(self) => (downloadRevealerInstance = self)}
    >
      <label label={bandwidth((b) => `[${formatKiloBytes(b[3])}]`)} />
    </revealer>
  );

  const trigger = (
    <box class="bandwidth" spacing={3}>
      <label class="packet upload" label={bandwidth((b) => ` ${b[0]}`)} />
      {uploadRevealer}
      <label class="separator" label={"-"} />
      <label class="packet download" label={bandwidth((b) => ` ${b[1]}`)} />
      {downloadRevealer}
    </box>
  );

  const parent = (
    <Eventbox
      onHover={() => {
        if (uploadRevealerInstance) uploadRevealerInstance.reveal_child = true;
        if (downloadRevealerInstance)
          downloadRevealerInstance.reveal_child = true;
      }}
      onHoverLost={() => {
        if (uploadRevealerInstance) uploadRevealerInstance.reveal_child = false;
        if (downloadRevealerInstance)
          downloadRevealerInstance.reveal_child = false;
      }}
    >
      {trigger}
    </Eventbox>
  );

  return parent;
}

function ClientTitle() {
  return (
    <revealer
      revealChild={focusedClient((c) => !!c)}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SWING_RIGHT}
    >
      <label
        class="client-title"
        ellipsize={Pango.EllipsizeMode.END}
        maxWidthChars={24}
        label={focusedClient((c) => {
          if (!c) return "No focused client";
          return c.title || "No Title";
        })}
      />
    </revealer>
  );
}
function Weather() {
  // Poll every 10 minutes (600,000 ms)
  const weather = createPoll(
    null,
    600000,
    [
      "curl",
      "-s",
      "https://api.open-meteo.com/v1/forecast?latitude=52.52&longitude=13.41&current=temperature_2m,wind_speed_10m&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m",
    ],
    (out) => {
      try {
        const parsed = JSON.parse(out);
        return {
          temp: parsed.current.temperature_2m,
          temp_unit: parsed.current_units.temperature_2m,
          wind: parsed.current.wind_speed_10m,
          wind_unit: parsed.current_units.wind_speed_10m,
        };
      } catch (e) {
        return null;
      }
    }
  );

  const label = (
    <label
      class="weather"
      ellipsize={Pango.EllipsizeMode.END}
      // onDestroy={() => weather.drop()} // No drop in signals
      label={weather((w) =>
        w
          ? `  ${w.temp} ${w.temp_unit} - ${w.wind} ${w.wind_unit}`
          : "Weather N/A"
      )}
    />
  );
  return (
    <Eventbox
      onClick={() =>
        GLib.spawn_command_line_async("xdg-open 'https://open-meteo.com/'")
      }
    >
      {label}
    </Eventbox>
  );
}

export default ({
  monitorName,
  halign,
}: {
  monitorName: string;
  halign: Accessor<Gtk.Align>;
}) => {
  return (
    <box class="bar-middle" spacing={5} halign={halign}>
      <AudioVisualizer />
      <Mpris />
      <Clock />
      <Weather />
      <Bandwidth />
      <ClientTitle />
      {/* <Crypto /> */}
    </box>
  );
};
