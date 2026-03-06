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
import { Gtk } from "ags/gtk4";
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
import { notify } from "../../../utils/notification";
import GLib from "gi://GLib";

const mpris = AstalMpris.get_default();

function Mpris() {
  const apps = new AstalApps.Apps();
  const players = createBinding(mpris, "players");

  return (
    <menubutton class={"mpris"}>
      <box spacing={5}>
        {/* <Cava
          barCount={12}
          transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
        /> */}
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
                    "playbackStatus",
                  )((s) =>
                    s === AstalMpris.PlaybackStatus.PLAYING
                      ? "mpris-icon playing"
                      : "mpris-icon paused",
                  )}
                />
                <label
                  label={createBinding(player, "title")}
                  ellipsize={Pango.EllipsizeMode.END}
                  maxWidthChars={25}
                />
              </box>
            );
          }}
        </For>
      </box>
      <popover
        $={(self) => {
          self.connect("notify::visible", () => {
            if (self.visible) self.add_css_class("popover-open");
            else if (self.get_child()) self.remove_css_class("popover-open");
          });
        }}
      >
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

function ClientTitle({
  focusedClient,
}: {
  focusedClient: Accessor<Hyprland.Client>;
}) {
  return (
    <box visible={focusedClient((c) => !!c)}>
      <With value={focusedClient}>
        {(client) =>
          client && (
            <label
              class="client-title"
              ellipsize={Pango.EllipsizeMode.END}
              maxWidthChars={20}
              label={focusedClient((client) => {
                return client ? createBinding(client, "title") : "No Title";
              })()}
              tooltipMarkup={focusedClient((c) => c.class)}
            />
          )
        }
      </With>
    </box>
  );
}

export default ({ halign }: { halign?: Gtk.Align | Accessor<Gtk.Align> }) => {
  return (
    <box class="information" spacing={5} halign={halign}>
      <box
        visible={createBinding(
          mpris,
          "players",
        )((players) => players.length > 0)}
      >
        <With value={createBinding(mpris, "players")}>
          {(players: AstalMpris.Player[]) => players.length > 0 && <Mpris />}
        </With>
      </box>

      <Weather />
      <Clock />
      <Bandwidth />
      <ClientTitle focusedClient={focusedClient} />
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
