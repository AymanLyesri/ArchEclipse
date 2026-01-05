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

export function getMonitorName(monitor: Gdk.Monitor) {
  // GTK4 provides get_connector() which returns Wayland connector name directly
  // This is more reliable than matching model strings against hyprctl output
  const connector = monitor.get_connector();
  if (connector) return connector;

  // Fallback to old method for compatibility with non-Wayland or older GTK
  const model = monitor.get_model() || monitor.get_description();
  return getConnectorFromHyprland(model as any);
}
