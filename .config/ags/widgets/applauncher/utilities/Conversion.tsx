import { execAsync } from "ags/process";

import { LauncherApp } from "../../../interfaces/app.interface";
import { convert, isConversionQuery } from "../../../utils/convert";

export { isConversionQuery };

export const getConversionResults = async (
  value: string,
): Promise<LauncherApp[]> => {
  const conversions = await convert(value);

  return conversions.map((conv) => ({
    app_name: `${conv.formatted}`,
    app_icon: "󰟛",
    app_description: `Converted from ${conv.original}`,
    app_launch: () => execAsync(["wl-copy", conv.formatted]),
  }));
};
