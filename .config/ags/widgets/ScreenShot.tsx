import { App, Astal, Gdk } from "astal/gtk3";
import { getMonitorName } from "../utils/monitor";
import { globalMargin, screenShotVisibility } from "../variables";
import { hideWindow } from "../utils/window";
import {
  bind,
  exec,
  execAsync,
  GLib,
  monitorFile,
  timeout,
  Variable,
} from "astal";
import { get } from "http";
import { notify } from "../utils/notification";
import { getImageRatio } from "../utils/image";

const getLatestScreenshotPath = () =>
  exec(`bash -c 'ls -t $HOME/Pictures/Screenshots | head -n 1'`);

const screenShot = Variable<string>(
  "./../../Pictures/Screenshots/" + getLatestScreenshotPath().trim()
);

print("screenshot updated: " + screenShot.get());

//screen shoter widget
const actions = (monitorName: String) => {
  return (
    <box className="actions" spacing={10} vertical={true}>
      <box
        className="image"
        css={bind(screenShot).as(
          (path) =>
            `background-image: url("${path}");
              background-size: contain;
        background-repeat: no-repeat;
        background-position: center;
        border-radius: 10px;
        min-width: 100px;
        min-height: ${getImageRatio(screenShot.get()) * 100}px;`
        )}
      />
      <button
        className="action"
        child={<label label={"Open"} />}
        onClicked={() => {
          execAsync(`xdg-open ${screenShot.get()}`).catch((err) =>
            notify({ summary: "Error", body: String(err) })
          );
          hideWindow("screenshot-" + monitorName);
        }}
      />
      <button
        className="action"
        child={<label label={"Edit"} />}
        onClicked={() => {
          execAsync(`gimp ${screenShot.get()}`).catch((err) =>
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
      visible={bind(screenShotVisibility)}
      child={
        <box
          className="screenshot-popup"
          child={
            <eventbox
              className={"screenshot-eventbox"}
              onHoverLost={() => screenShotVisibility.set(false)}
              child={
                <box
                  className="screenshot-widget"
                  child={actions(monitorName)}
                />
              }
            />
          }
        />
      }
    />
  );
};

monitorFile(`./../../Pictures/Screenshots`, () => {
  timeout(500, () => {
    screenShot.set(
      "./../../Pictures/Screenshots/" + getLatestScreenshotPath().trim()
    );
  });
  screenShotVisibility.set(true);
});
