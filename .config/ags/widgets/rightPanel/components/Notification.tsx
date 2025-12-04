import { execAsync } from "ags/process";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Notifd from "gi://AstalNotifd";
import { globalTransition, NOTIFICATION_DELAY } from "../../../variables";
import Hyprland from "gi://AstalHyprland";
import { notify } from "../../../utils/notification";
import { asyncSleep, time } from "../../../utils/time";
import { createState } from "ags";

const isIcon = (icon: string) => !!image.lookup_icon(icon);

const TRANSITION = 200;

function NotificationIcon(n: Notifd.Notification) {
  const notificationIcon = n.image || n.app_icon || n.desktopEntry;

  if (!notificationIcon)
    return <image class="icon" gicon={"dialog-information-symbolic"} />;

  return (
    <box
      class="image"
      css={`
        background-image: url("${notificationIcon}");
        background-size: cover;
        background-repeat: no-repeat;
        background-position: center;
        border-radius: 10px;
      `}
    />
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
  popup = false,
}: {
  n: Notifd.Notification;
  newNotification?: boolean;
  popup?: boolean;
}) => {
  const [getIsLocked, setIsLocked] = createState<boolean>(false);
  let revealerInstance: Gtk.Revealer | null = null;

  const value = getIsLocked;
  if (!value)
    setTimeout(() => {
      if (!getIsLocked && popup) closeNotification();
    }, NOTIFICATION_DELAY);

  async function closeNotification(dismiss = false) {
    if (revealerInstance) revealerInstance.reveal_child = false;
    setTimeout(() => {
      if (dismiss) n.dismiss();
    }, globalTransition);
  }

  const icon = (
    <box
      valign={Gtk.Align.START}
      halign={Gtk.Align.CENTER}
      hexpand={false}
      class="icon"
      child={NotificationIcon(n)}
    ></box>
  );

  const title = (
    <label
      class="title"
      xalign={0}
      justify={Gtk.Justification.LEFT}
      hexpand={true}
      maxWidthChars={24}
      ellipsize={Pango.EllipsizeMode.END}
      wrap={true}
      label={n.summary}
      useMarkup={true}
    />
  );

  const body = (
    <label
      class="body"
      hexpand={true}
      ellipsize={Pango.EllipsizeMode.END}
      maxWidthChars={24}
      xalign={0}
      justify={Gtk.Justification.LEFT}
      label={n.body}
      wrap={true}
    />
  );

  const expandRevealer = (
    <revealer
      reveal_child={false}
      transition_type={Gtk.RevealerTransitionType.CROSSFADE}
      transitionDuration={globalTransition}
      child={
        <togglebutton
          class="expand"
          active={false}
          onToggled={({ active }) => {
            title.set_property("truncate", !on);
            body.set_property("truncate", !on);
            self.label = on ? "" : "";
          }}
          label=""
        />
      }
    />
  );

  const lockButton = (
    <togglebutton
      class="lock"
      label=""
      onToggled={({ active }) => {
        setIsLocked(on);
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

  const leftRevealer = (
    <revealer
      reveal_child={false}
      transition_type={Gtk.RevealerTransitionType.CROSSFADE}
      transitionDuration={globalTransition}
      child={popup ? lockButton : copyButton}
    />
  );

  const closeRevealer = (
    <revealer
      reveal_child={false}
      transition_type={Gtk.RevealerTransitionType.CROSSFADE}
      transitionDuration={globalTransition}
      child={
        <button
          class="close"
          label=""
          onClicked={() => {
            closeNotification(true);
          }}
        />
      }
    ></revealer>
  );

  const Progress = (
    <progressbar
      class="circular-progress"
      fraction={1}
      $={async (self) => {
        let val = 1;
        while (val >= 0) {
          val -= 0.01;
          self.fraction = val;
          await asyncSleep(50);
        }
        self.visible = false;
      }}
    />
  );

  const topBar = (
    <box class="top-bar" hexpand={true} spacing={5}>
      <box spacing={5} hexpand>
        <box visible={popup} class={"circular-progress-box"} child={Progress} />
        <label
          wrap={true}
          xalign={0}
          truncate={popup}
          class="app-name"
          label={n.app_name}
        />
        {leftRevealer}
      </box>
      <box class={"quick-actions"}>
        {closeRevealer}
        {expandRevealer}
      </box>

      <label xalign={1} class="time" label={time(n.time)} />
    </box>
  );

  const Box = (
    <box
      class={`notification ${n.urgency} ${n.app_name}`}
      child={
        <box
          class="main-content"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={10}
        >
          {topBar}
          {/* <separator /> */}
          <box spacing={5}>
            {icon}
            <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
              <box hexpand={true} child={title}></box>
              {body}
            </box>
          </box>
          {/* {Actions} */}
        </box>
      }
    ></box>
  );

  const Revealer = (
    <revealer
      transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
      transitionDuration={TRANSITION}
      reveal_child={!newNotification}
      $={(self) => {
        revealerInstance = self;
        setTimeout(() => {
          self.reveal_child = true;
        }, 1);
      }}
      child={Box}
    ></revealer>
  );
  const Parent = (
    <box
      visible={true}
      $={(self) =>
        setTimeout(() => {
          if (!getIsLocked() && popup) closeNotification();
        }, NOTIFICATION_DELAY)
      }
      child={
        <Eventbox
          class={"notification-Eventbox"}
          visible={true}
          onHover={() => {
            leftRevealer.reveal_child = true;
            closeRevealer.reveal_child = true;
            expandRevealer.reveal_child = true;
          }}
          onHoverLost={() => {
            if (!getIsLocked()) leftRevealer.reveal_child = false;
            closeRevealer.reveal_child = false;
            expandRevealer.reveal_child = false;
          }}
          onClick={() =>
            popup ? lockButton.activate() : copyButton.activate()
          }
          // onSecondaryClick={() => closeRevealer.child.activate()}
          child={Revealer}
        ></Eventbox>
      }
    ></box>
  );

  return Parent;
};
