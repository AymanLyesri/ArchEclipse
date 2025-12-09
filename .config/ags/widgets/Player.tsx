import AstalMpris from "gi://AstalMpris?version=0.1";
import { getDominantColor, getImageRatio } from "../utils/image";
import Gtk from "gi://Gtk?version=4.0";
import { rightPanelWidth } from "../variables";
import { createBinding, createState, createComputed, Accessor } from "ags";
import Picture from "./Picture";
import Gio from "gi://Gio";

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
  const [isDragging, setIsDragging] = createState(false);
  const dominantColor = createBinding(
    player,
    "coverArt"
  )((path) => getDominantColor(path));
  const img = (
    height: number | Accessor<number>,
    width: number | Accessor<number>
  ) => {};
  const title = (
    <label
      class="title"
      maxWidthChars={20}
      halign={Gtk.Align.START}
      label={createBinding(player, "title")((t) => t || "Unknown Track")}
    ></label>
  );

  const artist = (
    <label
      class="artist"
      maxWidthChars={20}
      halign={Gtk.Align.START}
      label={createBinding(player, "artist")((a) => a || "Unknown Artist")}
    ></label>
  );

  const positionSlider = (
    <slider
      class="slider"
      css={dominantColor((c) => `highlight{background: ${c}00}`)}
      $={(self) => {
        let unsubscribe: (() => void) | null = null;

        const updateValue = () => {
          if (!isDragging.get()) {
            const pos = player.position;
            const len = player.length;
            self.set_value(len > 0 ? pos / len : 0);
          }
        };

        const gestureClick = new Gtk.GestureDrag();

        gestureClick.connect("drag-begin", () => {
          setIsDragging(true);
          if (unsubscribe) {
            unsubscribe();
            unsubscribe = null;
          }
        });

        gestureClick.connect("drag-update", () => {
          player.position = self.get_value() * player.length;
        });

        gestureClick.connect("drag-end", () => {
          player.position = self.get_value() * player.length;
          setIsDragging(false);
          unsubscribe = createBinding(player, "position").subscribe(
            updateValue
          );
        });

        self.add_controller(gestureClick);
        unsubscribe = createBinding(player, "position").subscribe(updateValue);
      }}
      visible={createBinding(player, "length")((l) => l > 0)}
    />
  );

  const positionLabel = (
    <label
      class="position time"
      halign={Gtk.Align.START}
      label={createBinding(player, "position")(lengthStr)}
      visible={createBinding(player, "length")((l) => l > 0)}
    ></label>
  );
  const lengthLabel = (
    <label
      class="length time"
      halign={Gtk.Align.END}
      visible={createBinding(player, "length")((l) => l > 0)}
      label={createBinding(player, "length")(lengthStr)}
    ></label>
  );

  const icon = (
    <box halign={Gtk.Align.END} valign={Gtk.Align.CENTER}>
      <image
        class="icon"
        tooltip_text={createBinding(player, "identity")((i) => i || "")}
        file={createBinding(
          player,
          "entry"
        )((entry) => {
          const name = `${entry}-symbolic`;
          // return Gtk.Utils.lookUpicon(name)
          //   ? `icon:///${name}`
          //   : "icon:///audio-x-generic-symbolic";
          return `icon:///audio-x-generic-symbolic`;
        })}
      />
    </box>
  );

  const playPause = (
    <button
      onClicked={() => player.play_pause()}
      class="play-pause"
      visible={createBinding(player, "can_play")((c) => c)}
    >
      <label
        label={createBinding(
          player,
          "playbackStatus"
        )((s) => {
          switch (s) {
            case AstalMpris.PlaybackStatus.PLAYING:
              return "⏸";
            case AstalMpris.PlaybackStatus.PAUSED:
            case AstalMpris.PlaybackStatus.STOPPED:
              return "▶";
            default:
              return "▶";
          }
        })}
      />
    </button>
  );

  const prev = (
    <button
      onClicked={() => player.previous()}
      visible={createBinding(player, "can_go_previous")((c) => c)}
    >
      <label label="⏮" />
    </button>
  );

  const next = (
    <button
      onClicked={() => player.next()}
      visible={createBinding(player, "can_go_next")((c) => c)}
    >
      <label label="⏭" />
    </button>
  );

  const content = (
    <box
      class="bottom-bar"
      spacing={5}
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      valign={Gtk.Align.END}
    >
      <box class="info" orientation={Gtk.Orientation.VERTICAL}>
        {title}
        {artist}
      </box>

      <centerbox>
        <box $type="start">{positionLabel}</box>
        <box $type="center" spacing={5}>
          {prev}
          {playPause}
          {next}
        </box>
        <box $type="end">{lengthLabel}</box>
      </centerbox>
      {positionSlider}
    </box>
  );

  return (
    <overlay
      class={`player ${playerType}`}
      hexpand
      //     css={createBinding(
      //       player,
      //       "coverArt"
      //     )((p) => {
      //       if (playerType == "popup") return "";

      //       const ratio = getImageRatio(p || "") || 1; // default to square
      //       const width = rightPanelWidth.get();
      //       const height = width * ratio;

      //       return `
      //   min-height: ${height}px;
      //   background-image: url('${p}');
      //   background-size: cover;
      //   background-position: center;
      // `;
      //     })}
      // spacing={5}
    >
      <Picture
        class="img"
        height={createBinding(
          player,
          "coverArt"
        )((path) => {
          const ratio = getImageRatio(path) || 1;
          const width = rightPanelWidth.get();
          return width * ratio;
        })}
        file={createBinding(player, "coverArt")}
      />
      {playerType == "widget" ? (
        <box
          $type="overlay"
          orientation={Gtk.Orientation.VERTICAL}
          hexpand
          valign={Gtk.Align.END}
        >
          {/* <box>{icon}</box> */}
          {content}
        </box>
      ) : (
        <box>
          {
            <Picture
              class="img"
              width={100}
              height={100}
              file={createBinding(player, "coverArt")}
            />
          }
          {content}
        </box>
      )}
    </overlay>
  );
};
