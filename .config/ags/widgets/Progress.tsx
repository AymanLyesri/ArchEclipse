import { createState, createComputed } from "ags";
import App from "ags/gtk3/app";
import Gdk from "gi://Gdk?version=3.0";
import Astal from "gi://Astal?version=3.0";
import { asyncSleep } from "../utils/time";

const INTERVAL = 10;
const INCREMENT = 0.069;

const [getProgressIncrement, setProgressIncrement] = createState(INCREMENT);
const [getProgressValue, setProgressValue] = createState(0);

const levelBar = (
  <levelbar
    class="progress-bar"
    max_value={100}
    widthRequest={333}
    value={createComputed(() => getProgressValue)}
  />
);

async function RunningProgress() {
  setProgressValue(0);
  setProgressIncrement(INCREMENT);

  while (getProgressValue <= 100) {
    setProgressValue(getProgressValue + getProgressIncrement);
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
    child={<box class="progress-widget" child={levelBar}></box>}
  ></window>
);
