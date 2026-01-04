import Gdk from "gi://Gdk?version=4.0";

import Gio from "gi://Gio";

export function getConnectorFromHyprland(model: string) {
  const proc = Gio.Subprocess.new(
    ["hyprctl", "monitors", "-j"],
    Gio.SubprocessFlags.STDOUT_PIPE
  );

  const [, stdout] = proc.communicate_utf8(null, null);
  const monitors = JSON.parse(stdout);

  for (const m of monitors) {
    const desc = `${m.make ?? ""} ${m.model ?? ""} ${m.description ?? ""}`;
    if (desc.includes(model)) return m.name;
  }
}

export function getMonitorName(display: Gdk.Display, monitor: Gdk.Monitor) {
  // GTK4 provides get_connector() which returns the Wayland connector name directly
  const connector = monitor.get_connector();
  if (connector) return connector;

  // Fallback to the old method using model matching
  const model = monitor.get_model() || monitor.get_description();
  return getConnectorFromHyprland(model as any);
}
