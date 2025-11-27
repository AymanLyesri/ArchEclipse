declare module "ags" {
  export function createComputed<T>(
    fn: () => T
  ): (<U>(map?: (value: T) => U) => U) & T;
  export function createComputed<
    Deps extends Array<Accessor<any>>,
    Values extends { [K in keyof Deps]: Accessed<Deps[K]> }
  >(deps: Deps, transform: (...values: Values) => V): Accessor<V>;
  export function createState<T>(initial: T): [T, (value: T) => void];
  export function createBinding(
    obj: object,
    prop: string
  ): (<U>(map?: (value: any) => U) => U) & any;
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
