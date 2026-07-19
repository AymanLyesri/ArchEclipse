import { Accessor, createState } from "ags";
import { Astal, Gdk, Gtk } from "ags/gtk4";
import { barState, deactivateState } from "../Bar";
import { timeout } from "ags/time";
import AppLauncher from "../../applauncher/AppLauncher";

export const [searchQuery, setSearchQuery] = createState<string>("");

export const [searchActivate, setSearchActivate] = createState<number>(0);

export default ({ widthRequest }: { widthRequest?: Accessor<number> }) => {
  let entryRef: Gtk.TextView | null = null;
  let popoverRef: Gtk.Popover | null = null;
  let settingFromState = false; // guards buffer<->state feedback loop

  const [isExclusive, setIsExclusive] = createState<boolean>(true);

  isExclusive.subscribe(() => {
    const window = entryRef?.get_root() as Gtk.Window | undefined;
    if (!window) return; // not registered yet — ignore the initial fire
    window.keymode = isExclusive.get()
      ? Astal.Keymode.EXCLUSIVE
      : Astal.Keymode.ON_DEMAND;
  });

  const closePopover = () => {
    popoverRef?.popdown();
  };

  return (
    <box class="search-bar">
      <scrolledwindow vscrollbarPolicy={Gtk.PolicyType.EXTERNAL}>
        <box spacing={5}>
          <Gtk.TextView
            wrapMode={Gtk.WrapMode.WORD_CHAR}
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

              barState.subscribe(() => {
                if (!entryRef) return;
                const window = entryRef.get_root() as Gtk.Window | undefined;
                if (!window) return; // not registered yet — ignore the initial fire
                window.keymode = Astal.Keymode.EXCLUSIVE;
                if (barState.get() === "search") {
                  timeout(50, () => {
                    popoverRef?.popup();
                    entryRef?.grab_focus();
                  });
                } else {
                  popoverRef?.popdown();
                  setSearchQuery("");
                  setIsExclusive(true);
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
                  setIsExclusive(isExclusive.peek() ? false : true);

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
          <togglebutton
            class="search-icon"
            label="ESC"
            active={isExclusive}
            onClicked={() => {
              setIsExclusive(isExclusive.peek() ? false : true);
            }}
            tooltipMarkup="Keyboard input mode (true focus) / mouse input mode."
          />
        </box>
      </scrolledwindow>

      <Gtk.Popover
        autohide={false}
        hasArrow={false}
        marginTop={50}
        $={(self) => {
          popoverRef = self;
          self.set_parent(entryRef!);
          self.set_offset(0, 15); // x, y — this replaces marginTop
          self.connect("notify::visible", () => {
            if (self.visible) {
              self.add_css_class("popover-open");
            } else {
              self.remove_css_class("popover-open");
            }
          });

          self.connect("closed", () => {
            if (barState.peek() !== "search") return; // only reset if search was active
            deactivateState("search");
            setSearchQuery("");
            setIsExclusive(true);
          });
        }}
      >
        <AppLauncher
          onLaunched={closePopover}
          minimal={isExclusive((is) => !is)}
        />
      </Gtk.Popover>
    </box>
  ) as Gtk.Widget;
};
