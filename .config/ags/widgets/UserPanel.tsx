import { bind, exec, execAsync, Variable } from "astal";
import MediaWidget from "./MediaWidget";

import NotificationHistory from "./rightPanel/NotificationHistory";
import { App, Astal, Gdk, Gtk } from "astal/gtk3";

import hyprland from "gi://AstalHyprland";
import { date_less } from "../variables";
import { hideWindow } from "../utils/window";
import { getMonitorName } from "../utils/monitor";
import { notify } from "../utils/notification";
import { FileChooserButton } from "./FileChooser";
const Hyprland = hyprland.get_default();

const pfpPath = exec(`bash -c "echo $HOME/.face.icon"`);
const username = exec(`whoami`);
const uptime = Variable("-").poll(600000, "uptime -p");

const UserPanel = (monitorName: string) => {
  const Profile = () => {
    const UserName = (
      <box halign={Gtk.Align.CENTER} className="user-name">
        <label label="I'm " />
        <label className="name" label={username} />
      </box>
    );

    const Uptime = (
      <box
        halign={Gtk.Align.CENTER}
        className="up-time"
        child={<label className="uptime" label={bind(uptime)} />}
      ></box>
    );

    const ProfilePicture = (
      <box
        className="profile-picture"
        css={`
          background-image: url("${pfpPath}");
        `}
        child={
          <FileChooserButton
            hexpand
            vexpand
            usePreviewLabel={false}
            onFileSet={(self) => {
              let uri = self.get_uri();
              if (!uri) return;
              const cleanUri = uri.replace("file://", ""); // Remove 'file://' from the URI
              execAsync(`bash -c "cp '${cleanUri}' ${pfpPath}"`)
                .then(() => {
                  ProfilePicture.css = `background-image: url('${pfpPath}');`;
                })
                .finally(() => {
                  notify({
                    summary: "Profile picture",
                    body: `${cleanUri} set to ${pfpPath}`,
                  });
                })
                .catch((err) => notify(err));
            }}
          />
        }
      ></box>
    );

    return (
      <box className="profile" vertical={true}>
        {ProfilePicture}
        {UserName}
        {Uptime}
      </box>
    );
  };

  const Actions = () => {
    const Logout = () => (
      <button
        hexpand={true}
        className="logout"
        label="󰍃"
        onClicked={() => {
          Hyprland.message_async("dispatch exit", () => {});
        }}
      />
    );

    const Shutdown = () => (
      <button
        hexpand={true}
        className="shutdown"
        label=""
        onClicked={() => {
          execAsync(`shutdown now`);
        }}
      />
    );

    const Restart = () => (
      <button
        hexpand={true}
        className="restart"
        label="󰜉"
        onClicked={() => {
          execAsync(`reboot`);
        }}
      />
    );

    const Sleep = () => (
      <button
        hexpand={true}
        className="sleep"
        label="󰤄"
        onClicked={() => {
          hideWindow(`user-panel-${monitorName}`);
          execAsync(`bash -c "$HOME/.config/hypr/scripts/hyprlock.sh suspend"`);
        }}
      />
    );

    return (
      <box className="system-actions" vertical={true} spacing={10}>
        <box className="action" spacing={10}>
          {Shutdown()}
          {Restart()}
        </box>
        <box className="action" spacing={10}>
          {Sleep()}
          {Logout()}
        </box>
      </box>
    );
  };

  const right = (
    <box
      halign={Gtk.Align.CENTER}
      className="bottom"
      vertical={true}
      spacing={10}
    >
      {Profile()}
      {Actions()}
    </box>
  );

  const Date = (
    <box
      className="date"
      child={
        <label
          halign={Gtk.Align.CENTER}
          hexpand={true}
          label={bind(date_less)}
        />
      }
    ></box>
  );

  const middle = (
    <box
      className="middle"
      vertical={true}
      hexpand={true}
      vexpand={true}
      spacing={10}
    >
      {/* {Resources()} */}
      {NotificationHistory()}
      {Date}
    </box>
  );

  return (
    <box className="user-panel" spacing={10}>
      {MediaWidget()}
      {middle}
      {right}
    </box>
  );
};

const WindowActions = (monitorName: string) => {
  return (
    <box
      className="window-actions"
      hexpand={true}
      halign={Gtk.Align.END}
      child={
        <button
          className="close"
          label=""
          onClicked={() => {
            hideWindow(`user-panel-${monitorName}`);
          }}
        />
      }
    ></box>
  );
};

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;
  return (
    <window
      gdkmonitor={monitor}
      name={`user-panel-${monitorName}`}
      namespace="user-panel"
      application={App}
      className="user-panel"
      layer={Astal.Layer.OVERLAY}
      visible={false}
      keymode={Astal.Keymode.ON_DEMAND}
      onKeyPressEvent={(self, event) => {
        if (event.get_keyval()[1] === Gdk.KEY_Escape) {
          hideWindow(`user-panel-${monitorName}`);
          return true;
        }
      }}
      child={
        <box className="display" vertical={true} spacing={10}>
          {WindowActions(monitorName)}
          {UserPanel(monitorName)}
        </box>
      }
    />
  );
};
