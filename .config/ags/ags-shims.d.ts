declare module "ags" {
  export interface Accessor<T> {
    (): T;
    get(): T;
    <U>(map: (value: T) => U): U;
  }

  export interface Setter<T> {
    (value: T | ((prev: T) => T)): void;
  }

  export function createComputed<T>(fn: () => T): Accessor<T>;
  export function createComputed<
    Deps extends Array<Accessor<any>>,
    Values extends { [K in keyof Deps]: Accessed<Deps[K]> }
  >(deps: Deps, transform: (...values: Values) => V): Accessor<V>;
  export function createState<T>(initial: T): [Accessor<T>, Setter<T>];
  export function createBinding<T>(obj: object, prop: string): Accessor<T>;
}

declare module "ags/gtk3/app" {
  interface AGSWindow {
    hide(): void;
    show(): void;
  }
  const app: {
    get_window(name: string): AGSWindow | undefined;
  };
  export default app;
}

declare module "gi://Gtk?version=3.0" {
  const Gtk: any;
  export default Gtk;
}

declare module "gi://Gdk?version=3.0" {
  const Gdk: any;
  export default Gdk;
}

declare module "gi://Astal?version=3.0" {
  const Astal: any;
  export default Astal;
}

declare module "gi://AstalApps" {
  const Apps: any;
  export default Apps;
}

declare module "gi://AstalHyprland" {
  const Hyprland: any;
  export default Hyprland;
}

declare module "gi://GLib" {
  const GLib: any;
  export default GLib;
}
