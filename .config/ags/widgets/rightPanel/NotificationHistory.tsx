import Gtk from "gi://Gtk?version=3.0";
import Notifd from "gi://AstalNotifd";
import Notification from "./components/Notification";
import { createBinding, createState, createComputed } from "ags";
import CustomRevealer from "../CustomRevealer";

interface Filter {
  name: string;
  class: string;
}

const [getFilter, setFilter] = createState<Filter>({ name: "", class: "" });

export default () => {
  const Filters: Filter[] = [
    { name: "Spotify", class: "spotify" },
    { name: "Clipboard", class: "clipboard" },
    { name: "Update", class: "update" },
  ];

  const Filter = (
    <box className="filter">
      {Filters.map((filter) => (
        <button
          label={filter.name}
          hexpand={true}
          onClicked={() => {
            const current = getFilter();
            setFilter(current === filter ? { name: "", class: "" } : filter);
          }}
          className={createComputed(() =>
            getFilter().class === filter.class ? "active" : ""
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
  const notifications = createBinding(notifd, "notifications");

  const NotificationHistory = (
    <box vertical={true} spacing={5}>
      {createComputed(() => {
        const list = notifications();
        const filter = getFilter();
        if (!list) return [];
        return FilterNotifications(list, filter.name).map((notification) => (
          <Notification n={notification} />
        ));
      })}
    </box>
  );

  const NotificationsDisplay = (
    <scrollable
      hscroll={Gtk.PolicyType.NEVER}
      vexpand={true}
      child={NotificationHistory}
    ></scrollable>
  );

  const ClearNotifications = (
    <button
      className="clear"
      label=""
      onClicked={() => {
        notifd.notifications.forEach((notification) => {
          notification.dismiss();
        });
      }}
    />
  );

  return (
    <box className="notification-history" vertical={true} spacing={5}>
      <CustomRevealer trigger={Filter} child={ClearNotifications} />
      {NotificationsDisplay}
    </box>
  );
};
