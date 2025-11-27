import Gdk from "gi://Gdk?version=3.0";

export function getMonitorName(display: Gdk.Display, gdkmonitor: Gdk.Monitor) {
  const screen = display.get_default_screen();
  for (let i = 0; i < display.get_n_monitors(); ++i) {
    if (gdkmonitor === display.get_monitor(i))
      return screen.get_monitor_plug_name(i);
  }
}
