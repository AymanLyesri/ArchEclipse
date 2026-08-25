import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();

import {
  date_less,
  date_more,
  focusedClient,
  globalSettings,
  setGlobalSetting,
  specialWorkspace,
} from "../../../variables";
import { Accessor, createBinding, createComputed, For, With } from "ags";
import { Gdk, Gtk } from "ags/gtk4";
import CustomRevealer from "../../CustomRevealer";
import { dateFormats } from "../../../constants/date.constants";
import AstalMpris from "gi://AstalMpris";
import AstalApps from "gi://AstalApps";
import Pango from "gi://Pango";
import { Eventbox } from "../../Custom/Eventbox";
import Player from "../../Player";
import Crypto from "../../Crypto";
import Cava from "../../Cava";
import Bandwidth from "./sub-components/Bandwidth";
import GLib from "gi://GLib";
import { WeatherButton } from "../../Weather";
import { timeout } from "ags/time";
import GObject from "ags/gobject";
import Picture from "../../Picture";
import { connectPopoverEvents } from "../../../utils/window";
import PlayerWidget, {
  playablePlayers,
} from "./sub-components/PlayerWidget";
import KeyboardLayout from "./sub-components/KeyboardLayout";

const mpris = AstalMpris.get_default();

function Clock() {
  const revealer = <label class="revealer" label={date_more}></label>;

  const trigger = (
    <label class="clock" label={date_less}></label>
  ) as Gtk.Label;

  return (
    <Eventbox
      onClick={() => {
        const currentFormat = globalSettings.peek().dateFormat;
        const currentIndex = dateFormats.indexOf(currentFormat);
        setGlobalSetting(
          "dateFormat",
          dateFormats[(currentIndex + 1) % dateFormats.length],
        );

        // update the date immediately without waiting for the next tick
        trigger.set_label(
          GLib.DateTime.new_now_local().format(
            globalSettings.peek().dateFormat,
          )!,
        );
      }}
    >
      <CustomRevealer
        trigger={trigger}
        child={revealer}
        custom_class="clock"
        transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}
      />
    </Eventbox>
  );
}
export default ({ halign }: { halign?: Gtk.Align | Accessor<Gtk.Align> }) => {
  const t0 = GLib.get_monotonic_time();
  const mark = (label: string) =>
    print(
      `[InfoTiming] ${label}: ${(GLib.get_monotonic_time() - t0) / 1000} ms\n`,
    );
  const playerBox = (
    <box visible={playablePlayers((players) => players.length > 0)}>
      <With value={playablePlayers}>
        {(players: AstalMpris.Player[]) =>
          players.length > 0 && <PlayerWidget />
        }
      </With>
    </box>
  );
  mark("player");
  const weather = WeatherButton();
  mark("weather");
  const clock = <Clock />;
  mark("clock");
  const kbd = <KeyboardLayout />;
  mark("keyboard");
  const bw = <Bandwidth />;
  mark("bandwidth");
  return (
    <box class="information" spacing={5} halign={halign}>
      {playerBox}
      {weather}
      {clock}
      {kbd}
      {bw}
      <box>
        <With value={globalSettings(({ crypto }) => crypto.favorite)}>
          {(crypto: { symbol: string; timeframe: string }) =>
            crypto.symbol != "" && (
              <Eventbox
                tooltipText={"click to remove"}
                onClick={() =>
                  setGlobalSetting("crypto.favorite", {
                    symbol: "",
                    timeframe: "",
                  })
                }
              >
                <Crypto
                  symbol={crypto.symbol}
                  timeframe={crypto.timeframe}
                  showPrice={true}
                  showGraph={true}
                  orientation={Gtk.Orientation.HORIZONTAL}
                />
              </Eventbox>
            )
          }
        </With>
      </box>
    </box>
  );
};
