import App from "ags/gtk4/app";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import Astal from "gi://Astal?version=4.0";
import { getMonitorName } from "../utils/monitor";
import {
  globalMargin,
  screenShotVisibility,
  setScreenShotVisibility,
} from "../variables";
import { hideWindow } from "../utils/window";

import { createBinding, createComputed, createState } from "ags";
import { execAsync, exec } from "ags/process";
import { monitorFile } from "ags/file";
import GLib from "gi://GLib";
import { get } from "http";
import { notify } from "../utils/notification";
import { getImageRatio } from "../utils/image";

const getLatestScreenshotPath = () =>
  exec(`bash -c 'ls -t $HOME/Pictures/Screenshots | head -n 1'`);

const [screenShot, setScreenShot] = createState<string>(
  "./../../Pictures/Screenshots/" + getLatestScreenshotPath().trim()
);

print("screenshot updated: " + screenShot);

//screen shoter widget
const actions = (monitorName: String) => {
  return (
    <box class="actions" spacing={10} vertical={true}>
      <box
        class="image"
        css={createComputed(
          () =>
            `background-image: url("${screenShot}");
              background-size: contain;
        background-repeat: no-repeat;
        background-position: center;
        border-radius: 10px;
        min-width: 100px;
        min-height: ${getImageRatio(screenShot) * 100}px;`
        )}
      />
      <button
        class="action"
        child={<label label={"Open"} />}
        onClicked={() => {
          execAsync(`xdg-open ${screenShot}`).catch((err) =>
            notify({ summary: "Error", body: String(err) })
          );
          hideWindow("screenshot-" + monitorName);
        }}
      />
      <button
        class="action"
        child={<label label={"Edit"} />}
        onClicked={() => {
          execAsync(`gimp ${screenShot}`).catch((err) =>
            notify({
              summary: "Error Or Gimp is not Installed",
              body: String(err),
            })
          );
          hideWindow("screenshot-" + monitorName);
        }}
      />
    </box>
  );
};

export default (monitor: Gdk.Monitor) => {
  const monitorName = getMonitorName(monitor.get_display(), monitor)!;
  return (
    <window
      gdkmonitor={monitor}
      namespace="screenshot"
      name={`screenshot-${monitorName}`}
      application={App}
      anchor={Astal.WindowAnchor.LEFT}
      layer={Astal.Layer.OVERLAY}
      margin={globalMargin}
      visible={createComputed(() => screenShotVisibility)}
      child={
        <box
          class="screenshot-popup"
          child={
            <Eventbox
              class={"screenshot-Eventbox"}
              onHoverLost={() => setScreenShotVisibility(false)}
              child={
                <box class="screenshot-widget" child={actions(monitorName)} />
              }
            />
          }
        />
      }
    />
  );
};

monitorFile(`./../../Pictures/Screenshots`, () => {
  GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
    setScreenShot(
      "./../../Pictures/Screenshots/" + getLatestScreenshotPath.trim()
    );
    return false;
  });
  setScreenShotVisibility(true);
});
