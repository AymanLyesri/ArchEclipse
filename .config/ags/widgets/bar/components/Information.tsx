import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();

import { playerToColor } from "../../../utils/color";
import { lookupIcon, playerToIcon } from "../../../utils/icon";
import {
  date_less,
  date_more,
  dateFormat,
  setDateFormat,
  focusedClient,
  globalTransition,
  pingedCrypto,
  setPingedCrypto,
} from "../../../variables";
import { Accessor, createBinding, For, With } from "ags";
import { createPoll } from "ags/time";
import Gtk from "gi://Gtk?version=4.0";
import GLib from "gi://GLib?version=2.0";
import CustomRevealer from "../../CustomRevealer";
import { dateFormats } from "../../../constants/date.constants";
import AstalMpris from "gi://AstalMpris";
import AstalApps from "gi://AstalApps";
import Pango from "gi://Pango";
import { Eventbox } from "../../Custom/Eventbox";
import Player from "../../Player";
import Crypto from "../../Crypto";
import Cava from "../../Cava";

const BANDWIDTH_POLL_MS = 2000; // bandwidth poll period (increase to reduce CPU)

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
        <box spacing={5}>
          <Cava
            barCount={12}
            transitionType={Gtk.RevealerTransitionType.SWING_LEFT}
          />
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
      "bash",
      "-c",
      `
  LOC=$(curl -fsSL https://ipinfo.io/loc) || exit 1
  LAT=\${LOC%,*}
  LON=\${LOC#*,}
  curl -fsSL "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,wind_speed_10m&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m"
  `,
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
      <Mpris />
      <Clock />
      <Weather />
      <Bandwidth />
      <ClientTitle />
      <With value={pingedCrypto}>
        {(crypto) =>
          crypto.symbol != "" ? (
            <Eventbox
              tooltipText={"click to remove"}
              onClick={() => setPingedCrypto({ symbol: "", timeframe: "" })}
            >
              <Crypto
                symbol={crypto.symbol}
                timeframe={crypto.timeframe}
                showPrice={true}
                showGraph={true}
                orientation={Gtk.Orientation.HORIZONTAL}
              />
            </Eventbox>
          ) : (
            <box />
          )
        }
      </With>
    </box>
  );
};
