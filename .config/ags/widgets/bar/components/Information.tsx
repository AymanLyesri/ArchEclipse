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
import CustomRevealer from "../../CustomRevealer";
import { dateFormats } from "../../../constants/date.constants";
import AstalMpris from "gi://AstalMpris";
import AstalApps from "gi://AstalApps";
import Pango from "gi://Pango";
import { Eventbox } from "../../Custom/Eventbox";
import Player from "../../Player";
import Crypto from "../../Crypto";
import Cava from "../../Cava";
import Weather from "../../Weather";
import Bandwidth from "../../Bandwidth";

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
                <image visible={!!app.iconName} iconName={app?.iconName} />
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
        const currentFormat = dateFormat.get();
        const currentIndex = dateFormats.indexOf(currentFormat);
        setDateFormat(dateFormats[(currentIndex + 1) % dateFormats.length]); // Cycle through formats
      }}
    >
      <CustomRevealer trigger={trigger} child={revealer} custom_class="clock" />
    </Eventbox>
  );
}

function ClientTitle() {
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
      <With value={createBinding(mpris, "players")}>
        {(players: AstalMpris.Player[]) => players.length > 0 && <Mpris />}
      </With>

      <Weather />
      <Bandwidth />
      <Clock />

      <With value={focusedClient}>{(client) => client && <ClientTitle />}</With>

      <With value={pingedCrypto}>
        {(crypto) =>
          crypto.symbol != "" && (
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
          )
        }
      </With>
    </box>
  );
};
