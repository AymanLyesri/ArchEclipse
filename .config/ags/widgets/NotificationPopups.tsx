import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Notifd from "gi://AstalNotifd";
import { createState, createComputed, For, Accessor } from "ags";
import { globalMargin, globalSettings, globalTransition } from "../variables";
import { timeout, Timer } from "ags/time";
import { NotificationWidget } from "./rightPanel/components/Notification";

// see comment below in constructor
const TIMEOUT_DELAY = 4000;

// The purpose if this class is to replace Variable<Array<Widget>>
// with a Map<number, NotificationWidget> type in order to track notification widgets
// by their id, while making it conveniently bindable as an array
class NotificationMap {
  // the underlying notificationMap to keep track of id -> NotificationWidget pairs
  private notificationMap: Map<number, NotificationWidget> = new Map();

  // it makes sense to use a Variable under the hood and use its
  // reactivity implementation instead of keeping track of subscribers ourselves
  private notifications: Accessor<Array<NotificationWidget>>;
  private setNotifications: (value: Array<NotificationWidget>) => void;

  // notify subscribers to rerender when state changes
  private notify() {
    this.setNotifications([...this.notificationMap.values()].reverse());
  }

  constructor() {
    const [notifications, setNotifications] = createState<
      Array<NotificationWidget>
    >([]);
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
      if (globalSettings.peek().notifications.dnd) return;

      const notifWidget = new NotificationWidget({
        n: notifd.get_notification(id)!,
        newNotification: true,
      });

      this.set(id, notifWidget);

      // Auto-remove notification from popup after delay
      // Don't dismiss from daemon to keep in history
      timeout(TIMEOUT_DELAY, () => {
        if (this.notificationMap.has(id)) {
          // Trigger close animation via the notification's hide function
          notifWidget.closeNotification(false);
          // Wait for animation to complete, then remove from map
          timeout(globalTransition, () => {
            this.delete(id);
          });
        }
      });
    });

    // notifications can be closed by the outside before
    // any user input, which have to be handled too
    notifd.connect("resolved", (_, id) => {
      // Remove from popup when dismissed from history or externally
      if (this.notificationMap.has(id)) {
        timeout(globalTransition, () => {
          this.delete(id);
        });
      }
    });
  }

  private set(key: number, value: NotificationWidget) {
    // in case of replacement, remove previous widget
    if (this.notificationMap.has(key)) {
      this.notificationMap.delete(key);
    }
    this.notificationMap.set(key, value);
    this.notify();
  }

  private delete(key: number) {
    this.notificationMap.delete(key);
    this.notify();
  }

  // needed by the Subscribable interface
  get() {
    return this.notifications;
  }
}

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const { TOP, RIGHT } = Astal.WindowAnchor;
  const notifications = new NotificationMap().get();

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
      visible={notifications((notifs) => notifs.length > 0)}
      resizable={false}
      $={(self) => {
        setup(self);
      }}
    >
      <box
        class={"notification-popups"}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
      >
        <For each={notifications}>{(notifWidget) => notifWidget.render()}</For>
      </box>
    </window>
  );
};
