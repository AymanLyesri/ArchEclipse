import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import Brightness from "../services/brightness";
const brightness = Brightness.get_default();
import Wp from "gi://AstalWp";
import { globalMargin } from "../variables";
import { createBinding, createState, createComputed } from "ags";

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
  connectable: any,
  signal: string,
  setValue: (value: number) => void,
  icons: string[]
) => {
  const [sliderLock, setSliderLock] = createState<boolean>(false);
  const value = createBinding(connectable, signal);

  const indicator = (
    <label
      class={"icon"}
      label={createComputed(() => getIcon(value(), icons))}
    />
  );

  const slider = (
    <slider
      orientation={Gtk.Orientation.VERTICAL}
      inverted={true}
      class="slider"
      drawValue={false}
      heightRequest={100}
      value={createComputed(() => value())}
      onValueChanged={(self) => setValue(self.get_value())}
    />
  );

  const revealer = (
    <revealer
      transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
      revealChild={false}
      setup={(self) => {
        const debouncedHide = debounce(() => {
          if (!sliderLock()) self.reveal_child = false;
        }, DELAY);
        // Assuming connectable is a GObject, we can use connect
        connectable.connect(`notify::${signal}`, () => {
          self.reveal_child = true;
          debouncedHide();
        });
      }}
      child={
        <box class={"container"} orientation={Gtk.Orientation.VERTICAL}>
          {slider}
          {indicator}
        </box>
      }
    />
  );

  const Eventbox = (
    <Eventbox
      onHover={() => setSliderLock(true)}
      onHoverLost={() => {
        setSliderLock(false);
        revealer.reveal_child = false;
      }}
      child={revealer}
    />
  );
  return Eventbox;
};

function OnScreenProgress(orientation={Gtk.Orientation.VERTICAL}: boolean) {
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

export default ({ monitor }: { monitor: Gdk.Monitor }) => (
  <window
    gdkmonitor={monitor}
    name="osd"
    namespace="osd"
    class="osd"
    layer={Astal.Layer.OVERLAY}
    margin={globalMargin}
    anchor={Astal.WindowAnchor.RIGHT}
    child={OnScreenProgress(true)}
  />
);
