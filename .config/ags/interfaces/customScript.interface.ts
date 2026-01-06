import { Accessor } from "gnim";

export interface CustomScript {
  name: string | Accessor<string>;
  icon: string;
  description: string | Accessor<string>;
  keybind?: string[];
  sensitive?: boolean | Promise<boolean>;
  script: () => void;
}
