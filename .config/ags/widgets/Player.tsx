import AstalMpris from "gi://AstalMpris";
import { getDominantColor } from "../utils/image";
import { Gtk } from "ags/gtk4";
import { createBinding, createState, Accessor } from "ags";
import Picture from "./Picture";
// import Cava from "./Cava";
import GLib from "gi://GLib";
import Pango from "gi://Pango";
import AstalApps from "gi://AstalApps";

export default ({
  player,
  width,
  height,
  className,
}: {
  player: AstalMpris.Player;
  width?: Accessor<number> | number;
  height?: Accessor<number> | number;
  className?: string;
}) => {
  const apps = new AstalApps.Apps();

  const [isDragging, setIsDragging] = createState(false);
  const [parentWidth, setParentWidth] = createState(0);
  const [slideDirection, setSlideDirection] = createState<"next" | "prev">(
    "next",
  );

  const dominantColor = createBinding(
    player,
    "coverArt",
  )((path) => getDominantColor(path));

  const isPlaying = createBinding(
    player,
    "playbackStatus",
  )((status) => status === AstalMpris.PlaybackStatus.PLAYING);

  function lengthStr(length: number) {
    const min = Math.floor(length / 60);
    const sec = Math.floor(length % 60);
    const sec0 = sec < 10 ? "0" : "";
    return `${min}:${sec0}${sec}`;
  }

  // =========================
  // Bottom bar (unchanged logic)
  // =========================
  const bottomBar = () => {
    const title = (
      <label
        class="title"
        ellipsize={Pango.EllipsizeMode.END}
        halign={Gtk.Align.START}
        label={createBinding(player, "title")((t) => t || "Unknown Track")}
      />
    );

    const artist = (
      <label
        class="artist"
        maxWidthChars={20}
        halign={Gtk.Align.START}
        ellipsize={Pango.EllipsizeMode.END}
        label={createBinding(player, "artist")((a) => a || "Unknown Artist")}
      />
    );

    const positionSlider = (
      <slider
        class="slider"
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
            unsubscribe?.();
            unsubscribe = null;
          });

          gestureClick.connect("drag-update", () => {
            player.position = self.get_value() * player.length;
          });

          gestureClick.connect("drag-end", () => {
            player.position = self.get_value() * player.length;
            setIsDragging(false);
            unsubscribe = createBinding(player, "position").subscribe(
              updateValue,
            );
          });

          self.add_controller(gestureClick);
          unsubscribe = createBinding(player, "position").subscribe(
            updateValue,
          );
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
      />
    );

    const lengthLabel = (
      <label
        class="length time"
        halign={Gtk.Align.END}
        visible={createBinding(player, "length")((l) => l > 0)}
        label={createBinding(player, "length")(lengthStr)}
      />
    );

    const Icon = () => (
      <box hexpand halign={Gtk.Align.END} valign={Gtk.Align.START}>
        <image
          class="icon"
          tooltip_text={createBinding(player, "identity")((i) => i || "")}
          iconName={
            apps.exact_query(player.entry)[0]?.iconName || "audio-x-generic"
          }
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
            "playbackStatus",
          )((s) => {
            switch (s) {
              case AstalMpris.PlaybackStatus.PLAYING:
                return "";
              case AstalMpris.PlaybackStatus.PAUSED:
              case AstalMpris.PlaybackStatus.STOPPED:
                return "";
              default:
                return "";
            }
          })}
        />
      </button>
    );

    const prev = (
      <button
        onClicked={() => {
          player.previous();
          setSlideDirection("prev");
        }}
        visible={createBinding(player, "can_go_previous")((c) => c)}
      >
        <label label="󰒮" />
      </button>
    );

    const next = (
      <button
        onClicked={() => {
          player.next();
          setSlideDirection("next");
        }}
        visible={createBinding(player, "can_go_next")((c) => c)}
      >
        <label label="󰒭" />
      </button>
    );

    return (
      <box
        class="bottom-bar"
        spacing={5}
        orientation={Gtk.Orientation.VERTICAL}
        hexpand
      >
        <box class="top-row" spacing={10}>
          <Picture
            class={createBinding(
              player,
              "playbackStatus",
            )((s) =>
              s === AstalMpris.PlaybackStatus.PLAYING
                ? "cover-art-spinner playing"
                : "cover-art-spinner paused",
            )}
            height={40}
            width={40}
            file={createBinding(
              player,
              "coverArt",
            )(
              (c) =>
                c ||
                `${GLib.get_home_dir()}/.config/ags/assets/player/player_default.png`,
            )}
          />
          <box class="info" orientation={Gtk.Orientation.VERTICAL}>
            {title}
            {artist}
          </box>
          <Icon />
        </box>

        <box class="separator" vexpand />

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
  };

  // =========================
  // Stack animation (FIXED)
  // =========================
  const playerStack = new Gtk.Stack({
    transition_duration: 250,
    hexpand: true,
    vexpand: true,
  });

  const bar1 = bottomBar() as Gtk.Widget;
  const bar2 = bottomBar() as Gtk.Widget;

  let currentIndex = 0;
  const names = ["bar1", "bar2"];

  playerStack.add_named(bar1, names[0]);
  playerStack.add_named(bar2, names[1]);
  playerStack.set_visible_child_name(names[0]);

  function switchBar(direction: "next" | "prev") {
    playerStack.set_transition_type(
      direction === "next"
        ? Gtk.StackTransitionType.SLIDE_LEFT
        : Gtk.StackTransitionType.SLIDE_RIGHT,
    );

    currentIndex = currentIndex === 0 ? 1 : 0;
    playerStack.set_visible_child_name(names[currentIndex]);
  }

  // =========================
  // Main overlay
  // =========================
  const overlay = (
    <overlay
      class={`player ${className || ""}`}
      hexpand
      $={(self) => {
        const controller = new Gtk.EventControllerMotion();

        controller.connect("enter", () => {
          const alloc = self.get_allocation();
          if (alloc) setParentWidth(alloc.width);
        });

        const checkWidth = () => {
          const alloc = self.get_allocation();
          if (alloc && alloc.width > 0 && alloc.width !== parentWidth.get()) {
            setParentWidth(alloc.width);
          }
          return true;
        };

        const timeoutId = GLib.timeout_add(
          GLib.PRIORITY_DEFAULT,
          100,
          checkWidth,
        );

        self.connect("destroy", () => {
          if (timeoutId) GLib.source_remove(timeoutId);
        });

        self.add_controller(controller);
        checkWidth();

        // ✅ SAFE: only switching, not recreating widgets
        createBinding(player, "title").subscribe(() => {
          switchBar(slideDirection.get() || "next");
        });
      }}
    >
      <Picture
        class="img"
        height={height}
        width={width}
        file={createBinding(
          player,
          "coverArt",
        )(
          (c) =>
            c ||
            `${GLib.get_home_dir()}/.config/ags/assets/player/player_default.png`,
        )}
      />

      <box
        $type="overlay"
        orientation={Gtk.Orientation.VERTICAL}
        valign={Gtk.Align.END}
      >
        {playerStack}
      </box>
    </overlay>
  );

  return overlay;
};
