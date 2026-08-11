import { Accessor, createBinding, createComputed, For, With } from "ags";
import AstalApps from "gi://AstalApps";
import AstalMpris from "gi://AstalMpris";
import GLib from "gi://GLib";
import { connectPopoverEvents } from "../../../../utils/window";
import { timeout } from "ags/time";
import { Gtk } from "ags/gtk4";
import Cava from "../../../Cava";
import Picture from "../../../Picture";
import Pango from "gi://Pango";
import Player from "../../../Player";

const mpris = AstalMpris.get_default();

// Browsers leave zombie mpris players behind after a media tab closes -
// no title, nothing playing - which would render as "Unknown Track"
// entries. Only players with real metadata or active playback count.
export const isPlayablePlayer = (player: AstalMpris.Player) =>
  (player.title ?? "").trim() !== "" ||
  player.playbackStatus === AstalMpris.PlaybackStatus.PLAYING;

export const playablePlayers = createComputed(() => {
  const players = createBinding(mpris, "players")();
  return players.filter((player) => {
    createBinding(player, "title")();
    createBinding(player, "playbackStatus")();
    return isPlayablePlayer(player);
  });
});

export default ({
  widthRequest,
}: {
  widthRequest?: Accessor<number> | number;
}) => {
  const apps = new AstalApps.Apps();
  const DEFAULT_COVER = `${GLib.get_home_dir()}/.config/ags/assets/player/player_default.png`;

  return (
    <box class={"player-widget"} spacing={5} widthRequest={widthRequest}>
      <With value={playablePlayers}>
        {(playerList) =>
          playerList.length == 0 ? (
            <box halign={Gtk.Align.CENTER} hexpand spacing={5}>
              <label class="icon" label="󰎈" />
              <label label="No player running" />
            </box>
          ) : (
            <box spacing={5}>
              {playerList.map((player) => {
                const [app] = apps.exact_query(player.entry);

                // Cover guard (YouTube anti-flickering protection)
                let lastValidCover = player.coverArt || DEFAULT_COVER;
                const coverBinding = createBinding(
                  player,
                  "coverArt",
                )((c) => {
                  if (c && c.trim() !== "") {
                    lastValidCover = c;
                    return c;
                  }
                  return lastValidCover || DEFAULT_COVER;
                });

                return (
                  <menubutton
                    hexpand={widthRequest ? true : false}
                    $={(self) => connectPopoverEvents(self, "barWindow")}
                  >
                    <overlay
                      css={createComputed(() => {
                        const title_width = createBinding(
                          player,
                          "title",
                        )((title) => Math.min(title.length * 10 + 50, 200));
                        const is_playing = createBinding(
                          player,
                          "playbackStatus",
                        )(
                          (status) =>
                            status === AstalMpris.PlaybackStatus.PLAYING,
                        );
                        // return min-width
                        return `min-width: ${is_playing() ? title_width() + 25 : title_width()}px;`;
                      })}
                    >
                      <Picture class={"cover-art"} file={coverBinding} />
                      <box class={"content"} $type="overlay" spacing={3}>
                        <Cava
                          barCount={12}
                          transitionType={
                            Gtk.RevealerTransitionType.SLIDE_RIGHT
                          }
                          isPlaying={createBinding(
                            player,
                            "playbackStatus",
                          )(
                            (status) =>
                              status === AstalMpris.PlaybackStatus.PLAYING,
                          )}
                        />
                        <image
                          visible={!!app?.iconName}
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
                        <revealer
                          transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
                          $={(self) => {
                            player.connect("notify::playback-status", (s) => {
                              const revealSequence = () => {
                                self.reveal_child = true;
                                timeout(5000, () => {
                                  self.reveal_child = false;
                                });
                              };
                              revealSequence();
                            });
                          }}
                        >
                          <label
                            class="playback-status-icon icon"
                            label={createBinding(
                              player,
                              "playbackStatus",
                            )((s) =>
                              s === AstalMpris.PlaybackStatus.PLAYING
                                ? ""
                                : "",
                            )}
                          />
                        </revealer>
                        <label
                          label={createBinding(player, "title")}
                          ellipsize={Pango.EllipsizeMode.END}
                          maxWidthChars={25}
                        />
                      </box>
                    </overlay>
                    <popover
                      $={(self) => {
                        self.connect("notify::visible", () => {
                          if (self.visible) self.add_css_class("popover-open");
                          else if (self.get_child())
                            self.remove_css_class("popover-open");
                        });
                      }}
                    >
                      <Player height={200} width={300} player={player} />
                    </popover>
                  </menubutton>
                );
              })}
            </box>
          )
        }
      </With>
    </box>
  ) as Gtk.Widget;
};
