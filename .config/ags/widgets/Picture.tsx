import { Accessor } from "ags";
import Gio from "gi://Gio?version=2.0";
import Gtk from "gi://Gtk?version=4.0";

interface PictureProps {
  class?: Accessor<string> | string;
  height?: Accessor<number> | number;
  width?: Accessor<number> | number;
  file: Accessor<string> | string;
  contentFit?: Gtk.ContentFit;
  $?: (self: Gtk.Picture) => void;
}
export default function Picture({
  class: className = "image",
  height,
  width,
  file,
  contentFit = Gtk.ContentFit.COVER,
  $,
}: PictureProps) {
  let pictureRef: Gtk.Picture | undefined;

  return (
    <overlay
      heightRequest={height}
      widthRequest={width}
      $={(self) => {
        const children = self.observe_children();
        const count = children.get_n_items();

        for (let i = 0; i < count; i++) {
          const child = children.get_item(i);

          if (child instanceof Gtk.Picture) {
            pictureRef = child;
          }
        }

        // ⚡ expose helper method
        (self as any).getPicture = () => pictureRef;
      }}
    >
      <Gtk.Picture
        $type="overlay"
        class={"picture " + className}
        file={
          typeof file === "string"
            ? Gio.File.new_for_path(file)
            : file((f) => Gio.File.new_for_path(f))
        }
        contentFit={contentFit}
        $={(self) => {
          // also capture directly (more reliable)
          pictureRef = self;
        }}
      />
    </overlay>
  );
}
