import GLib from "gi://GLib?version=2.0";
import GObject from "gnim/gobject";

export function time(time: number, format = "%H:%M") {
  return GLib.DateTime.new_from_unix_local(time).format(format)!;
}

export function asyncSleep(INTERVAL: number) {
  return new Promise((resolve) => setTimeout(resolve, INTERVAL));
}

export function logTime(label: string, fn: () => void) {
  const start = GLib.get_monotonic_time();
  fn(); // Ensure async execution
  const end = GLib.get_monotonic_time();
  const duration = (end - start) / 1000;

  // Color coding remains the same
  const colors = {
    fast: "\x1b[32m",
    medium: "\x1b[33m",
    slow: "\x1b[31m",
  };
  const color =
    duration > 100 ? colors.slow : duration > 10 ? colors.medium : colors.fast;

  print(`${label}: ${color}${duration} ms\x1b[0m`);
}

export function logTimeWidget(label: string, fn: () => GObject.Object) {
  const start = GLib.get_monotonic_time();
  const widgetInstance = fn();
  const end = GLib.get_monotonic_time();
  const duration = (end - start) / 1000;

  // Color coding remains the same
  const colors = {
    fast: "\x1b[32m",
    medium: "\x1b[33m",
    slow: "\x1b[31m",
  };
  const color =
    duration > 100 ? colors.slow : duration > 10 ? colors.medium : colors.fast;

  print(`${label}: ${color}${duration} ms\x1b[0m`);
  return widgetInstance;
}
