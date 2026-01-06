import { execAsync } from "ags/process";
import GLib from "gi://GLib?version=2.0";
import { createState } from "ags";
import Gtk from "gi://Gtk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Notifd from "gi://AstalNotifd";
import { globalTransition } from "../../../variables";
import hyprland from "gi://AstalHyprland";
import { notify } from "../../../utils/notification";
import { time } from "../../../utils/time";

import Pango from "gi://Pango?version=1.0";
import Picture from "../../Picture";
import GdkPixbuf from "gi://GdkPixbuf?version=2.0";
import Gdk from "gi://Gdk?version=4.0";
import { timeout } from "ags/time";

interface NotificationProps {
  n: Notifd.Notification;
  newNotification?: boolean;
}

export class NotificationWidget {
  private n: Notifd.Notification;
  private newNotification: boolean;
  private isEllipsized: ReturnType<typeof createState<boolean>>[0];
  private setIsEllipsized: ReturnType<typeof createState<boolean>>[1];
  private Revealer!: Gtk.Revealer;

  constructor(props: NotificationProps) {
    this.n = props.n;
    this.newNotification = props.newNotification ?? false;

    const [isEllipsized, setIsEllipsized] = createState<boolean>(true);

    this.isEllipsized = isEllipsized;
    this.setIsEllipsized = setIsEllipsized;
  }

  private textureFromFile(path: string): Gdk.Texture | undefined {
    try {
      const pixbuf = GdkPixbuf.Pixbuf.new_from_file(path);
      return Gdk.Texture.new_for_pixbuf(pixbuf);
    } catch (e) {
      print("Failed to load image:", e);
    }
  }

  private getNotificationIcon() {
    const notificationIcon =
      this.n.image || this.n.app_icon || this.n.desktopEntry;

    // Check for null/undefined BEFORE calling .endsWith()
    if (!notificationIcon)
      return <image class="icon" iconName={"dialog-information-symbolic"} />;

    if (notificationIcon.endsWith(".webp")) {
      const texture = this.textureFromFile(notificationIcon);
      return <Picture paintable={texture} />;
    }

    return <Picture file={notificationIcon} class="icon" />;
  }

  private copyNotificationContent() {
    if (this.n.appIcon) {
      execAsync(`bash -c "wl-copy --type image/png < '${this.n.appIcon}'"`)
        .finally(() => notify({ summary: "Copied", body: this.n.appIcon }))
        .catch((err) => notify({ summary: "Error", body: err }));
      return;
    }

    const content = this.n.body || this.n.app_name;
    if (!content) return;
    execAsync(`wl-copy "${content}"`).catch((err) =>
      notify({ summary: "Error", body: err })
    );
  }

  private dismissNotification() {
    this.n.dismiss();
  }

  public closeNotification = (dismiss = false) => {
    this.Revealer.reveal_child = false;
    timeout(globalTransition, () => {
      if (dismiss) this.dismissNotification();
    });
  };

  private getIcon() {
    return (
      <box valign={Gtk.Align.START} halign={Gtk.Align.START} class="icon">
        {this.getNotificationIcon()}
      </box>
    );
  }

  private getTitle() {
    return (
      <label
        class="title"
        xalign={0}
        justify={Gtk.Justification.LEFT}
        maxWidthChars={24}
        wrap={true}
        label={this.n.summary}
        useMarkup={true}
      />
    );
  }

  private getBody() {
    return (
      <label
        class="body"
        label={this.n.body}
        wrap={true}
        wrapMode={Pango.WrapMode.WORD_CHAR}
        ellipsize={this.isEllipsized((ellipsized) =>
          ellipsized ? Pango.EllipsizeMode.END : Pango.EllipsizeMode.NONE
        )}
        maxWidthChars={10}
        singleLineMode={this.isEllipsized}
        vexpand={false}
      />
    );
  }

  private getActions() {
    const actions: Notifd.Action[] = this.n.actions;
    return (
      <box class="actions">
        {actions.map((action) => {
          return (
            <button
              hexpand
              onClicked={() => {
                this.n.invoke(action.id);
              }}
            >
              <label label={action.label.split(":").at(-1)!} />
            </button>
          );
        })}
      </box>
    );
  }

  private getExpandButton() {
    return (
      <togglebutton
        class="expand"
        active={false}
        onToggled={(self) => {
          this.setIsEllipsized(!self.active);
        }}
        label={this.isEllipsized((ellipsized) => (!ellipsized ? "" : ""))}
      />
    );
  }

  private getCopyButton() {
    return (
      <button
        class="copy"
        label=""
        onClicked={() => this.copyNotificationContent()}
      />
    );
  }

  private getCloseButton() {
    return (
      <button
        class="close"
        label=""
        onClicked={() => {
          this.closeNotification(true);
        }}
      />
    );
  }

  private getTopBar() {
    return (
      <box class="top-bar" spacing={5}>
        <box spacing={5}>
          {this.n.appIcon && (
            <image class="app-icon" iconName={this.n.appIcon} />
          )}
          <label wrap={true} class="app-name" label={this.n.app_name} />

          {this.getCopyButton()}
        </box>
        <box class={"separator"} hexpand />
        <box class="quick-actions">
          {this.getExpandButton()}
          {this.getCloseButton()}
        </box>

        <label halign={Gtk.Align.END} class="time" label={time(this.n.time)} />
      </box>
    );
  }

  private getNotificationBox() {
    return (
      <box
        class={`notification`}
        hexpand
        orientation={Gtk.Orientation.VERTICAL}
      >
        {this.getTopBar()}
        <box class={"content"} spacing={5}>
          {this.getIcon()}
          <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
            {this.getTitle()}
            {this.getBody()}
          </box>
        </box>
        {this.getActions()}
      </box>
    );
  }

  private getRevealer() {
    return (
      <revealer
        transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
        transitionDuration={globalTransition}
        reveal_child={!this.newNotification}
        $={(self) => {
          this.Revealer = self as Gtk.Revealer;
          GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1, () => {
            self.reveal_child = true;
            return false;
          });
        }}
      >
        {this.getNotificationBox()}
      </revealer>
    );
  }

  public render() {
    return (
      <box class="notification-parent" visible={true}>
        {this.getRevealer()}
      </box>
    );
  }
}
