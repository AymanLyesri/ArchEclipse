import AstalMpris from "gi://AstalMpris?version=0.1";
import { getDominantColor, getImageRatio } from "../utils/image";
import Gtk from "gi://Gtk?version=4.0";
import {
  createBinding,
  createState,
  createComputed,
  Accessor,
  With,
} from "ags";
import Picture from "./Picture";
import Gio from "gi://Gio";
// import Cava from "./Cava";
import GLib from "gi://GLib?version=2.0";
import Pango from "gi://Pango?version=1.0";
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

  // Calculate bar count based on parent width
  const barCount = parentWidth((width) => {
    // Calculate bar count based on width
    // You might want to adjust this formula based on your needs
    // Example: 1 bar per 10 pixels, but ensure minimum of 8 bars
    const calculated = Math.floor(width / 10);
    return Math.max(8, Math.min(calculated, 50)); // Clamp between 8 and 50 bars
  });

  function lengthStr(length: number) {
    const min = Math.floor(length / 60);
    const sec = Math.floor(length % 60);
    const sec0 = sec < 10 ? "0" : "";
    return `${min}:${sec0}${sec}`;
  }

  const playerStack = new Gtk.Stack({
    transition_duration: 250,
    hexpand: true,
    vexpand: true,
  });

  function showPlayer(widget: Gtk.Widget, direction: "next" | "prev") {
    playerStack.set_transition_type(
      direction === "next"
        ? Gtk.StackTransitionType.SLIDE_LEFT
        : Gtk.StackTransitionType.SLIDE_RIGHT,
    );

    const name = `player-${Date.now()}`;
    playerStack.add_named(widget, name);
    playerStack.set_visible_child_name(name);
  }

  const bottomBar = () => {
    const title = (
      <label
        class="title"
        ellipsize={Pango.EllipsizeMode.END}
        halign={Gtk.Align.START}
        label={createBinding(player, "title")((t) => t || "Unknown Track")}
      ></label>
    );

    const artist = (
      <label
        class="artist"
        maxWidthChars={20}
        halign={Gtk.Align.START}
        ellipsize={Pango.EllipsizeMode.END}
        label={createBinding(player, "artist")((a) => a || "Unknown Artist")}
      ></label>
    );

    const positionSlider = (
      <slider
        class="slider"
        // css={dominantColor((c) => `highlight{background: ${c}00};`)}
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
            file={createBinding(player, "coverArt")}
          />
          <box class="info" orientation={Gtk.Orientation.VERTICAL}>
            {title}
            {artist}
          </box>
          <Icon />
        </box>

        <box class={"separator"} vexpand></box>

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

  const overlay = (
    <overlay
      class={`player ${className || ""}`}
      hexpand
      $={(self) => {
        // Create a controller to monitor size changes
        const controller = new Gtk.EventControllerMotion();

        controller.connect("enter", () => {
          // Get the allocation when mouse enters
          const alloc = self.get_allocation();
          if (alloc) {
            setParentWidth(alloc.width);
          }
        });

        // Also check on allocation changes using a custom approach
        const checkWidth = () => {
          const alloc = self.get_allocation();
          if (alloc && alloc.width > 0 && alloc.width !== parentWidth.get()) {
            setParentWidth(alloc.width);
          }
          return true; // Continue timeout
        };

        // Start checking width periodically
        const timeoutId = GLib.timeout_add(
          GLib.PRIORITY_DEFAULT,
          100, // Check every 100ms
          checkWidth,
        );

        // Clean up on destroy
        self.connect("destroy", () => {
          if (timeoutId) {
            GLib.source_remove(timeoutId);
          }
        });

        self.add_controller(controller);

        // Initial width check
        checkWidth();

        playerStack.add_named(bottomBar() as Gtk.Widget, "bottom-bar");
        playerStack.set_visible_child_name("bottom-bar");

        createBinding(player, "title").subscribe(() => {
          showPlayer(bottomBar() as Gtk.Widget, slideDirection.get() || "next");
        });
      }}
    >
      <Picture
        class="img"
        height={height}
        width={width}
        file={createBinding(player, "coverArt")}
      />

      <box
        $type="overlay"
        orientation={Gtk.Orientation.VERTICAL}
        valign={Gtk.Align.END}
      >
        {/* <box halign={Gtk.Align.CENTER}>
          <With value={barCount}>
            {(count) => (
              <Cava
                barCount={count} // Use computed bar count
                transitionType={Gtk.RevealerTransitionType.SWING_UP}
              />
            )}
          </With>
        </box> */}
        {playerStack}
      </box>
    </overlay>
  );

  return overlay;
};
