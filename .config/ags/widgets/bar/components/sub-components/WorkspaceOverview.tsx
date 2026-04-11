import { Gdk, Gtk } from "ags/gtk4";
import Hyprland from "gi://AstalHyprland";
import AstalApps from "gi://AstalApps";
import { Accessor, createBinding, createState, With } from "gnim";
import GObject from "ags/gobject";
import Pango from "gi://Pango";

const apps = new AstalApps.Apps();

type Node =
  | { type: "leaf"; client: Hyprland.Client }
  | { type: "vsplit" | "hsplit"; a: Node; b: Node };

const buildTree = (clients: Hyprland.Client[]): Node => {
  if (clients.length === 1) return { type: "leaf", client: clients[0] };

  // Try vertical separator
  const xs = [...new Set(clients.flatMap((c) => [c.x, c.x + c.width]))].sort(
    (a, b) => a - b,
  );

  for (const x of xs) {
    const left = clients.filter((c) => c.x + c.width <= x + 5);
    const right = clients.filter((c) => c.x >= x - 5);

    if (
      left.length &&
      right.length &&
      left.length + right.length === clients.length
    ) {
      return {
        type: "vsplit",
        a: buildTree(left),
        b: buildTree(right),
      };
    }
  }

  // Try horizontal separator
  const ys = [...new Set(clients.flatMap((c) => [c.y, c.y + c.height]))].sort(
    (a, b) => a - b,
  );

  for (const y of ys) {
    const top = clients.filter((c) => c.y + c.height <= y + 5);
    const bot = clients.filter((c) => c.y >= y - 5);

    if (
      top.length &&
      bot.length &&
      top.length + bot.length === clients.length
    ) {
      return {
        type: "hsplit",
        a: buildTree(top),
        b: buildTree(bot),
      };
    }
  }

  // fallback: biggest wins
  const main = clients.sort(
    (a, b) => b.width * b.height - a.width * a.height,
  )[0];

  return { type: "leaf", client: main };
};

const renderNode = (node: Node): Gtk.Widget => {
  if (node.type === "leaf") {
    const [app] = apps.exact_query(node.client.class);
    const icon = app?.iconName || "application-x-executable";

    return (
      <overlay
        class="workspace-client"
        tooltipMarkup={"<b>Hold to drag</b>\n" + node.client.class}
        heightRequest={node.client.height / 7}
        widthRequest={node.client.width / 7}
        $={(self) => {
          /* ---------- Drag source ---------- */
          const dragSource = new Gtk.DragSource({
            actions: Gdk.DragAction.MOVE,
          });

          dragSource.connect("drag-begin", (source) => {
            // Get icon from theme
            const iconTheme = Gtk.IconTheme.get_for_display(
              self.get_display()!,
            );
            const iconPaintable = iconTheme.lookup_icon(
              icon,
              null,
              24,
              1,
              Gtk.TextDirection.NONE,
              0,
            );
            if (iconPaintable) {
              source.set_icon(iconPaintable, 24, 24);
            }
          });

          dragSource.connect("prepare", () => {
            print("DRAG SOURCE PREPARE");

            const value = new GObject.Value();
            value.init(GObject.TYPE_OBJECT);
            value.set_object(node.client);

            print("dragging PID:", node.client.pid);

            return Gdk.ContentProvider.new_for_value(value);
          });

          dragSource.connect("drag-end", () => {});

          self.add_controller(dragSource);
        }}
      >
        <image $type="overlay" iconName={icon} hexpand vexpand />
        <label
          $type="overlay"
          label={createBinding(node.client, "title")}
          class={"title"}
          valign={Gtk.Align.END}
          ellipsize={Pango.EllipsizeMode.END}
        />
        <label
          $type="overlay"
          class={"move"}
          label={"󰆾"}
          valign={Gtk.Align.START}
          halign={Gtk.Align.START}
        />
      </overlay>
    ) as Gtk.Widget;
  }

  const orient =
    node.type === "vsplit"
      ? Gtk.Orientation.HORIZONTAL
      : Gtk.Orientation.VERTICAL;

  return (
    <box orientation={orient} spacing={5} homogeneous>
      {renderNode(node.a)}
      {renderNode(node.b)}
    </box>
  ) as Gtk.Widget;
};

export const workspaceClientLayout = (
  workspace: Hyprland.Workspace | null,
): Gtk.Widget => {
  if (!workspace)
    return (
      <label label={"empty"} class="workspace-client-layout"></label>
    ) as Gtk.Widget;

  return (
    <box class="workspace-client-layout">
      <With value={createBinding(workspace, "clients")}>
        {(clients: Hyprland.Client[]) => {
          if (clients.length === 0) {
            return (
              <label label={"empty"} class="workspace-client-layout"></label>
            ) as Gtk.Widget;
          }
          return renderNode(buildTree(clients));
        }}
      </With>
    </box>
  ) as Gtk.Widget;
};
