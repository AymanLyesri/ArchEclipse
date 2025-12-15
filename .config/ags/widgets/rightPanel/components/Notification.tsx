import { execAsync } from "ags/process";
import GLib from "gi://GLib?version=2.0";
import { createState } from "ags";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Notifd from "gi://AstalNotifd";
import { globalTransition, NOTIFICATION_DELAY } from "../../../variables";
import hyprland from "gi://AstalHyprland";
import { notify } from "../../../utils/notification";
import { asyncSleep, time } from "../../../utils/time";
import { Eventbox } from "../../Custom/Eventbox";
import Pango from "gi://Pango?version=1.0";
import Picture from "../../Picture";
const Hyprland = hyprland.get_default();

// const isIcon = (icon: string) => !!Astal.Icon.lookup_icon(icon);

const [wrapText, setWrapText] = createState<boolean>(false);

const TRANSITION = 200;

function NotificationIcon(n: Notifd.Notification) {
  const notificationIcon = n.image || n.app_icon || n.desktopEntry;

  if (!notificationIcon)
    return <image class="icon" iconName={"dialog-information-symbolic"} />;

  return (
    // <box
    //   class="image"
    //   css={`
    //     background-image: url("${notificationIcon}");
    //     background-size: cover;
    //     background-repeat: no-repeat;
    //     background-position: center;
    //     border-radius: 10px;
    //   `}
    // />
    <Picture file={notificationIcon} class="icon" />
  );
}

function copyNotificationContent(n: Notifd.Notification) {
  if (n.appIcon) {
    execAsync(`bash -c "wl-copy --type image/png < '${n.appIcon}'"`)
      .finally(() => notify({ summary: "Copied", body: n.appIcon }))
      .catch((err) => notify({ summary: "Error", body: err }));
    return;
  }

  const content = n.body || n.app_name;
  if (!content) return;
  execAsync(`wl-copy "${content}"`).catch((err) =>
    notify({ summary: "Error", body: err })
  );
}

export default ({
  n,
  newNotification = false,
  isPopup = false,
  onClose,
  onHide,
}: {
  n: Notifd.Notification;
  newNotification?: boolean;
  isPopup?: boolean;
  onClose?: () => void;
  onHide?: (hideFunc: () => void) => void;
}) => {
  const [IsLocked, setIsLocked] = createState<boolean>(false);
  // IsLocked.subscribe((value) => {
  //   if (!value)
  //     GLib.timeout_add(GLib.PRIORITY_DEFAULT, NOTIFICATION_DELAY, () => {
  //       if (!IsLocked.get() && isPopup) closeNotification();
  //       return false;
  //     });
  // });

  async function closeNotification(dismiss = false) {
    (Revealer as Gtk.Revealer).reveal_child = false;
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, globalTransition, () => {
      // Only dismiss from daemon when in history (not popup)
      // This keeps notifications in history even when popup is closed
      if (dismiss && !isPopup) {
        n.dismiss();
      }
      // Always call onClose to remove from popup map
      if (onClose) onClose();
      return false;
    });
  }

  const icon = (
    <box valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER} class="icon">
      {NotificationIcon(n)}
    </box>
  );

  const title = (
    <label
      class="title"
      xalign={0}
      justify={Gtk.Justification.LEFT}
      maxWidthChars={24}
      wrap={true}
      label={n.summary}
      useMarkup={true}
    />
  );

  const body = (
    <label
      class="body"
      label={n.body}
      wrap={true}
      wrapMode={Pango.WrapMode.WORD_CHAR}
      lines={2}
      vexpand={false} // need height constraint to make wrap work
    />
  );

  // const actions: string[] = n.actions
  //   ? JSON.parse(n.actions.toString()[0])
  //   : [];

  // const Actions = (
  //   <box className="actions">
  //     {actions.map((action) => (
  //       <button
  //         className={action[0].includes("Delete") ? "delete" : ""}
  //         onClicked={() => {
  //           Hyprland.message_async(`dispatch exec ${action[1]}`).catch((err) =>
  //             notify(err)
  //           );
  //         }}
  //         hexpand={true}
  //         child={
  //           <label label={action[0].includes("Delete") ? "󰆴" : action[0]} />
  //         }></button>
  //     ))}
  //   </box>
  // );

  const expand = (
    <togglebutton
      class="expand"
      active={false}
      onToggled={(self) => {
        setWrapText(self.active);
      }}
      label={wrapText((wrap) => (wrap ? "" : ""))}
    />
  );

  const lockButton = (
    <togglebutton
      class="lock"
      label=""
      onToggled={(self) => {
        setIsLocked(self.active);
      }}
    />
  );

  const copyButton = (
    <button
      class="copy"
      label=""
      onClicked={() => copyNotificationContent(n)}
    />
  );

  // const leftRevealer = (
  //   <revealer
  //     reveal_child={false}
  //     transition_type={Gtk.RevealerTransitionType.CROSSFADE}
  //     transitionDuration={globalTransition}
  //   >
  //     {isPopup ? lockButton : copyButton}
  //   </revealer>
  // );

  const close = (
    <button
      class="close"
      label=""
      // sensitive={isPopup}
      onClicked={() => {
        closeNotification(true);
      }}
    />
  );

  // const CircularProgress = (
  //   <circularprogress
  //     class="circular-progress"
  //     rounded={true}
  //     value={1}
  //     $={async (self) => {
  //       while (self.value >= 0) {
  //         self.value -= 0.01;
  //         await asyncSleep(50);
  //       }
  //       self.visible = false;
  //     }}
  //   />
  // );

  const topBar = (
    <box class="top-bar" spacing={5}>
      <box spacing={5}>
        <box visible={isPopup} class="circular-progress-box">
          {/* {CircularProgress} */}
        </box>
        <label wrap={true} class="app-name" label={n.app_name} />

        {copyButton}
      </box>
      <box class={"separator"} hexpand />
      <box class="quick-actions">
        {close}
        {/* {expand} */}
      </box>

      <label halign={Gtk.Align.END} class="time" label={time(n.time)} />
    </box>
  );

  const Box = (
    <box
      class={`notification ${n.urgency} ${n.app_name}`}
      hexpand
      orientation={Gtk.Orientation.VERTICAL}
    >
      {topBar}
      <box spacing={5}>
        {icon}
        <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          {title}
          {body}
        </box>
      </box>
      {/* {Actions} */}
    </box>
  );

  const Revealer = (
    <revealer
      transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
      transitionDuration={TRANSITION}
      reveal_child={!newNotification}
      $={(self) => {
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1, () => {
          self.reveal_child = true;
          return false;
        });
      }}
    >
      {Box}
    </revealer>
  );
  const Parent = (
    <box
      class="notification-parent"
      visible={true}
      $={(self) => {
        // Only handle resolved signal for popups
        if (isPopup) {
          const handler = n.connect("resolved", () => {
            closeNotification(false);
          });
          self.connect("destroy", () => {
            n.disconnect(handler);
          });
        }

        // Expose hide function to parent via callback
        if (onHide) {
          onHide(() => closeNotification(false));
        }
      }}
    >
      {Revealer}
    </box>
  );

  return Parent;
};
