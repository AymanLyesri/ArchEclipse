export interface LauncherAppAction {
  label: string;
  onClick: () => void;
  className?: string;
  tooltip?: string;
}

export interface LauncherApp {
  app_name: string;
  app_description?: string;
  app_arg?: string;
  app_type?: string;
  app_icon?: string;
  app_actions?: LauncherAppAction[];
  app_close_on_launch?: boolean;
  app_launch: (arg?: any) => void;
}
