export const workspaceRegexIconMap: Array<{ pattern: RegExp; icon: string }> = [
  {
    // Match any class that ends with "cord" to catch Discord, Legcord, Vencord, Vesktop, etc.
    pattern: /cord$/,
    icon: "󰙯",
  },
  {
    // Match common terminal classes
    pattern: /foot|kitty|alacritty|xterm|gnome-terminal|konsole/i,
    icon: "",
  },
  {
    // Match common file manager classes
    pattern: /thunar|nautilus|dolphin|ranger/i,
    icon: "󰉋",
  },
  {
    // Match common chrome-based browser classes
    pattern: /chrome|chromium|brave/i,
    icon: "",
  },
  {
    // Match Firefox
    pattern: /firefox|zen/i,
    icon: "󰈹",
  },
  {
    // Match VLC
    pattern: /vlc/i,
    icon: "󰕼",
  },
  {
    // Match Spotify clients, also include any class that contains "spotify" or "spotube" to catch various Spotify clients
    pattern: /spotify|spotube/i,
    icon: "",
  },
  {
    // Match common code editor classes
    pattern: /code|vscode|sublime|jetbrains/i,
    icon: "",
  },
  {
    // Match Steam
    pattern: /steam/i,
    icon: "",
  },
  {
    // Match game clients, also include any class that end with ".exe" to catch Windows games running through Proton
    pattern: /lutris|game|\.exe$/i,
    icon: "",
  },
  {
    // Match telegram
    pattern: /telegram/i,
    icon: "",
  },
];
