import { execAsync, exec } from "ags/process";

import App from "ags/gtk4/app";
import { Gtk } from "ags/gtk4";
import { Gdk } from "ags/gtk4";
import { Astal } from "ags/gtk4";

import Hyprland from "gi://AstalHyprland";

import { hideWindow } from "../utils/window";

import { getMonitorName } from "../utils/monitor";

import UserProfile, {
  UserProfileMinimal,
} from "./leftPanel/components/UserProfile";
const hyprland = Hyprland.get_default();

const UserPanel = () => {
  const Logout = () => (
    <button
      hexpand={true}
      class="logout system-action"
      label="󰍃"
      onClicked={() => {
        // hyprland.message_async("dispatch exit", () => {});
        hyprland.dispatch("hl.dsp.exit()", "");
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
          {/* <Center /> */}
          <UserProfileMinimal />
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
      exclusivity={Astal.Exclusivity.IGNORE}
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
