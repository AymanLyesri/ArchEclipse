export interface CustomScript {
  name: string;
  icon: string;
  description: string;
  keybind?: string[];
  sensitive?: boolean | Promise<boolean>;
  script: () => void;
}
