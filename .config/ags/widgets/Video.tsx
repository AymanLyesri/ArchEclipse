import { Accessor } from "ags";
import { Gtk } from "ags/gtk4";
import Adw from "gi://Adw";
import Gio from "gi://Gio";

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
