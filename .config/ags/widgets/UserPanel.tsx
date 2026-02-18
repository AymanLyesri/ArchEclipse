import { execAsync, exec } from "ags/process";
import { createPoll } from "ags/time";

import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";

import Hyprland from "gi://AstalHyprland";
import { date_less, date_more } from "../variables";
import { hideWindow } from "../utils/window";
import Picture from "./Picture";
import Gio from "gi://Gio";
import { notify } from "../utils/notification";
import GLib from "gi://GLib";
import { getMonitorName } from "../utils/monitor";
import MediaWidget from "./MediaWidget";
const hyprland = Hyprland.get_default();

// $HOME/.face.icon, if the file doesn't exist, it will return the default user picture path "./assets/userpanel/archeclipse_default_pfp.jpg"
const homePfpPath = GLib.getenv("HOME") + "/.face.icon";
const pfpPath = Gio.File.new_for_path(homePfpPath).query_exists(null)
  ? homePfpPath
  : `${GLib.get_home_dir()}/.config/ags/assets/userpanel/archeclipse_default_pfp.jpg`;

const username = GLib.get_user_name();
const desktopEnv = GLib.getenv("XDG_CURRENT_DESKTOP") || "Unknown DE";

const uptime = createPoll("", 600000, "uptime -p"); // every 10 minutes

const UserPanel = () => {
  const Center = () => {
    const pfp = (
      <button
        class="profile-picture"
        tooltipMarkup={"Click to set up profile picture"}
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
        <Picture file={pfpPath} />
      </button>
    );
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

    const topRevealer = (
      <revealer
        transition-duration={500}
        transition-type={Gtk.RevealerTransitionType.SLIDE_DOWN}
        visible={true}
      >
        <MediaWidget />
      </revealer>
    ) as Gtk.Revealer;

    const bottomRevealer = (
      <revealer
        transition-duration={500}
        transition-type={Gtk.RevealerTransitionType.SLIDE_DOWN}
        visible={true}
      >
        <box class={"info"} orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          {UserName}
          {DesktopEnv}
          {Uptime}
        </box>
      </revealer>
    ) as Gtk.Revealer;

    return (
      <box class={"center"} orientation={Gtk.Orientation.VERTICAL}>
        <Gtk.EventControllerMotion
          onEnter={() => {
            topRevealer.revealChild = true;
            bottomRevealer.revealChild = true;
          }}
          onLeave={() => {
            topRevealer.revealChild = false;
            bottomRevealer.revealChild = false;
          }}
        />
        {/* {topRevealer} */}
        {pfp}
        {bottomRevealer}
      </box>
    );
  };

  const Logout = () => (
    <button
      hexpand={true}
      class="logout system-action"
      label="󰍃"
      onClicked={() => {
        hyprland.message_async("dispatch exit", () => {});
      }}
      tooltipText={"logout from Hyprland"}
      heightRequest={350}
      widthRequest={350}
    />
  );

  const Shutdown = () => (
    <button
      hexpand={true}
      class="shutdown system-action"
      label=""
      onClicked={() => {
        execAsync(`shutdown now`);
      }}
      tooltipText={"shutdown immediately"}
      heightRequest={350}
      widthRequest={350}
    />
  );

  const Reboot = () => (
    <button
      hexpand={true}
      class="reboot system-action"
      label="󰜉"
      onClicked={() => {
        execAsync(`reboot`);
      }}
      tooltipText={"reboot immediately"}
      heightRequest={350}
      widthRequest={350}
    />
  );

  const Sleep = () => (
    <button
      hexpand={true}
      class="sleep system-action"
      label="󰤄"
      onClicked={(self) => {
        hideWindow(`user-panel-${(self.get_root() as any).monitorName}`);
        execAsync(`bash -c "$HOME/.config/hypr/scripts/hyprlock.sh suspend"`);
      }}
      tooltipText={"put system to sleep"}
      heightRequest={350}
      widthRequest={350}
    />
  );

  const Date = (
    <box
      class="section date"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
    >
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

  const display = () => {
    return (
      <overlay>
        <box
          class="display"
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
          hexpand={true}
          vexpand={true}
          $={(container) => {
            // Create a 2x2 Grid with action buttons only
            const grid = new Gtk.Grid({
              halign: Gtk.Align.CENTER,
              valign: Gtk.Align.CENTER,
              rowSpacing: 10,
              columnSpacing: 10,
            });
            grid.add_css_class("user-grid");

            // Top-left: Logout
            const logoutBtn = Logout() as Gtk.Widget;
            grid.attach(logoutBtn, 0, 0, 1, 1);

            // Top-right: Shutdown
            const shutdownBtn = Shutdown() as Gtk.Widget;
            grid.attach(shutdownBtn, 1, 0, 1, 1);

            // Bottom-left: Sleep
            const sleepBtn = Sleep() as Gtk.Widget;
            grid.attach(sleepBtn, 0, 1, 1, 1);

            // Bottom-right: Reboot
            const rebootBtn = Reboot() as Gtk.Widget;
            grid.attach(rebootBtn, 1, 1, 1, 1);

            container.append(grid);
          }}
        />
        <box
          $type="overlay"
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
        >
          <Center />
        </box>
      </overlay>
    );
  };

  return display();
};

export default ({
  monitor,
  setup,
}: {
  monitor: Gdk.Monitor;
  setup: (self: Gtk.Window) => void;
}) => {
  const monitorName = getMonitorName(monitor)!;
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
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.BOTTOM
      }
      $={(self) => {
        setup(self);
        (self as any).monitorName = monitorName;
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
        <UserPanel />
      </box>
    </window>
  );
};
