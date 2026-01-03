import { Accessor } from "ags";
import Adw from "gi://Adw?version=1";
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
  autoplay = true,
  loop = true,
}: VideoProps) {
  return (
    <Adw.Clamp maximumSize={height || width}>
      <Gtk.Video
        class={className}
        autoplay
        loop
        file={
          typeof file === "string"
            ? Gio.File.new_for_path(file)
            : file((f) => Gio.File.new_for_path(f))
        }
      />
    </Adw.Clamp>
  );
}
