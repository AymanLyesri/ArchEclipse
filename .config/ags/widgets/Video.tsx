import { Accessor } from "ags";
import { Gtk } from "ags/gtk4";
import Gio from "gi://Gio";

interface VideoProps {
  class?: Accessor<string> | string;
  height?: Accessor<number> | number;
  width?: Accessor<number> | number;
  file: Accessor<string> | string;
  autoplay?: boolean;
  loop?: boolean;
  visible?: Accessor<boolean> | boolean;
}

export default function Video({
  class: className = "video",
  height,
  width,
  file,
  autoplay = true,
  loop = true,
  visible,
}: VideoProps) {
  // Use Gtk.Video directly with explicit size requests.
  // Adw.Clamp was previously used here but it constrains its child to a single
  // maximumSize dimension — when passed height (e.g. 300) it clips the video
  // to 300px wide regardless of the actual display width (e.g. 533px for a
  // 1920×1080 video), causing the video to only fill half the preview window.
  return (
    <Gtk.Video
      class={className}
      autoplay={autoplay}
      loop={loop}
      visible={visible ?? true}
      widthRequest={typeof width === "number" ? width : undefined}
      heightRequest={typeof height === "number" ? height : undefined}
      hexpand={true}
      vexpand={true}
      file={
        typeof file === "string"
          ? Gio.File.new_for_path(file)
          : file((f) => Gio.File.new_for_path(f))
      }
      $={(self: Gtk.Video) => {
        // Full GStreamer/GL teardown when the widget leaves the screen.
        // set_playing(false) alone is not sufficient — the crash logs show
        // gst_gl_context_fill_info fatal assertions and libnvidia-glcore
        // segfaults caused by the previous GstPlay GL context still being
        // alive on the display when a new Gtk.Video tries to initialize.
        // Correct sequence: pause → MediaFile.clear() → detach stream.
        const teardown = () => {
          const stream = self.get_media_stream();
          if (stream) {
            stream.set_playing(false);
            if (stream instanceof Gtk.MediaFile) {
              stream.clear();
            }
          }
          self.set_media_stream(null);
        };
        self.connect("unrealize", teardown);
      }}
    />
  );
}
