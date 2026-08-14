import { Accessor, createState, With } from "ags";
import { Astal, Gdk, Gtk } from "ags/gtk4";
import GLib from "gi://GLib";
import { barState, deactivateState } from "../Bar";
import { globalSettings } from "../../../variables";
import AppLauncher from "../../applauncher/AppLauncher";

export const [searchQuery, setSearchQuery] = createState<string>("");

export const [searchActivate, setSearchActivate] = createState<number>(0);

// Fresh object per keypress so equal directions still emit.
export const [searchNavigate, setSearchNavigate] = createState<{
  direction: number;
}>({ direction: 0 });

export default ({ widthRequest }: { widthRequest?: Accessor<number> }) => {
  let entryRef: Gtk.TextView | null = null;
  let popoverRef: Gtk.Popover | null = null;
  let settingFromState = false; // guards buffer<->state feedback loop
  let popupTimer: any = null;

  // Auto input mode: keyboard and mouse both work (ON_DEMAND keymode) and
  // Esc closes the launcher. Legacy mode (default): the launcher grabs the
  // keyboard exclusively; Esc toggles between keyboard grab and mouse input,
  // since Hyprland restricts pointer input while a layer surface holds the
  // keyboard exclusively.
  const autoInput = () =>
    globalSettings.peek().bar.searchAutoInput.value as boolean;

  // Legacy mode only: whether the keyboard is exclusively grabbed right now.
  const [isExclusive, setIsExclusive] = createState<boolean>(true);

  const applyKeymode = () => {
    const window = entryRef?.get_root() as Gtk.Window | undefined;
    if (!window) return;
    if (barState.peek() !== "search") {
      window.keymode = Astal.Keymode.NONE;
      return;
    }
    window.keymode = autoInput()
      ? Astal.Keymode.ON_DEMAND
      : isExclusive.peek()
        ? Astal.Keymode.EXCLUSIVE
        : Astal.Keymode.ON_DEMAND;
  };

  const cancelPendingPopup = () => {
    if (popupTimer) {
      popupTimer.cancel?.();
      popupTimer = null;
    }
  };

  const showPopover = () => {
    if (!popoverRef || !entryRef) return;

    cancelPendingPopup();
    popupTimer = GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
      popupTimer = null;

      if (!popoverRef || !entryRef || barState.peek() !== "search") {
        return GLib.SOURCE_REMOVE;
      }

      if (popoverRef.get_parent() !== entryRef) {
        popoverRef.set_parent(entryRef);
      }

      if (!popoverRef.visible) {
        popoverRef.popup();
      }

      entryRef.grab_focus();
      return GLib.SOURCE_REMOVE;
    });
  };

  const closePopover = () => {
    cancelPendingPopup();
    popoverRef?.popdown();
  };

  // The bar's Window bookkeeping instance lives on the pill box, not on
  // the root window - walk up like the workspace popovers do.
  const findBarWindow = () => {
    let parent = entryRef?.get_parent();
    let candidate: any = null;
    while (parent && !candidate) {
      candidate = (parent as any).barWindow;
      parent = parent.get_parent();
    }
    return candidate as {
      isHovered?: () => boolean;
      popupIsOpen?: () => boolean;
      addOpenPopover?: (popover: Gtk.Popover) => void;
      removeOpenPopover?: (popover: Gtk.Popover) => void;
    } | null;
  };

  return (
    <box class="search-bar">
      <scrolledwindow vscrollbarPolicy={Gtk.PolicyType.EXTERNAL}>
        <box spacing={5}>
          <Gtk.TextView
            wrapMode={Gtk.WrapMode.WORD_CHAR}
            class="search-entry"
            hexpand
            $={(self) => {
              entryRef = self;

              // state -> widget (e.g. prefillLauncherInput from main.tsx,
              // or launcher clearing the query on launch)
              searchQuery.subscribe(() => {
                const next = searchQuery.get();
                if (self.buffer.text === next) return;
                settingFromState = true;
                self.buffer.text = next;
                const iter = self.buffer.get_end_iter();
                self.buffer.place_cursor(iter);
                settingFromState = false;
              });

              // widget -> state
              self.buffer.connect("changed", () => {
                if (settingFromState) return;
                setSearchQuery(self.buffer.text);
              });

              isExclusive.subscribe(applyKeymode);

              barState.subscribe(() => {
                if (!entryRef) return;
                const window = entryRef.get_root() as Gtk.Window | undefined;
                if (!window) return; // not registered yet — ignore the initial fire
                if (barState.get() === "search") {
                  setIsExclusive(true); // legacy mode always opens grabbed
                  applyKeymode();
                  showPopover();
                } else {
                  closePopover();
                  setSearchQuery("");
                  window.keymode = Astal.Keymode.NONE;
                }
              });
            }}
          >
            <Gtk.EventControllerKey
              onKeyPressed={(
                _,
                keyval: number,
                _keycode: number,
                state: number,
              ) => {
                if (keyval === Gdk.KEY_Escape) {
                  if (autoInput()) {
                    deactivateState("search");
                  } else {
                    setIsExclusive(!isExclusive.peek());
                  }
                  return true;
                }

                const isDown =
                  keyval === Gdk.KEY_Down || keyval === Gdk.KEY_Tab;
                const isUp =
                  keyval === Gdk.KEY_Up || keyval === Gdk.KEY_ISO_Left_Tab;
                if (isDown || isUp) {
                  setSearchNavigate({ direction: isDown ? 1 : -1 });
                  return true;
                }

                const isEnter =
                  keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter;
                if (!isEnter) return false;

                const isShiftPressed =
                  (state & Gdk.ModifierType.SHIFT_MASK) !== 0;
                if (isShiftPressed) return false; // Shift+Enter -> newline

                setSearchActivate(searchActivate.peek() + 1);
                return true; // swallow Enter so TextView doesn't insert \n
              }}
            />
          </Gtk.TextView>
          <With
            value={globalSettings(
              (s) => s.bar.searchAutoInput.value as boolean,
            )}
          >
            {(auto: boolean) =>
              auto ? (
                <button
                  class="search-icon"
                  label="ESC"
                  onClicked={() => {
                    deactivateState("search");
                  }}
                  tooltipMarkup="Close the launcher"
                />
              ) : (
                <togglebutton
                  class="search-icon"
                  label="ESC"
                  active={isExclusive}
                  onClicked={() => {
                    setIsExclusive(!isExclusive.peek());
                  }}
                  tooltipMarkup="Keyboard input mode (true focus) / mouse input mode."
                />
              )
            }
          </With>
        </box>
      </scrolledwindow>

      <Gtk.Popover
        autohide={false}
        hasArrow={false}
        marginTop={50}
        $={(self) => {
          popoverRef = self;
          if (entryRef) {
            self.set_parent(entryRef);
          }
          self.set_offset(0, 15); // x, y — this replaces marginTop
          self.connect("notify::visible", () => {
            const windowInstance = findBarWindow();
            if (self.visible) {
              self.add_css_class("popover-open");
              windowInstance?.addOpenPopover?.(self);
            } else {
              self.remove_css_class("popover-open");
              windowInstance?.removeOpenPopover?.(self);
            }
          });

          self.connect("closed", () => {
            const windowInstance = findBarWindow();
            if (barState.peek() !== "search") return; // only reset if search was active
            deactivateState("search");
            setSearchQuery("");

            if (
              !windowInstance?.isHovered?.() &&
              !windowInstance?.popupIsOpen?.()
            ) {
              deactivateState("expanded");
            }
          });
        }}
      >
        <AppLauncher onLaunched={closePopover} />
      </Gtk.Popover>
    </box>
  ) as Gtk.Widget;
};
