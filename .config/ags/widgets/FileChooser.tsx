import GObject from "gi://GObject";
import Gtk from "gi://Gtk?version=4.0";

export class FileChooserButton extends Gtk.FileChooserButton {
  static {
    GObject.registerClass(this);
  }

  constructor(props: any) {
    super(props as any);
  }
}

// export class FileChooserDialog extends astalify(Gtk.FileChooserDialog) {
//   static {
//     GObject.registerClass(this);
//   }

//   constructor(
//     props: ConstructProps<
//       Gtk.FileChooserDialog.ConstructorProps,
//       { onFileSet: [] }
//     >
//   ) {
//     super(props as any);
//   }
// }
