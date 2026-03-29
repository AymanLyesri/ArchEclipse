import { execAsync } from "ags/process";

import { LauncherApp } from "../../../interfaces/app.interface";
import { arithmetic, containsOperator } from "../../../utils/arithmetic";

export const isArithmeticQuery = (value: string): boolean => {
  const firstToken = value.trim().split(/\s+/)[0] || "";
  return containsOperator(firstToken);
};

export const getArithmeticResults = (value: string): LauncherApp[] => {
  const output = arithmetic(value);

  return [
    {
      app_name: output,
      app_launch: () => execAsync(["wl-copy", output]),
    },
  ];
};
