import { createBinding } from "ags";
import Wp from "gi://AstalWp";
import { globalTransition } from "../../../../variables";
import { Gtk } from "ags/gtk4";
import { execAsync } from "ags/process";
import { notify } from "../../../../utils/notification";

export default () => {
  const speaker = Wp.get_default()?.audio.defaultSpeaker!;
  const volumeIcon = createBinding(speaker, "volumeIcon");
  const volume = createBinding(speaker, "volume");

  const icon = <image pixelSize={11} iconName={volumeIcon} />;

  const slider = (
    <slider
      // step={0.1} // Gtk.Scale doesn't have step prop directly in JSX usually, handled by adjustment or set_increment
      class="slider"
      widthRequest={100}
      onValueChanged={(self) => {
        // external volume changes (fn keys, pavucontrol) also fire this and loop back
        if (Math.abs(self.get_value() - speaker.volume) < 0.001) return;
        speaker.volume = self.get_value();
      }}
      value={volume((v: number) => (isNaN(v) || v < 0 ? 0 : v > 1 ? 1 : v))}
    />
  );

  const percentage = (
    <label label={volume((v: number) => `${Math.round(v * 100)}%`)} />
  );

  const trigger = (
    <box class="trigger" spacing={5} children={[icon, percentage]} />
  );

  let hideTimeout: any = null;
  let isHovering = false;
  let lastVolume = speaker.volume;
  let firstRender = true;

  const revealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SWING_LEFT}
      $={(self) => {
        speaker.connect(`notify::volume`, () => {
          const currentVolume = speaker.volume;

          // Skip the initial notification on component mount
          if (firstRender) {
            firstRender = false;
            lastVolume = currentVolume;
            return;
          }

          // Ignore spurious notifications where value did not change
          if (currentVolume === lastVolume) {
            return;
          }

          lastVolume = currentVolume;
          self.reveal_child = true;

          if (hideTimeout) {
            clearTimeout(hideTimeout);
          }

          // Set new timeout to hide after 2 seconds of no volume changes
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
      tooltipText={volume(
        (v) => `Volume: ${Math.round(v * 100)}%\nClick to open Volume Mixer`,
      )}
      class={"custom-revealer"}
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
      <Gtk.GestureClick
        onPressed={() => {
          execAsync(`pavucontrol`).catch((err) =>
            notify({ summary: "pavu", body: err }),
          );
        }}
      />
      <box class={"content"}>
        {trigger}
        {revealer}
      </box>
    </box>
  );
};
