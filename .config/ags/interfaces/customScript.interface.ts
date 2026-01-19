import { Accessor } from "gnim";

export interface CustomScript {
  name: string | Accessor<string>;
  icon: string;
  description: string;
  keybind?: string[];
  app?: string;
  package?: string;
  script: () => void;
}
