import { Accessor } from "ags";
import Gdk from "gi://Gdk";
import Gio from "gi://Gio";
import { Gtk } from "ags/gtk4";

interface PictureProps {
  class?: Accessor<string> | string;
  height?: Accessor<number> | number;
  width?: Accessor<number> | number;
  file?: Accessor<string> | string;
  paintable?: Accessor<Gdk.Texture> | Gdk.Texture;
  contentFit?: Gtk.ContentFit;
  info?: string[];
  $?: (self: Gtk.Picture) => void;
}
export default function Picture({
  class: className,
  height,
  width,
  file,
  contentFit = Gtk.ContentFit.COVER,
  paintable,
  info,
  $,
}: PictureProps) {
  return (
    <overlay
      class="image"
      heightRequest={height}
      widthRequest={width}
      $={(self) => {
        // Expose a lookup helper without holding a long-lived strong reference.
        (self as any).getPicture = () => {
          const children = self.observe_children();
          const count = children.get_n_items();

          for (let i = 0; i < count; i++) {
            const child = children.get_item(i);

            if (child instanceof Gtk.Picture) {
              return child;
            }
          }

          return undefined;
        };
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
          if ($) {
            $.call(undefined, self);
          }
        }}
      />

      <box
        $type="overlay"
        class="image-info"
        halign={Gtk.Align.END}
        valign={Gtk.Align.END}
        visible={info != undefined}
        spacing={5}
      >
        {info?.map((i) => (
          <label class={"image-info-item"} label={i} />
        ))}
      </box>
    </overlay>
  );
}
