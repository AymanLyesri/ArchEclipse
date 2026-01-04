import Hyprland from "gi://AstalHyprland";
const hyprland = Hyprland.get_default();

import { playerToColor } from "../../../utils/color";
import { lookupIcon, playerToIcon } from "../../../utils/icon";
import {
  date_less,
  date_more,
  focusedClient,
  globalSettings,
  globalTransition,
  setGlobalSetting,
} from "../../../variables";
import { Accessor, createBinding, For, With } from "ags";
import { createPoll } from "ags/time";
import Gtk from "gi://Gtk?version=4.0";
import CustomRevealer from "../../CustomRevealer";
import { dateFormats } from "../../../constants/date.constants";
import AstalMpris from "gi://AstalMpris";
import AstalApps from "gi://AstalApps";
import Pango from "gi://Pango";
import { Eventbox } from "../../Custom/Eventbox";
import Player from "../../Player";
import Crypto from "../../Crypto";
import Cava from "../../Cava";
import Weather from "./sub-components/Weather";
import Bandwidth from "./sub-components/Bandwidth";

const mpris = AstalMpris.get_default();

function Mpris() {
  const apps = new AstalApps.Apps();
  const players = createBinding(mpris, "players");

  return (
    <menubutton class={"mpris"}>
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
                <image
                  visible={!!app.iconName}
                  iconName={app?.iconName}
                  class={createBinding(
                    player,
                    "playbackStatus"
                  )((s) =>
                    s === AstalMpris.PlaybackStatus.PLAYING
                      ? "mpris-icon playing"
                      : "mpris-icon paused"
                  )}
                />
                <label
                  label={createBinding(player, "title")}
                  ellipsize={Pango.EllipsizeMode.END}
                />
              </box>
            );
          }}
        </For>
      </box>
      <popover>
        <box spacing={4} orientation={Gtk.Orientation.VERTICAL}>
          <For each={players}>
            {(player) => <Player height={200} width={300} player={player} />}
          </For>
        </box>
      </popover>
    </menubutton>
  );
}

function Clock() {
  const revealer = <label class="revealer" label={date_more}></label>;

  const trigger = <label class="clock" label={date_less}></label>;

  return (
    <Eventbox
      onClick={() => {
        const currentFormat = globalSettings.peek().dateFormat;
        const currentIndex = dateFormats.indexOf(currentFormat);
        setGlobalSetting(
          "dateFormat",
          dateFormats[(currentIndex + 1) % dateFormats.length]
        ); // Cycle through formats
      }}
    >
      <CustomRevealer trigger={trigger} child={revealer} custom_class="clock" />
    </Eventbox>
  );
}

function ClientTitle({
  focusedClient,
}: {
  focusedClient: Accessor<Hyprland.Client>;
}) {
  return (
    <label
      class="client-title"
      ellipsize={Pango.EllipsizeMode.END}
      maxWidthChars={50}
      label={focusedClient((c) => {
        if (!c) return "No focused client";
        return c.title || "No Title";
      })}
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
    <box class="bar-middle" spacing={5} halign={halign}>
      <box
        visible={createBinding(
          mpris,
          "players"
        )((players) => players.length > 0)}
      >
        <With value={createBinding(mpris, "players")}>
          {(players: AstalMpris.Player[]) => players.length > 0 && <Mpris />}
        </With>
      </box>

      <Weather />
      <Bandwidth />
      <Clock />
      <ClientTitle focusedClient={focusedClient} />

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
  );
};
