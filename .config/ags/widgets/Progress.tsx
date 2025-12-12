import { createState, createComputed } from "ags";
import App from "ags/gtk4/app";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { asyncSleep } from "../utils/time";

const INTERVAL = 10;
const INCREMENT = 0.069;

const [progressIncrement, setProgressIncrement] = createState(INCREMENT);
const [progressValue, setProgressValue] = createState(0);

const levelBar = (
  <levelbar
    class="progress-bar"
    max_value={100}
    widthRequest={333}
    value={progressValue}
  />
);

async function RunningProgress() {
  setProgressValue(0);
  setProgressIncrement(INCREMENT);

  while (progressValue.get() <= 100) {
    setProgressValue(progressValue.get() + progressIncrement.get());
    await asyncSleep(INTERVAL); // Wait for 2 seconds before continuing
  }
  App.toggle_window("progress");
}

export function openProgress() {
  App.toggle_window("progress");
  RunningProgress();
}

export function closeProgress() {
  setProgressIncrement(1); // Speed up the progress bar
}

// const Spinner = <spinner />;

export default (monitor: Gdk.Monitor) => (
  <window
    gdkmonitor={monitor}
    name="progress"
    application={App}
    anchor={Astal.WindowAnchor.BOTTOM}
    margin={0}
    visible={false}
  >
    <box class="progress-widget">{levelBar}</box>
  </window>
);
