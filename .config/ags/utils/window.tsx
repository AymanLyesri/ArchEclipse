import app from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import GLib from "gi://GLib";
import { Accessor, createComputed } from "ags";

export const hideWindow = (name: string) => app.get_window(name)?.hide();
export const showWindow = (name: string) => app.get_window(name)?.show();
export const queueResize = (name: string) => {
  const window = app.get_window(name);
  if (window) {
    // For layer-shell windows in Hyprland, we need to hide/show to force size update
    const wasVisible = window.get_visible();
    if (wasVisible) {
      window.hide();
      // Use GLib.idle_add to ensure GTK processes the hide before showing again
      GLib.idle_add(GLib.PRIORITY_HIGH_IDLE, () => {
        window.show();
        return GLib.SOURCE_REMOVE;
      });
    }
  }
};

export function WindowActions({
  windowName,
  windowWidth,
  setWindowWidth,
  windowExclusivity,
  setWindowExclusivity,
  windowLock,
  setWindowLock,
  windowVisibility,
  setWindowVisibility,
}: {
  windowName: string;
  windowWidth: Accessor<number>;
  setWindowWidth: (width: number) => void;
  windowExclusivity: Accessor<boolean>;
  setWindowExclusivity: (exclusivity: boolean) => void;
  windowLock: Accessor<boolean>;
  setWindowLock: (lock: boolean) => void;
  windowVisibility: Accessor<boolean>;
  setWindowVisibility: (visibility: boolean) => void;
}) {
  const maxRightPanelWidth = 600;
  const minRightPanelWidth = 250;
  return (
    <box
      class="window-actions"
      vexpand={true}
      halign={Gtk.Align.END}
      valign={Gtk.Align.END}
      orientation={Gtk.Orientation.VERTICAL}
    >
      <button
        label=""
        class="expand-window"
        onClicked={() => {
          const current = windowWidth.get();
          setWindowWidth(
            current < maxRightPanelWidth ? current + 50 : maxRightPanelWidth
          );
          queueResize(windowName);
        }}
      />
      <button
        label=""
        class="shrink-window"
        onClicked={() => {
          const current = windowWidth.get();
          setWindowWidth(
            current > minRightPanelWidth ? current - 50 : minRightPanelWidth
          );
          queueResize(windowName);
        }}
      />
      <togglebutton
        label=""
        class="exclusivity"
        active={!windowExclusivity}
        onToggled={({ active }) => {
          setWindowExclusivity(!active);
        }}
      />
      <togglebutton
        label={windowLock((lock) => (lock ? "" : ""))}
        class="lock"
        active={windowLock}
        onToggled={({ active }) => {
          setWindowLock(active);
        }}
      />
      <button
        label=""
        class="close"
        onClicked={() => {
          setWindowVisibility(false);
        }}
      />
    </box>
  );
}
