import Gtk from "gi://Gtk?version=4.0";
import Notifd from "gi://AstalNotifd";
import GLib from "gi://GLib?version=2.0";
import {
  createState,
  createComputed,
  createBinding,
  For,
  Accessor,
  Setter,
} from "ags";
import Pango from "gi://Pango?version=1.0";
import { NotificationWidget } from "./Notification";

/* ----------------------------- Types ----------------------------- */

interface Filter {
  name: string;
  class: string;
}

interface NotificationStack {
  title: string;
  notifications: Notifd.Notification[];
}

/* --------------------------- Utilities --------------------------- */

function stackNotifications(
  notifications: Notifd.Notification[],
  filter: string,
): NotificationStack[] {
  const MAX_NOTIFICATIONS = 50;
  const stacks = new Map<string, Notifd.Notification[]>();

  const sorted = notifications.slice().sort((a, b) => b.time - a.time);

  sorted.forEach((n) => {
    if (filter && !n.summary.includes(filter) && !n.app_name.includes(filter))
      return;

    const key = n.summary || "Unknown";
    if (!stacks.has(key)) stacks.set(key, []);
    stacks.get(key)!.push(n);
  });

  const result = [...stacks.entries()].map(([title, notifications]) => ({
    title,
    notifications,
  }));

  // Keep only newest MAX_NOTIFICATIONS
  const flat = result.flatMap((s) => s.notifications);
  flat.slice(MAX_NOTIFICATIONS).forEach((n) => n.dismiss());

  return result;
}

/* ---------------------- Stack Component --------------------------- */

const NotificationStackView = ({
  stack,
  expandedStacks,
  setExpandedStacks,
}: {
  stack: NotificationStack;
  expandedStacks: Accessor<Map<string, boolean>>;
  setExpandedStacks: Setter<Map<string, boolean>>;
}) => {
  const isExpanded = createComputed(
    () => expandedStacks().get(stack.title) ?? false,
  );

  const visibleNotifications = createComputed(() =>
    isExpanded() ? stack.notifications : stack.notifications.slice(0, 1),
  );

  const ClearNotifications = (
    <button
      class="clear"
      label=""
      onClicked={() => {
        stack.notifications.forEach((n) => n.dismiss());
      }}
    />
  );

  const Actions = () => (
    <box class="actions" spacing={5}>
      {ClearNotifications}
      {stack.notifications.length > 1 && (
        <button
          class="stack-expand"
          label={isExpanded((expanded) => (expanded ? "" : ""))}
          onClicked={() => {
            setExpandedStacks((prev) => {
              const next = new Map(prev);
              next.set(stack.title, !isExpanded());
              return next;
            });
          }}
        />
      )}
    </box>
  );

  return (
    <box class="notification-stack" orientation={Gtk.Orientation.VERTICAL}>
      {/* Header */}
      <box class="stack-header" spacing={5}>
        <label
          class="stack-title"
          hexpand
          xalign={0}
          label={`(${stack.notifications.length}) ${stack.title}`}
          ellipsize={Pango.EllipsizeMode.END}
        />
        <Actions />
      </box>

      {/* Content */}
      <scrolledwindow
        class={isExpanded((expanded) =>
          expanded ? "stack-scrolled expanded" : "stack-scrolled collapsed",
        )}
      >
        <box
          class="stack-content"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={5}
        >
          <For each={visibleNotifications}>
            {(notification) =>
              new NotificationWidget({ n: notification }).render()
            }
          </For>
        </box>
      </scrolledwindow>
    </box>
  );
};

/* --------------------------- Main UI ------------------------------ */

export default ({ className }: { className?: string | Accessor<string> }) => {
  const notifd = Notifd.get_default();

  const [notificationFilter] = createState<Filter>({
    name: "",
    class: "",
  });

  const [expandedStacks, setExpandedStacks] = createState<Map<string, boolean>>(
    new Map(),
  );

  let scrolledWindow: Gtk.ScrolledWindow;
  let savedScrollPosition = 0;

  const stackedNotifications = createBinding(
    notifd,
    "notifications",
  )((notifications) => {
    const filter = notificationFilter.peek();
    if (!notifications) return [];

    // Schedule scroll position restoration after DOM updates
    if (scrolledWindow && savedScrollPosition > 0) {
      GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
        const vadj = scrolledWindow.get_vadjustment();
        if (vadj) {
          vadj.set_value(
            Math.min(
              savedScrollPosition,
              vadj.get_upper() - vadj.get_page_size(),
            ),
          );
        }
        return false;
      });
    }

    return stackNotifications(notifications, filter.name);
  });

  const NotificationHistory = (
    <box orientation={Gtk.Orientation.VERTICAL}>
      <For each={stackedNotifications}>
        {(stack) => (
          <NotificationStackView
            stack={stack}
            expandedStacks={expandedStacks}
            setExpandedStacks={setExpandedStacks}
          />
        )}
      </For>
    </box>
  );

  const NotificationsDisplay = (
    <scrolledwindow
      vexpand
      $={(self) => {
        scrolledWindow = self as Gtk.ScrolledWindow;

        // Track scroll position changes
        const vadj = self.get_vadjustment();
        if (vadj) {
          vadj.connect("value-changed", () => {
            savedScrollPosition = vadj.get_value();
          });
        }
      }}
    >
      {NotificationHistory}
    </scrolledwindow>
  );

  return (
    <box
      class={`notification-history ${className ?? ""}`}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
    >
      {NotificationsDisplay}
    </box>
  );
};
