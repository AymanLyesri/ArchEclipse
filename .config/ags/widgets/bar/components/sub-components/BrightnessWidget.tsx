import { Gtk } from "ags/gtk4";
import { globalTransition } from "../../../../variables";
import { Accessor, createBinding } from "ags";
import Brightness from "../../../../services/brightness";

export default ({ widthRequest }: { widthRequest?: Accessor<number> }) => {
  const brightness = Brightness.get_default();
  const screen = createBinding(brightness, "screen");

  const label = (
    <label
      label={screen((v) => {
        switch (true) {
          case v > 0.75:
            return "󰃠";
          case v > 0.5:
            return "󰃟";
          case v > 0:
            return "󰃞";
          default:
            return "󰃞";
        }
      })}
    />
  );

  const percentage = (
    <label label={screen((v: number) => `${Math.round(v * 100)}%`)} />
  );

  const slider = (
    <slider
      hexpand
      widthRequest={100}
      class="slider"
      drawValue={false}
      onValueChanged={({ value }) => {
        if (value == screen.peek()) return;
        brightness.screen = value;
      }}
      value={screen}
    />
  );

  const trigger = (
    <box class="trigger" spacing={5} children={[label, percentage]} />
  );

  let hideTimeout: any = null;
  let isHovering = false;
  let lastScreen = brightness.screen;
  let firstRender = true;

  const revealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SWING_LEFT}
      $={(self) => {
        brightness.connect(`notify::screen`, () => {
          const currentScreen = brightness.screen;

          // Skip the initial notification on component mount
          if (firstRender) {
            firstRender = false;
            lastScreen = currentScreen;
            return;
          }

          // Ignore spurious notifications where value did not change
          if (currentScreen === lastScreen) {
            return;
          }

          lastScreen = currentScreen;
          self.reveal_child = true;

          if (hideTimeout) {
            clearTimeout(hideTimeout);
          }

          // Set new timeout to hide after 2 seconds of no brightness changes
          hideTimeout = setTimeout(() => {
            if (!isHovering) {
              self.reveal_child = false;
            }
          }, 2000);
        });
      }}
    >
      {slider}
    </revealer>
  );

  return (
    <box
      tooltipText={screen((v) => `Brightness: ${Math.round(v * 100)}%`)}
      class={"custom-revealer"}
      visible={createBinding(brightness, "hasBacklight")}
      widthRequest={widthRequest}
    >
      <Gtk.EventControllerMotion
        onEnter={() => {
          isHovering = true;
          if (hideTimeout) {
            clearTimeout(hideTimeout);
          }
          (revealer as Gtk.Revealer).reveal_child = true;
        }}
        onLeave={() => {
          isHovering = false;
          if (hideTimeout) {
            clearTimeout(hideTimeout);
          }
          hideTimeout = setTimeout(() => {
            (revealer as Gtk.Revealer).reveal_child = false;
          }, 2000);
        }}
      ></Gtk.EventControllerMotion>
      <box class={"content"}>
        {trigger}
        {revealer}
      </box>
    </box>
  ) as Gtk.Widget;
};
