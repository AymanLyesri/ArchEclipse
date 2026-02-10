import { Gdk, Gtk } from "ags/gtk4";
import Hyprland from "gi://AstalHyprland";
import AstalApps from "gi://AstalApps";
import { execAsync } from "ags/process";
import { notify } from "./notification";
import Picture from "../widgets/Picture";
import { Accessor, createBinding, createState, With } from "gnim";
import { timeout } from "ags/time";
import { phi } from "../constants/phi.constants";
import GObject from "ags/gobject";

const apps = new AstalApps.Apps();
const hyprland = Hyprland.get_default();

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
        <Picture
          file={screenshotClient(node.client)}
          height={node.client.height / 7}
          width={node.client.width / 7}
        />
        <image $type="overlay" iconName={icon} hexpand vexpand />
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

// Store client title per client to track changes
const titleCache = new Map<number, string>();

function screenshotClient(client: Hyprland.Client): Accessor<string> {
  const [screenshot, setScreenshot] = createState<string>(``);
  const screenshotPath = `/tmp/ags_screenshot_${client.pid}.png`;

  // check if workspace is focused before taking screenshot, if not return placeholder
  if (client.workspace.id !== hyprland.focusedWorkspace.id) {
    setScreenshot(screenshotPath);
    return screenshot;
  }

  // Get current title
  const currentTitle = client.title;
  const cachedTitle = titleCache.get(client.pid);

  // Only take screenshot if title has changed or no screenshot exists
  if (cachedTitle === currentTitle) {
    // Title hasn't changed, use existing screenshot
    setScreenshot(screenshotPath);
    return screenshot;
  }

  timeout(300, () => {
    if (client.workspace.id == hyprland.focusedWorkspace.id) {
      // Build geometry safely
      const x = Math.max(0, client.x);
      const y = Math.max(0, client.y);
      const w = Math.max(50, client.width);
      const h = Math.max(50, client.height);

      const geom = `${x},${y} ${w}x${h}`;
      execAsync(
        // IMPORTANT: geometry must be inside quotes
        `bash -c "grim -g '${geom}' - | convert - -resize 35% -quality 60 -strip '${screenshotPath}'"`,
      )
        .then(() => {
          setScreenshot(screenshotPath);
          // Update cache with new title
          titleCache.set(client.pid, client.title);
        })
        .catch((e) => {
          notify({
            summary: "Screenshot Error",
            body: `Failed to take screenshot for ${client.class}\n${geom}\n${e}`,
          });
        });
    }
  });

  return screenshot;
}

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
