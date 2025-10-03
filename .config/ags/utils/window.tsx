import { Variable } from "astal";
import { App, Gtk } from "astal/gtk3";
import ToggleButton from "../widgets/toggleButton";

export function hideWindow(window_name: string) {
  App.get_window(window_name)!.hide();
}

export function showWindow(window_name: string) {
  App.get_window(window_name)!.show();
}

export function WindowActions({
  windowWidth,
  windowExclusivity,
  windowLock,
  windowVisibility,
}: {
  windowWidth: Variable<number>;
  windowExclusivity: Variable<boolean>;
  windowLock: Variable<boolean>;
  windowVisibility: Variable<boolean>;
}) {
  const maxRightPanelWidth = 600;
  const minRightPanelWidth = 250;
  return (
    <box
      className={"window-actions"}
      vexpand={true}
      halign={Gtk.Align.END}
      valign={Gtk.Align.END}
      vertical={true}
    >
      <button
        label={""}
        className={"expand-window"}
        onClicked={() => {
          windowWidth.set(
            windowWidth.get() < maxRightPanelWidth
              ? windowWidth.get() + 50
              : maxRightPanelWidth
          );
        }}
      />
      <button
        label={""}
        className={"shrink-window"}
        onClicked={() => {
          windowWidth.set(
            windowWidth.get() > minRightPanelWidth
              ? windowWidth.get() - 50
              : minRightPanelWidth
          );
        }}
      />
      <ToggleButton
        label={""}
        className={"exclusivity"}
        state={!windowExclusivity.get()}
        onToggled={(self, on) => {
          windowExclusivity.set(!on);
        }}
      />
      <ToggleButton
        label={windowLock.get() ? "" : ""}
        className={"lock"}
        state={windowLock.get()}
        onToggled={(self, on) => {
          windowLock.set(on);
          self.label = on ? "" : "";
        }}
      />
      <button
        label={""}
        className={"close"}
        onClicked={() => {
          windowVisibility.set(false);
        }}
      />
    </box>
  );
}
