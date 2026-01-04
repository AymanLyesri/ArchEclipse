export interface LauncherApp {
  app_name: string;
  app_description?: string;
  app_arg?: string;
  app_type?: string;
  app_icon?: string;
  app_launch: () => void;
}
