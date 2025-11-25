import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();
import Mpris from "gi://AstalMpris";
const mpris = Mpris.get_default();
// import Cava from "gi://AstalCava";
// const cava = Cava.get_default()!;

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
import { createBinding, createComputed, createState, createPoll } from "ags";
import Gtk from "gi://Gtk?version=3.0";
import GLib from "gi://GLib?version=2.0";
import CustomRevealer from "../../CustomRevealer";
import { showWindow } from "../../../utils/window";
import { dateFormats } from "../../../constants/date.constants";

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
  // cava?.set_bars(12);
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
      setup={(self) => (revealerInstance = self)}
      child={
        <label
          className={"cava"}
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
      }
    />
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

  // cava?.connect("notify::values", () => {
  //   // store latest values, schedule an update if not already scheduled
  //   lastValuesCache = cava.get_values() || null;
  //   schedule();
  // });

  return revealer;
}

function Media({ monitorName }: { monitorName: string }) {
  const mprisPlayers = createBinding(mpris, "players");
  // Derive active player only when players array changes (cheaper than scanning on each render)
  const activePlayerVar = createComputed(() => {
    const players = mprisPlayers();
    if (!players || players.length === 0) return null;
    return (
      players.find((p) => p.playbackStatus === Mpris.PlaybackStatus.PLAYING) ||
      players[0]
    );
  });

  // Small helper that returns a compact player box. Keep widget tree minimal.
  function Player(player: Mpris.Player | null) {
    if (!player) return <box />;

    const playerEntry = createBinding(player, "entry");
    const playerCoverArt = createBinding(player, "coverArt");
    const playerPosition = createBinding(player, "position");
    const playerLength = createBinding(player, "length");
    const playerTitle = createBinding(player, "title");
    const playerArtist = createBinding(player, "artist");

    const playerIcon = createComputed(() => playerToIcon(playerEntry()));

    // Only build CSS when coverArt changes (bind will handle it)
    const coverCss = createComputed(() => {
      const c = playerCoverArt();
      return c
        ? `background-image: linear-gradient(to right,#000000, rgba(0,0,0,0.5)), url("${c}");`
        : `background-color: transparent;`;
    });

    const progressWidget = (
      <box
        className="progress"
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
        child={<label className={"icon"} label={playerIcon} />}
      />
    );

    const title = (
      <label
        className="title"
        maxWidthChars={20}
        truncate={true}
        label={createComputed(() => playerTitle() || "Unknown Track")}
      />
    );

    const artist = (
      <label
        className="artist"
        maxWidthChars={20}
        truncate={true}
        label={createComputed(() => {
          const a = playerArtist();
          return a ? `[${a}]` : "Unknown Artist";
        })}
      />
    );

    return (
      <box
        className={createComputed(() => `media ${playerEntry()}`)}
        css={coverCss}
        spacing={10}
      >
        {progressWidget}
        {title}
        {artist}
      </box>
    );
  }

  // Debounce showWindow to avoid spamming when cursor moves inside
  let hoverTimeout: number | null = null;
  const handleHover = () => {
    if (hoverTimeout) return;
    hoverTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 150, () => {
      showWindow(`media-${monitorName}`);
      hoverTimeout = null;
      return GLib.SOURCE_REMOVE;
    });
  };

  const activePlayerBox = createComputed(() => {
    const player = activePlayerVar();
    return player ? Player(player) : <box />;
  });

  return (
    <revealer
      revealChild={createComputed(() => {
        const arr = mprisPlayers();
        return !!(arr && arr.length);
      })}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      child={
        <eventbox
          className="media-event"
          onClick={() =>
            hyprland.message_async("dispatch workspace 4", () => {})
          }
          onHover={handleHover}
          child={activePlayerBox}
        />
      }
    />
  );
}

function Clock() {
  const revealer = <label className="revealer" label={date_more}></label>;

  const trigger = <label className="clock" label={date_less}></label>;

  return (
    <eventbox
      onClick={() => {
        const currentFormat = dateFormat();
        const currentIndex = dateFormats.indexOf(currentFormat);
        setDateFormat(dateFormats[(currentIndex + 1) % dateFormats.length]);
      }}
      child={
        <CustomRevealer
          trigger={trigger}
          child={revealer}
          custom_class="clock"
        />
      }
    />
  );
}
function Bandwidth() {
  const bandwidth = createPoll(
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
      transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
      setup={(self) => (uploadRevealerInstance = self)}
      child={
        <label
          label={createComputed(() => `[${formatKiloBytes(bandwidth()[2])}]`)}
        />
      }
    />
  );

  const downloadRevealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
      setup={(self) => (downloadRevealerInstance = self)}
      child={
        <label
          label={createComputed(() => `[${formatKiloBytes(bandwidth()[3])}]`)}
        />
      }
    />
  );

  const trigger = (
    <box className="bandwidth" spacing={3}>
      <label
        className="packet upload"
        label={createComputed(() => ` ${bandwidth()[0]}`)}
      />
      {uploadRevealer}
      <label className="separator" label={"-"} />
      <label
        className="packet download"
        label={createComputed(() => ` ${bandwidth()[1]}`)}
      />
      {downloadRevealer}
    </box>
  );

  const parent = (
    <eventbox
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
      child={trigger}
    />
  );

  return parent;
}

function ClientTitle() {
  return (
    <revealer
      revealChild={createComputed(() => !emptyWorkspace())}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
      child={createComputed(() => {
        const client = focusedClient();
        if (client) {
          const title = createBinding(client, "title");
          return (
            <label
              className="client-title"
              truncate={true}
              maxWidthChars={24}
              label={createComputed(() => (title() ? String(title()) : ""))}
            />
          );
        } else {
          return <box />;
        }
      })}
    />
  );
}
function Weather() {
  // Poll every 10 minutes (600,000 ms)
  const weather = createPoll(
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
          wind: parsed.current.wind_speed_10m,
        };
      } catch (e) {
        return null;
      }
    }
  );

  const label = (
    <label
      className="weather"
      truncate={true}
      // onDestroy={() => weather.drop()} // No drop in signals
      label={createComputed(() => {
        const w = weather();
        return w ? `  ${w.temp} -   ${w.wind} km/h` : "Weather N/A";
      })}
    />
  );

  return (
    <eventbox
      onClick={() =>
        GLib.spawn_command_line_async("xdg-open 'https://open-meteo.com/'")
      }
      child={label}
    />
  );
}

export default ({
  monitorName,
  halign,
}: {
  monitorName: string;
  halign: Gtk.Align;
}) => {
  return (
    <box className="bar-middle" spacing={5} halign={halign} hexpand>
      {/* <AudioVisualizer /> */}
      <Media monitorName={monitorName} />
      <Clock />
      <Weather />
      <Bandwidth />
      <ClientTitle />
    </box>
  );
};
