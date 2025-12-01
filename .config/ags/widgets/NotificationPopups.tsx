import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Notifd from "gi://AstalNotifd";
import Notification from "./rightPanel/components/Notification";
import { createState, createComputed } from "ags";
import { DND, globalMargin } from "../variables";

// see comment below in constructor
const TIMEOUT_DELAY = 5000;

// The purpose if this class is to replace Variable<Array<Widget>>
// with a Map<number, Widget> type in order to track notification widgets
// by their id, while making it conveniently bindable as an array
class NotificationMap {
  // the underlying notificationMap to keep track of id widget pairs
  private notificationMap: Map<number, any> = new Map();

  // it makes sense to use a Variable under the hood and use its
  // reactivity implementation instead of keeping track of subscribers ourselves
  private notifications: any;
  private setNotifications: any;

  // notify subscribers to rerender when state changes
  private notify() {
    this.setNotifications([...this.notificationMap.values()].reverse());
  }

  constructor() {
    const [notifications, setNotifications] = createState<Array<any>>([]);
    this.notifications = notifications;
    this.setNotifications = setNotifications;

    const notifd = Notifd.get_default();

    /**
     * uncomment this if you want to
     * ignore timeout by senders and enforce our own timeout
     * note that if the notification has any actions
     * they might not work, since the sender already treats them as resolved
     */
    // notifd.ignoreTimeout = true

    notifd.connect("notified", (_, id) => {
      if (DND()) return;
      // this.clearOldNotifications(); // Clear old notifications before adding new one
      this.set(
        id,
        Notification({
          n: notifd.get_notification(id)!,
          newNotification: true,
          popup: true,
        })
      );
    });

    // notifications can be closed by the outside before
    // any user input, which have to be handled too
    notifd.connect("resolved", (_, id) => {
      this.delete(id);
    });
  }

  private set(key: number, value: any) {
    // in case of replacecment destroy previous widget
    this.notificationMap.get(key)?.destroy();
    this.notificationMap.set(key, value);
    this.notify();
  }

  private delete(key: number) {
    this.notificationMap.get(key)?.destroy();
    this.notificationMap.delete(key);
    this.notify();
  }

  // private clearOldNotifications() {
  //   const now = Date.now();

  //   const notifd = Notifd.get_default();

  //   // Clear notifications that are older than TIMEOUT_DELAY
  //   for (const [id, widget] of this.notificationMap.entries()) {
  //     const notification = notifd.get_notification(id);
  //     if (!notification) {
  //       // If notification doesn't exist in notifd, remove it
  //       this.delete(id);
  //       continue;
  //     }

  //     // Calculate age of notification in milliseconds
  //     const age = now - notification.get_time() * 1000;

  //     print(`Notification ${id} age: ${age} milliseconds`);

  //     if (age > TIMEOUT_DELAY) {
  //       this.delete(id);
  //     }
  //   }
  // }

  // needed by the Subscribable interface
  get() {
    return this.notifications();
  }

  // needed by the Subscribable interface
  subscribe(callback: (list: Array<any>) => void) {
    // In the new system, we might not need subscribe if we use the accessor directly in JSX
    // But for compatibility if needed:
    // return this.notifications.subscribe(callback);
    // Since we are using createComputed or just passing the accessor, we can just return a cleanup function or similar
    // However, for this specific case, we can just expose the accessor.
    return () => {};
  }
}

export default (monitor: Gdk.Monitor) => {
  const { TOP, RIGHT } = Astal.WindowAnchor;
  const notifications = new NotificationMap();

  return (
    <window
      gdkmonitor={monitor}
      class="NotificationPopups"
      name="notification-popups"
      namespace="notification-popups"
      application={App}
      exclusivity={Astal.Exclusivity.NORMAL}
      layer={Astal.Layer.OVERLAY}
      anchor={TOP | RIGHT}
      margin={globalMargin}
      widthRequest={400}
      child={
        <box
          class={"notification-popups"}
          vertical
          vexpand={true}
          child={createComputed(() => (
            <box vertical>{notifications.get().map((n: any) => n)}</box>
          ))}
        />
      }
    />
  );
};
