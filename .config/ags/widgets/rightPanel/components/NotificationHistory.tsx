import Gtk from "gi://Gtk?version=4.0";
import Notifd from "gi://AstalNotifd";
import { createState, createComputed, createBinding, For } from "ags";
import Pango from "gi://Pango?version=1.0";
import Notification from "./Notification";

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
  filter: string
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

const NotificationStackView = ({ stack }: { stack: NotificationStack }) => {
  const [expanded, setExpanded] = createState(false);

  const visibleNotifications = createComputed(() =>
    expanded() ? stack.notifications : stack.notifications.slice(0, 1)
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
          label={expanded((expanded) => (expanded ? "" : ""))}
          onClicked={() => setExpanded(!expanded())}
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
      <box
        class="stack-content"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
      >
        <For each={visibleNotifications}>
          {(notification) => <Notification n={notification} />}
        </For>
      </box>
    </box>
  );
};

/* --------------------------- Main UI ------------------------------ */

export default () => {
  const notifd = Notifd.get_default();

  const [notificationFilter] = createState<Filter>({
    name: "",
    class: "",
  });

  const stackedNotifications = createBinding(
    notifd,
    "notifications"
  )((notifications) => {
    const filter = notificationFilter.peek();
    if (!notifications) return [];
    return stackNotifications(notifications, filter.name);
  });

  const NotificationHistory = (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <For each={stackedNotifications}>
        {(stack) => <NotificationStackView stack={stack} />}
      </For>
    </box>
  );

  const NotificationsDisplay = (
    <scrolledwindow vexpand>{NotificationHistory}</scrolledwindow>
  );

  return (
    <box
      class="notification-history"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
    >
      {NotificationsDisplay}
    </box>
  );
};
