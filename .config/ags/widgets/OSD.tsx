import { Astal, Gdk, Gtk } from "astal/gtk3";
import Brightness from "../services/brightness";
const brightness = Brightness.get_default();
import Wp from "gi://AstalWp";
import { globalMargin } from "../variables";
import { bind, Connectable } from "astal/binding";
import { Variable } from "astal";

const audio = Wp.get_default()?.audio!;

const DELAY = 2000;

// Debounce function to avoid multiple rapid calls
const debounce = (func: () => void, delay: number) => {
  let timer: any;
  return () => {
    clearTimeout(timer);
    timer = setTimeout(func, delay);
  };
};

// Function to map value to icon
const getIcon = (value: number, icons: string[]) => {
  if (value > 0.75) return icons[0];
  if (value > 0.5) return icons[1];
  if (value > 0.25) return icons[2];
  return icons[3];
};

const osdSlider = (
  connectable: Connectable,
  signal: string,
  setValue: (value: number) => void,
  icons: string[]
) => {
  let sliderLock = Variable<boolean>(false);

  const indicator = (
    <label label={bind(connectable, signal).as((v) => getIcon(v, icons))} />
  );

  const slider = (
    <slider
      vertical={true}
      inverted={true}
      className="slider"
      draw_value={false}
      height_request={100}
      value={bind(connectable, signal)}
      onDragged={({ value }) => setValue(value)}
    />
  );

  const revealer = (
    <revealer
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      revealChild={false}
      setup={(self) => {
        const debouncedHide = debounce(() => {
          if (!sliderLock.get()) self.reveal_child = false;
        }, DELAY);
        self.hook(connectable, `notify::${signal}`, () => {
          self.reveal_child = true;
          debouncedHide();
        });
      }}
      child={
        <box className={"container"} vertical={true}>
          {slider}
          {indicator}
        </box>
      }
    />
  );

  const eventbox = (
    <eventbox
      onHover={() => sliderLock.set(true)}
      onHoverLost={() => {
        sliderLock.set(false);
        revealer.reveal_child = false;
      }}
      child={revealer}
    />
  );
  return eventbox;
};

function OnScreenProgress(vertical: boolean) {
  const volumeIcons = ["", "", "", ""];
  const brightnessIcons = ["󰃠", "󰃟", "󰃞", "󰃞"];

  const VolumeSlider = osdSlider(
    audio.defaultSpeaker,
    "volume",
    (value) => (audio.defaultSpeaker.volume = value),
    volumeIcons
  );

  const MicrophoneSlider = osdSlider(
    audio.defaultMicrophone,
    "volume",
    (value) => (audio.defaultMicrophone.volume = value),
    volumeIcons
  );

  const BrightnessSlider = osdSlider(
    brightness,
    "screen",
    (value) => (brightness.screen = value),
    brightnessIcons
  );

  return (
    <box>
      {VolumeSlider}
      {MicrophoneSlider}
      {BrightnessSlider}
    </box>
  );
}

export default (monitor: Gdk.Monitor) => (
  <window
    gdkmonitor={monitor}
    name="osd"
    namespace="osd"
    className="osd"
    layer={Astal.Layer.OVERLAY}
    margin={globalMargin}
    anchor={Astal.WindowAnchor.RIGHT}
    child={OnScreenProgress(true)}
  />
);
