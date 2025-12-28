import app from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import GLib from "gi://GLib";
import { Accessor, createComputed } from "ags";

/**
 * Window utility class for managing popup state
 *
 * Usage:
 * 1. Create Window instance in your panel component and store it on a parent box:
 *    $={(self) => { (self as any).windowPropertyName = new Window(); }}
 *
 * 2. In widgets with popovers, call connectPopoverEvents in the $ property:
 *    <menubutton $={(self) => connectPopoverEvents(self, "windowPropertyName")}>>
 *      <popover>...</popover>
 *    </menubutton>
 *
 * 3. Check popup state before hiding panel on leave event:
 *    if (!lock.get() && !windowInstance.popupIsOpen()) { hidePanel(); }
 */

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

class Window {
  private _popupIsOpen: boolean = false;

  constructor() {}

  public popupIsOpen(): boolean {
    return this._popupIsOpen;
  }

  public setPopupIsOpen(value: boolean): void {
    this._popupIsOpen = value;
  }
}

export { Window };

/**
 * Helper function to connect popover events to window popup state
 * Call this in the $ property of a menubutton or any widget with a popover
 */
export const connectPopoverEvents = (
  self: Gtk.MenuButton,
  windowPropertyName: string = "leftPanelWindow"
) => {
  // Find the window instance from parent chain
  const findWindowInstance = () => {
    let parent = self.get_parent();
    let windowInstance = null;
    while (parent && !windowInstance) {
      windowInstance = (parent as any)[windowPropertyName];
      parent = parent.get_parent();
    }
    return windowInstance;
  };

  // Try to connect immediately if popover exists
  const tryConnect = () => {
    const popover = self.get_popover();
    if (popover) {
      const windowInstance = findWindowInstance();
      if (windowInstance && windowInstance.setPopupIsOpen) {
        popover.connect("show", () => {
          windowInstance.setPopupIsOpen(true);
        });
        popover.connect("closed", () => {
          windowInstance.setPopupIsOpen(false);
        });
        return true;
      }
    }
    return false;
  };

  // Try immediately
  if (!tryConnect()) {
    // If popover not ready, use idle_add to try after widget tree is built
    GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      tryConnect();
      return GLib.SOURCE_REMOVE;
    });
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
  const maxPanelWidth = 1500;
  const minPanelWidth = 250;
  return (
    <box
      class="window-actions"
      vexpand={true}
      halign={Gtk.Align.END}
      valign={Gtk.Align.END}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
    >
      <button
        label=""
        class="expand-window"
        onClicked={() => {
          const current = windowWidth.get();
          setWindowWidth(
            current < maxPanelWidth ? current + 50 : maxPanelWidth
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
            current > minPanelWidth ? current - 50 : minPanelWidth
          );
          queueResize(windowName);
        }}
      />
      <togglebutton
        label=""
        class="exclusivity"
        active={windowExclusivity((exclusivity) => !exclusivity)}
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
