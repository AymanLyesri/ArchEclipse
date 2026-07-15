import app from "ags/gtk4/app";
import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib";
import { Accessor, createComputed } from "ags";
import { setGlobalSetting } from "../variables";

/**
 * Window utility class for managing popup state
 *
 * Usage:
 * 1. Create Window instance in your panel component and store it on a parent box:
 *    $={(self) => { (self as any).windowPropertyName = new Window(); }}
 *
 * 2. In widgets with popovers, call connectPopoverEvents in the $ property:
 *    <menubutton $={(self) => connectPopoverEvents(self, "windowPropertyName")}>...
 *    </menubutton>
 *    <button $={(self) => {
 *      const popover = new Gtk.Popover(...);
 *      popover.set_parent(self);
 *      connectPopoverEvents(self, "windowPropertyName", popover);
 *    }}>...
 *    </button>
 *
 * 3. Check popup state before hiding panel on leave event:
 *    if (!lock.get() && !windowInstance.popupIsOpen()) { hidePanel(); }
 */

export const hideWindow = (name: string) => app.get_window(name)?.hide();
export const showWindow = (name: string) => app.get_window(name)?.show();
export const queueResize = (window: Gtk.Window | null) => {
  print("Queueing resize for window:", window?.name);
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
  private _openPopovers: Set<Gtk.Popover> = new Set();
  private _isDragging: boolean = false;

  constructor() {}

  public popupIsOpen(): boolean {
    return this._openPopovers.size > 0;
  }

  // Kept for compatibility if anything still calls this directly —
  // but prefer addOpenPopover/removeOpenPopover below.
  public setPopupIsOpen(value: boolean): void {
    if (!value) this._openPopovers.clear();
  }

  public addOpenPopover(popover: Gtk.Popover): void {
    this._openPopovers.add(popover);
  }

  public removeOpenPopover(popover: Gtk.Popover): void {
    this._openPopovers.delete(popover);
  }

  public isDragging(): boolean {
    return this._isDragging;
  }

  public setIsDragging(value: boolean): void {
    this._isDragging = value;
  }
}

export { Window };

/**
 * Helper function to connect popover events to window popup state
 * Call this in the $ property of a menubutton or any widget with a popover
 */
export const connectPopoverEvents = (
  self: Gtk.Widget,
  windowPropertyName: string = "leftPanelWindow",
  popover?: Gtk.Popover | null,
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

  const getPopover = () => {
    if (popover) return popover;

    const menuButton = self as Gtk.MenuButton;
    return typeof menuButton.get_popover === "function"
      ? menuButton.get_popover()
      : null;
  };

  const tryConnect = () => {
    const currentPopover = getPopover();
    if (currentPopover) {
      const updatePopupState = () => {
        const windowInstance = findWindowInstance();
        if (!windowInstance) return;

        if (currentPopover.visible) {
          windowInstance.addOpenPopover?.(currentPopover);
        } else {
          windowInstance.removeOpenPopover?.(currentPopover);
        }
      };

      currentPopover.connect("notify::visible", updatePopupState);
      currentPopover.connect("destroy", () => {
        const windowInstance = findWindowInstance();
        windowInstance?.removeOpenPopover?.(currentPopover);
      });
      updatePopupState();
      return true;
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
  windowWidth,
  windowSettingKey,
  windowExclusivity,
  windowLock,
  maxPanelWidth = 1500,
  minPanelWidth = 250,
}: {
  windowWidth: Accessor<number>;
  windowSettingKey: string;
  windowExclusivity: Accessor<boolean>;
  windowLock: Accessor<boolean>;
  maxPanelWidth?: number;
  minPanelWidth?: number;
}) {
  let parentWindow: Gtk.Window | null;
  return (
    <box
      class="window-actions"
      vexpand={true}
      halign={Gtk.Align.END}
      valign={Gtk.Align.END}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
      $={(self) => {
        self.connect("notify::root", () => {
          const root = self.get_root();
          if (root instanceof Gtk.Window) {
            parentWindow = root;
          }
        });
      }}
    >
      <button
        label=""
        class="expand-window"
        onClicked={() => {
          const current = windowWidth.get();
          setGlobalSetting(
            windowSettingKey + ".width",
            current < maxPanelWidth ? current + 50 : maxPanelWidth,
          );
          queueResize(parentWindow);
        }}
      />
      <button
        label=""
        class="shrink-window"
        onClicked={() => {
          const current = windowWidth.get();
          setGlobalSetting(
            windowSettingKey + ".width",
            current > minPanelWidth ? current - 50 : minPanelWidth,
          );
          queueResize(parentWindow);
        }}
      />
      <togglebutton
        label=""
        class="exclusivity"
        active={windowExclusivity((exclusivity) => !exclusivity)}
        onToggled={({ active }) => {
          setGlobalSetting(windowSettingKey + ".exclusivity", !active);
        }}
      />
      <togglebutton
        label={windowLock((lock) => (lock ? "" : ""))}
        class="lock"
        active={windowLock}
        onToggled={({ active }) => {
          setGlobalSetting(windowSettingKey + ".lock", active);
        }}
      />
      <button
        label=""
        class="close"
        onClicked={() => {
          app.get_window(parentWindow?.name || "")?.hide();
        }}
      />
    </box>
  );
}
