import AstalMpris from "gi://AstalMpris?version=0.1";
import { getDominantColor, getImageRatio } from "../utils/image";
import Gtk from "gi://Gtk?version=4.0";
import { rightPanelWidth } from "../variables";
import { createBinding, createComputed } from "ags";

const FALLBACK_ICON = "audio-x-generic-symbolic";
const PLAY_ICON = "media-playback-start-symbolic";
const PAUSE_ICON = "media-playback-pause-symbolic";
const PREV_ICON = "media-skip-backward-symbolic";
const NEXT_ICON = "media-skip-forward-symbolic";

function lengthStr(length: number) {
  const min = Math.floor(length / 60);
  const sec = Math.floor(length % 60);
  const sec0 = sec < 10 ? "0" : "";
  return `${min}:${sec0}${sec}`;
}

export default ({
  player,
  playerType,
}: {
  player: AstalMpris.Player;
  playerType: "popup" | "widget";
}) => {
  const coverArt = createBinding(player, "coverArt");
  const titleBinding = createBinding(player, "title");
  const artistBinding = createBinding(player, "artist");
  const lengthBinding = createBinding(player, "length");
  const positionBinding = createBinding(player, "position");
  const canPlayBinding = createBinding(player, "canPlay");
  const playbackStatusBinding = createBinding(player, "playbackStatus");
  const canGoPreviousBinding = createBinding(player, "canGoPrevious");
  const canGoNextBinding = createBinding(player, "canGoNext");

  const dominantColor = createComputed(() => getDominantColor(coverArt()));

  const img = () => {
    if (playerType == "widget") return <box></box>;

    return (
      <box
        valign={Gtk.Align.CENTER}
        child={
          <box
            class="img"
            css={createComputed(
              () => `
                    background-image: url('${coverArt()}');
                `
            )}
          />
        }
      ></box>
    );
  };
  const title = (
    <label
      class="title"
      maxWidthChars={20}
      halign={Gtk.Align.START}
      ellipsize={Pango.EllipsizeMode.END}
      label={createComputed(() => titleBinding() || "Unknown Track")}
    ></label>
  );

  const artist = (
    <label
      class="artist"
      maxWidthChars={20}
      halign={Gtk.Align.START}
      ellipsize={Pango.EllipsizeMode.END}
      label={createComputed(() => artistBinding() || "Unknown Artist")}
    ></label>
  );

  const positionSlider = (
    <slider
      class="slider"
      css={createComputed(() => `highlight{background: ${dominantColor()}00}`)}
      onValueChanged={(self) =>
        (player.position = self.get_value() * player.length)
      }
      visible={createComputed(() => lengthBinding() > 0)}
      value={createComputed(() =>
        lengthBinding() > 0 ? positionBinding() / lengthBinding() : 0
      )}
    />
  );

  const positionLabel = (
    <label
      class="position time"
      halign={Gtk.Align.START}
      label={createComputed(() => lengthStr(positionBinding()))}
      visible={createComputed(() => lengthBinding() > 0)}
    ></label>
  );
  const lengthLabel = (
    <label
      class="length time"
      halign={Gtk.Align.END}
      visible={createComputed(() => lengthBinding() > 0)}
      label={createComputed(() => lengthStr(lengthBinding()))}
    ></label>
  );

  const playPause = (
    <button
      onClicked={() => player.play_pause()}
      class="play-pause"
      visible={createComputed(() => canPlayBinding())}
      child={
        <image
          gicon={createComputed(() => {
            const s = playbackStatusBinding();
            switch (s) {
              case AstalMpris.PlaybackStatus.PLAYING:
                return PAUSE_ICON;
              case AstalMpris.PlaybackStatus.PAUSED:
              case AstalMpris.PlaybackStatus.STOPPED:
                return PLAY_ICON;
              default:
                return PLAY_ICON;
            }
          })}
        ></image>
      }
    ></button>
  );

  const prev = (
    <button
      onClicked={() => player.previous()}
      visible={createComputed(() => canGoPreviousBinding())}
      child={<image gicon={PREV_ICON}></image>}
    ></button>
  );

  const next = (
    <button
      onClicked={() => player.next()}
      visible={createComputed(() => canGoNextBinding())}
      child={<image gicon={NEXT_ICON}></image>}
    ></button>
  );

  return (
    <box
      class={`player ${playerType}`}
      vexpand={false}
      css={createComputed(() => {
        if (playerType == "popup") return "";

        const p = coverArt();
        const ratio = getImageRatio(p) || 1; // default to square
        const width = rightPanelWidth();
        const height = width * ratio;

        return `
    min-height: ${height}px;
    background-image: url('${p}');
    background-size: cover;
    background-position: center;
  `;
      })}
    >
      {img()}
      <box orientation={Gtk.Orientation.VERTICAL} hexpand={true}>
        {/* <box>{icon}</box> */}
        <box vexpand={true}></box>
        <Eventbox
          class={"bottom-Eventbox"}
          child={
            <box
              class={"bottom-bar"}
              spacing={5}
              orientation={Gtk.Orientation.VERTICAL}
            >
              <box class={"info"} orientation={Gtk.Orientation.VERTICAL}>
                {title}
                {artist}
              </box>

              <centerbox
                spacing={5}
                startWidget={positionLabel}
                centerWidget={
                  <box spacing={5}>
                    {prev}
                    {playPause}
                    {next}
                  </box>
                }
                endWidget={lengthLabel}
              />
              {positionSlider}
            </box>
          }
        />
      </box>
    </box>
  );
};
