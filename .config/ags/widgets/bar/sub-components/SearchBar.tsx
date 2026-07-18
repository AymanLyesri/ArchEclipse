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

  const closePopover = () => {
    popoverRef?.popdown();
  };

  return (
    <box class="search-bar">
      <scrolledwindow vscrollbarPolicy={Gtk.PolicyType.EXTERNAL}>
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
              if (barState.get() === "search") {
                window.keymode = Astal.Keymode.EXCLUSIVE; // set BEFORE popup
                timeout(50, () => {
                  popoverRef?.popup();
                  entryRef?.grab_focus();
                });
              } else {
                popoverRef?.popdown();
                window.keymode = Astal.Keymode.ON_DEMAND;
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
                closePopover();
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
          });
        }}
      >
        <AppLauncher onLaunched={closePopover} />
      </Gtk.Popover>
    </box>
  ) as Gtk.Widget;
};
