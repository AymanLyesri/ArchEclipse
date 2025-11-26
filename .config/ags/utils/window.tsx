import app from "ags/gtk3/app";
import Gtk from "gi://Gtk?version=3.0";
import { createComputed } from "ags";
import togglebutton from "../widgets/togglebutton";

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
  windowWidth: () => number;
  setWindowWidth: (width: number) => void;
  windowExclusivity: () => boolean;
  setWindowExclusivity: (exclusivity: boolean) => void;
  windowLock: () => boolean;
  setWindowLock: (lock: boolean) => void;
  windowVisibility: () => boolean;
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
      vertical={true}
    >
      <button
        label=""
        class="expand-window"
        onClicked={() => {
          const current = windowWidth();
          setWindowWidth(
            current < maxRightPanelWidth ? current + 50 : maxRightPanelWidth
          );
        }}
      />
      <button
        label=""
        class="shrink-window"
        onClicked={() => {
          const current = windowWidth();
          setWindowWidth(
            current > minRightPanelWidth ? current - 50 : minRightPanelWidth
          );
        }}
      />
      <togglebutton
        label=""
        class="exclusivity"
        active={() => !windowExclusivity()}
        onToggled={(self, on) => {
          setWindowExclusivity(!on);
        }}
      />
      <togglebutton
        label={createComputed(() => (windowLock() ? "" : ""))}
        class="lock"
        active={windowLock}
        onToggled={(self, on) => {
          setWindowLock(on);
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
