import { Accessor } from "ags";
import Gdk from "gi://Gdk";
import Gio from "gi://Gio?version=2.0";
import Gtk from "gi://Gtk?version=4.0";

interface PictureProps {
  class?: Accessor<string> | string;
  height?: Accessor<number> | number;
  width?: Accessor<number> | number;
  file?: Accessor<string> | string;
  paintable?: Accessor<Gdk.Texture> | Gdk.Texture;
  contentFit?: Gtk.ContentFit;
  $?: (self: Gtk.Picture) => void;
}
export default function Picture({
  class: className,
  height,
  width,
  file,
  contentFit = Gtk.ContentFit.COVER,
  paintable,
  $,
}: PictureProps) {
  let pictureRef: Gtk.Picture | undefined;

  return (
    <overlay
      class="image"
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
        class={
          className != undefined
            ? typeof className === "string"
              ? "image " + className
              : className!((c) => "image " + c)
            : "image"
        }
        file={
          file != undefined
            ? typeof file === "string"
              ? Gio.File.new_for_path(file)
              : file!((f) => Gio.File.new_for_path(f))
            : undefined
        }
        paintable={
          paintable != undefined
            ? typeof paintable === "object"
              ? paintable
              : paintable!((p) => p)
            : undefined
        }
        contentFit={contentFit}
        $={(self) => {
          // also capture directly (more reliable)
          pictureRef = self;
          if ($) {
            $.call(undefined, self);
          }
        }}
      />
    </overlay>
  );
}
