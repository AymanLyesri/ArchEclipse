import app from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import { Accessor, createComputed } from "ags";

export const hideWindow = (name: string) => app.get_window(name)?.hide();
export const showWindow = (name: string) => app.get_window(name)?.show();

export function WindowActions({
  windowWidth,
  setWindowWidth,
  windowExclusivity,
  setWindowExclusivity,
  windowLock,
  setWindowLock,
  windowVisibility,
  setWindowVisibility,
}: {
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
