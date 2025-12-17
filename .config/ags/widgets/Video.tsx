import { Accessor } from "ags";
import Gio from "gi://Gio?version=2.0";
import Gtk from "gi://Gtk?version=4.0";

interface VideoProps {
  class?: Accessor<string> | string;
  height?: Accessor<number> | number;
  width?: Accessor<number> | number;
  file: Accessor<string> | string;
  autoplay?: boolean;
  loop?: boolean;
}

export default function Video({
  class: className = "video",
  height,
  width,
  file,
  autoplay = false,
  loop = false,
}: VideoProps) {
  let videoRef: Gtk.Video | undefined;

  return (
    <overlay
      heightRequest={height}
      widthRequest={width}
      $={(self) => {
        const children = self.observe_children();
        const count = children.get_n_items();

        for (let i = 0; i < count; i++) {
          const child = children.get_item(i);

          if (child instanceof Gtk.Video) {
            videoRef = child;
          }
        }

        // ⚡ expose helper method
        (self as any).getVideo = () => videoRef;
      }}
    >
      <Gtk.Video
        $type="overlay"
        class={"video " + className}
        file={
          typeof file === "string"
            ? Gio.File.new_for_path(file)
            : file((f) => Gio.File.new_for_path(f))
        }
        autoplay={autoplay}
        loop={loop}
        $={(self) => {
          // also capture directly (more reliable)
          videoRef = self;
        }}
      />
    </overlay>
  );
}
