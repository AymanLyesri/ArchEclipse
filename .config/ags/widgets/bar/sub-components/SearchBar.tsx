import { Accessor, createState } from "ags";
import { Astal, Gdk, Gtk } from "ags/gtk4";
import { activeSearchMonitor, barState, deactivateState } from "../Bar";
import { timeout } from "ags/time";
import AppLauncher from "../../applauncher/AppLauncher";

export const [searchQuery, setSearchQuery] = createState<string>("");

export const [searchActivate, setSearchActivate] = createState<number>(0);

export default ({
  widthRequest,
  monitor,
}: {
  widthRequest?: Accessor<number>;
  monitor?: string;
}) => {
  let entryRef: Gtk.TextView | null = null;
  let popoverRef: Gtk.Popover | null = null;
  let settingFromState = false; // guards buffer<->state feedback loop

  // barState/activeSearchMonitor are module-level singletons shared by
  // every monitor's SearchBar instance — without this check every
  // instance pops its own popover open the moment ANY monitor's search
  // activates, not just the target one.
  const isTargetMonitor = () => {
    const target = activeSearchMonitor.peek();
    return !target || !monitor || target === monitor;
  };

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

              const syncPopoverVisibility = () => {
                if (!entryRef) return;
                const window = entryRef.get_root() as Gtk.Window | undefined;
                if (!window) return; // not registered yet — ignore the initial fire

                if (barState.get() !== "search") {
                  popoverRef?.popdown();
                  setSearchQuery("");
                  window.keymode = Astal.Keymode.NONE;
                  return;
                }

                if (!isTargetMonitor()) {
                  // search is active, but for a different monitor — stay hidden
                  // without touching the shared query/exclusive state.
                  popoverRef?.popdown();
                  window.keymode = Astal.Keymode.NONE;
                  return;
                }

                window.keymode = Astal.Keymode.ON_DEMAND;
                timeout(50, () => {
                  popoverRef?.popup();
                  entryRef?.grab_focus();
                });
              };

              barState.subscribe(syncPopoverVisibility);
              activeSearchMonitor.subscribe(syncPopoverVisibility);
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
                  deactivateState("search");
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
            if (!isTargetMonitor()) return; // not this monitor's close — just us hiding
            deactivateState("search");
            setSearchQuery("");
          });

          // ON_DEMAND keymode (needed so clicks reach the popover at all)
          // lets GTK's normal focus-follows-click move keyboard focus away
          // from the entry whenever something inside is clicked — steal it
          // back afterwards so typing keeps working without an extra click.
          // CAPTURE phase so this fires even when a child (e.g. a button)
          // claims the click sequence for itself.
          const refocusEntry = new Gtk.GestureClick();
          refocusEntry.set_propagation_phase(Gtk.PropagationPhase.CAPTURE);
          refocusEntry.connect("pressed", () => {
            timeout(100, () => entryRef?.grab_focus());
          });
          self.add_controller(refocusEntry);
        }}
      >
        <AppLauncher onLaunched={closePopover} />
      </Gtk.Popover>
    </box>
  ) as Gtk.Widget;
};
