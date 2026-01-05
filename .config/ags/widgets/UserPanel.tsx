import { execAsync, exec } from "ags/process";
import { createPoll } from "ags/time";
import MediaWidget from "./MediaWidget";

import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";

import Hyprland from "gi://AstalHyprland";
import { date_less, date_more } from "../variables";
import { hideWindow } from "../utils/window";
import { getMonitorName } from "../utils/monitor";
import Picture from "./Picture";
import NotificationHistory from "./rightPanel/components/NotificationHistory";
import Gio from "gi://Gio";
import { notify } from "../utils/notification";
import GLib from "gi://GLib";
import { monitorFile } from "ags/file";
const hyprland = Hyprland.get_default();

const pfpPath = exec(`bash -c "echo $HOME/.face.icon"`);
const username = exec(`whoami`);
const desktopEnv = exec(`bash -c "echo $XDG_CURRENT_DESKTOP"`);
const uptime = createPoll("", 600000, "uptime -p"); // every 10 minutes

const UserPanel = (monitorName: string) => {
  const Profile = () => {
    const UserName = (
      <box halign={Gtk.Align.CENTER} class="user-name">
        <label label="I'm " />
        <label class="secondary" label={username} />
      </box>
    );
    const DesktopEnv = (
      <box class="desktop-env" halign={Gtk.Align.CENTER}>
        <label label="On " />
        <label class="secondary" label={desktopEnv} />
      </box>
    );

    const Uptime = (
      <box halign={Gtk.Align.CENTER} class="up-time">
        <label class="uptime" label={uptime} />
      </box>
    );

    const ProfilePicture = (
      <button
        class="profile-picture"
        onClicked={async (self) => {
          // setProgressStatus("loading");
          const dialog = new Gtk.FileDialog({
            title: "Open Image",
            modal: true,
          });

          // Image filter
          const filter = new Gtk.FileFilter();
          filter.set_name("Images");
          filter.add_mime_type("image/png");
          filter.add_mime_type("image/jpeg");
          filter.add_mime_type("image/webp");

          dialog.set_default_filter(filter);

          try {
            const root = self.get_root();
            if (!(root instanceof Gtk.Window)) return;

            const file: Gio.File = await new Promise((resolve, reject) => {
              dialog.open(root, null, (dlg, res) => {
                try {
                  resolve(dlg!.open_finish(res));
                } catch (e) {
                  reject(e);
                }
              });
            });

            if (!file) return;

            const filename = file.get_path();
            if (!filename) return;

            await execAsync(`bash -c "cp '${filename}' $HOME/.face.icon"`);

            notify({
              summary: "Success",
              body: "User picture updated!",
            });
            // refresh picture
            const picture = (self.child as any).getPicture() as Gtk.Picture;
            picture.set_file(Gio.File.new_for_path(filename));
            // setProgressStatus("success");
          } catch (err) {
            // Gtk.FileDialog throws on cancel — ignore silently
            if (
              err instanceof GLib.Error &&
              err.matches(Gtk.dialog_error_quark(), Gtk.DialogError.CANCELLED)
            )
              return;

            // setProgressStatus("error");

            notify({
              summary: "Error",
              body: String(err),
            });
          }
        }}
      >
        <Picture file={pfpPath} width={200} height={200} />
      </button>

      // </box>
    );

    return (
      <box class="profile" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
        {ProfilePicture}
        {UserName}
        {DesktopEnv}
        {Uptime}
      </box>
    );
  };

  const Actions = () => {
    const Logout = () => (
      <button
        hexpand={true}
        class="logout"
        label="󰍃"
        onClicked={() => {
          hyprland.message_async("dispatch exit", () => {});
        }}
      />
    );

    const Shutdown = () => (
      <button
        hexpand={true}
        class="shutdown"
        label=""
        onClicked={() => {
          execAsync(`shutdown now`);
        }}
        tooltipText={"SUPER + CTRL + SHIFT + ESC"}
      />
    );

    const Restart = () => (
      <button
        hexpand={true}
        class="restart"
        label="󰜉"
        onClicked={() => {
          execAsync(`reboot`);
        }}
      />
    );

    const Sleep = () => (
      <button
        hexpand={true}
        class="sleep"
        label="󰤄"
        onClicked={() => {
          hideWindow(`user-panel-${monitorName}`);
          execAsync(`bash -c "$HOME/.config/hypr/scripts/hyprlock.sh suspend"`);
        }}
        tooltipText={"SUPER + CTRL + ESC"}
      />
    );

    return (
      <box
        class="system-actions"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
      >
        <box class="action" spacing={10}>
          <Shutdown />
          <Restart />
        </box>
        <box class="action" spacing={10}>
          <Sleep />
          <Logout />
        </box>
      </box>
    );
  };

  const right = (
    <box
      halign={Gtk.Align.CENTER}
      class="bottom"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
    >
      <Profile />
      <Actions />
    </box>
  );

  const Date = (
    <box class="date" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <label
        class={"less"}
        halign={Gtk.Align.CENTER}
        hexpand={true}
        label={date_less}
      />
      <label
        class={"more"}
        halign={Gtk.Align.CENTER}
        hexpand={true}
        label={date_more}
      />
    </box>
  );

  const middle = (
    <box
      class="middle"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand={true}
      vexpand={true}
      spacing={10}
    >
      <NotificationHistory />
      {Date}
    </box>
  );

  return (
    <box class="main" spacing={10}>
      <MediaWidget />
      {middle}
      {right}
    </box>
  );
};

const WindowActions = (monitorName: string) => {
  return (
    <box class="window-actions" hexpand={true} halign={Gtk.Align.END}>
      <button
        class="close"
        label=""
        onClicked={() => {
          hideWindow(`user-panel-${monitorName}`);
        }}
      />
    </box>
  );
};

export default ({ monitor }: { monitor: Gdk.Monitor }) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;
  return (
    <window
      gdkmonitor={monitor}
      name={`user-panel-${monitorName}`}
      namespace="user-panel"
      application={App}
      class="user-panel"
      layer={Astal.Layer.OVERLAY}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
      $={(self) => {
        const key = new Gtk.EventControllerKey();
        key.connect("key-pressed", (controller, keyval) => {
          if (keyval === Gdk.KEY_Escape) {
            self.hide();
            return true;
          }
          return false;
        });
        self.add_controller(key);
      }}
    >
      <box class="display" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
        {WindowActions(monitorName)}
        {UserPanel(monitorName)}
      </box>
    </window>
  );
};
