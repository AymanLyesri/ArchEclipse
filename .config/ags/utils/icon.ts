import Astal from "gi://Astal?version=4.0";

export function playerToIcon(name: string) {
  let icons: {
    [key: string]: string;
  } = {
    spotify: "󰓇",
    VLC: "󰓈",
    YouTube: "󰓉",
    Brave: "",
    Audacious: "󰓋",
    Rhythmbox: "󰓌",
    Chromium: "",
    Firefox: "󰈹",
    firefox: "󰈹",
  };
  return icons[name] || "";
}

export const lookupIcon = (name: string) => {
  let result = image.lookup_icon(name)
    ? image.lookup_icon(name)
    : "audio-x-generic-symbolic";
  return result;
};
