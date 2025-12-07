import Gtk from "gi://Gtk?version=4.0";
import Notifd from "gi://AstalNotifd";
import Notification from "./components/Notification";
import { createState, createComputed, createBinding, For } from "ags";
import CustomRevealer from "../CustomRevealer";

interface Filter {
  name: string;
  class: string;
}

export default () => {
  const [notificationFilter, setNotificationFilter] = createState<Filter>({
    name: "",
    class: "",
  });
  const Filters: Filter[] = [
    { name: "Spotify", class: "spotify" },
    { name: "Clipboard", class: "clipboard" },
    { name: "Update", class: "update" },
  ];

  const Filter = (
    <box class="filter">
      {Filters.map((filter) => (
        <button
          label={filter.name}
          hexpand={true}
          onClicked={() => {
            setNotificationFilter((current) =>
              current.class === filter.class ? { name: "", class: "" } : filter
            );
          }}
          class={notificationFilter((f) =>
            f.class === filter.class ? "active" : ""
          )}
        />
      ))}
    </box>
  );

  function FilterNotifications(
    notifications: Notifd.Notification[],
    filter: string
  ): Notifd.Notification[] {
    const MAX_NOTIFICATIONS = 10;

    // Sort notifications by time (newest first)
    const sortedNotifications = notifications.sort((a, b) => b.time - a.time);

    const filtered: Notifd.Notification[] = [];
    const others: Notifd.Notification[] = [];

    sortedNotifications.forEach((notification) => {
      if (
        notification.app_name.includes(filter) ||
        notification.summary.includes(filter)
      ) {
        filtered.push(notification);
      } else {
        others.push(notification);
      }
    });

    const combinedNotifications = [...filtered, ...others];
    const keptNotifications = combinedNotifications.slice(0, MAX_NOTIFICATIONS);

    // Close excess notifications
    combinedNotifications.slice(MAX_NOTIFICATIONS).forEach((notification) => {
      notification.dismiss();
    });

    return keptNotifications;
  }

  const notifd = Notifd.get_default();

  const filteredNotifications = createComputed((get) => {
    const notifications = get(createBinding(notifd, "notifications"));
    const filter = get(notificationFilter);
    if (!notifications) return [];
    return FilterNotifications(notifications, filter.name);
  });

  const NotificationHistory = (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <For each={filteredNotifications}>
        {(notification) => <Notification n={notification} />}
      </For>
    </box>
  );

  const NotificationsDisplay = (
    <scrolledwindow vexpand={true}>{NotificationHistory}</scrolledwindow>
  );

  const ClearNotifications = (
    <button
      class="clear"
      label=""
      onClicked={() => {
        Notifd.get_default().notifications.forEach((notification) => {
          notification.dismiss();
        });
      }}
    />
  );

  return (
    <box
      class="notification-history"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
    >
      <CustomRevealer trigger={Filter} child={ClearNotifications} />
      {NotificationsDisplay}
    </box>
  );
};
