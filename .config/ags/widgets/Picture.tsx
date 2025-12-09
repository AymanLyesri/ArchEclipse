import { Accessor } from "ags";
import Gio from "gi://Gio?version=2.0";
import Gtk from "gi://Gtk?version=4.0";

interface PictureProps {
  class?: Accessor<string> | string;
  height?: Accessor<number> | number;
  width?: Accessor<number> | number;
  file: Accessor<Gio.File> | Gio.File;
  contentFit?: Gtk.ContentFit;
}

export default function Picture({
  class: className = "image",
  height,
  width,
  file,
  contentFit = Gtk.ContentFit.COVER,
}: PictureProps) {
  return (
    <overlay heightRequest={height} widthRequest={width}>
      <Gtk.Picture
        $type={"overlay"}
        class={className}
        file={file}
        contentFit={contentFit}
      />
    </overlay>
  );
}
