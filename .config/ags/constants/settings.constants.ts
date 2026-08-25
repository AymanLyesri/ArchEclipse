import {
  barWidgetSelectors,
  leftPanelWidgetSelectors,
  rightPanelWidgetSelectors,
} from "../constants/widget.constants";
import { booruApis, chatBotApis } from "../constants/api.constants";
import { BooruImage } from "../class/BooruImage.class";
import { dateFormats } from "../constants/date.constants";
import { phi, phi_min } from "../constants/phi.constants";
import { Settings } from "../interfaces/settings.interface";
import { Astal } from "ags/gtk4";

export const defaultSettings: Settings = {
  dateFormat: dateFormats[0],
  hyprsunset: {
    kelvin: 6500, // leave as is
  },
  hyprland: {
    general: {
      border_size: {
        name: "Border Size",
        value: 0,
        min: 0,
        max: 10,
        type: "int",
      },
      gaps_in: {
        name: "Gaps In",
        value: 7,
        min: 0,
        max: 20,
        type: "int",
      },
      gaps_out: {
        name: "Gaps Out",
        value: 10,
        min: 0,
        max: 40,
        type: "int",
      },
    },

    decoration: {
      rounding: {
        name: "Rounding",
        value: Math.round(phi * 10),
        min: 0,
        max: 50,
        type: "int",
      }, // already φ-based
      active_opacity: {
        name: "Active Opacity",
        value: 0.9,
        min: 0,
        max: 1,
        type: "float",
      }, // φ_min + small tweak
      inactive_opacity: {
        name: "Inactive Opacity",
        value: 0.8,
        min: 0,
        max: 1,
        type: "float",
      }, // φ_min - small tweak
      blur: {
        enabled: {
          name: "Blur Enabled",
          value: true,
          type: "bool",
          min: 0,
          max: 1,
        },
        size: {
          name: "Blur Size",
          value: 4,
          type: "int",
          min: 0,
          max: 10,
        }, // 3 → φ*2 ≈ 3
        passes: {
          name: "Blur Passes",
          value: 4,
          type: "int",
          min: 0,
          max: 10,
        },
        xray: { name: "Blur Xray", value: false, type: "bool", min: 0, max: 1 },
      },
      shadow: {
        enabled: {
          name: "Shadow Enabled",
          value: true,
          type: "bool",
          min: 0,
          max: 1,
        },
        range: {
          name: "Shadow Range",
          value: 15,
          type: "int",
          min: 0,
          max: 20,
        }, // 6 → φ*4 ≈ 6
        render_power: {
          name: "Shadow Render Power",
          value: 3,
          type: "int",
          min: 0,
          max: 20,
        },
      },
    },
  },
  notifications: {
    dnd: false,
  },
  ui: {
    opacity: {
      name: "Opacity",
      value: phi_min, // 0.618 instead of 0.5
      type: "float",
      min: 0,
      max: 1,
    },
    scale: {
      name: "Scale",
      value: Math.round(phi * 6), // 10 → φ*6 ≈ 9.7 → 10
      type: "int",
      min: 10,
      max: 30,
    },
    fontSize: {
      name: "Font Size",
      value: 12, // 12 → φ*7 ≈ 11.3 → 12
      type: "int",
      min: 10,
      max: 30,
    },
  },
  alwaysOnWidget: {
    visibility: {
      name: "Always On Widget Visibility",
      value: true,
      type: "bool",
      min: 0,
      max: 1,
    },
  },
  autoWorkspaceSwitching: {
    name: "Auto Workspace Switching",
    value: true,
    type: "bool",
    min: 0,
    max: 1,
  },
  dynamicThemeColors: {
    name: "Dynamic Theme Colors",
    value: true,
    type: "bool",
    min: 0,
    max: 1,
    tooltip: "Enable dynamic theme colors based on the current wallpaper",
  },
  dynamicThemeVariants: {
    name: "Dynamic Theme Variants",
    value: true,
    type: "bool",
    min: 0,
    max: 1,
    tooltip:
      "Enable dynamic theme variants (light/dark) based on the current wallpaper",
  },
  bar: {
    lock: {
      name: "Lock",
      value: true,
      type: "bool",
      min: 0,
      max: 1,
      tooltip:
        "Keep the bar always visible. When off, the bar auto-hides and hovering the screen edge reveals it",
    },
    smartHide: {
      name: "Smart Hide",
      value: false,
      type: "bool",
      min: 0,
      max: 1,
      tooltip:
        "When the bar is unlocked, show it while no window overlaps its area and hide it when one is in the way",
    },
    expanded: {
      name: "Always Expanded",
      value: false,
      type: "bool",
      min: 0,
      max: 1,
      tooltip: "Rest in the expanded layout instead of the compact pill",
    },
    fullWidth: {
      name: "Full Width",
      value: false,
      type: "bool",
      min: 0,
      max: 1,
      tooltip:
        "Stretch the bar across the whole monitor like the classic layout",
    },
    revealPressure: {
      name: "Reveal Pressure",
      value: 250,
      type: "int",
      min: 0,
      max: 1000,
      tooltip:
        "How hard the pointer must be pushed against the screen edge before an unlocked bar reveals (relative motion units, 0 = instant)",
    },
    orientation: {
      name: "Orientation",
      value: true,
      type: "bool",
      min: 0,
      max: 1,
    },
    workspaceNumbers: {
      name: "Workspace Numbers",
      value: false,
      type: "bool",
      min: 0,
      max: 1,
      tooltip: "Show a small workspace number next to each workspace icon",
    },

    layout: barWidgetSelectors,
  },
  waifuWidget: {
    input_history: "",
    visibility: true,
    current: new BooruImage(),
    api: booruApis[0],
  },
  rightPanel: {
    exclusivity: true,
    lock: false,
    width: 250,
    widgets: rightPanelWidgetSelectors,
    hotZone: {
      name: "Right Panel Hot Zone",
      value: true,
      type: "bool",
      min: 0,
      max: 1,
      tooltip:
        "Reveal the right panel by hovering the screen edge or bar corner",
    },
    hotZoneSize: {
      name: "Right Panel Hot Zone Size",
      value: 5,
      type: "int",
      min: 1,
      max: 50,
      tooltip: "Width in pixels of the right panel reveal area",
    },
  },
  leftPanel: {
    exclusivity: true,
    lock: false,
    width: 400,
    widget: leftPanelWidgetSelectors[0],
    hotZone: {
      name: "Left Panel Hot Zone",
      value: true,
      type: "bool",
      min: 0,
      max: 1,
      tooltip:
        "Reveal the left panel by hovering the screen edge or bar corner",
    },
    hotZoneSize: {
      name: "Left Panel Hot Zone Size",
      value: 5,
      type: "int",
      min: 1,
      max: 50,
      tooltip: "Width in pixels of the left panel reveal area",
    },
  },
  chatBot: {
    api: chatBotApis[0],
    imageGeneration: false,
  },
  booru: {
    api: booruApis[0],
    tags: [],
    limit: Math.round(20 * phi_min), // 20 → 20*0.618 ≈ 12
    page: 1,
    columns: 2,
    bookmarks: [],
    pins: [],
    selectedTab: booruApis[0].name,
  },
  crypto: {
    favorite: {
      symbol: "",
      timeframe: "",
    },
  },
  fileManager: "nautilus",
  keyStrokeVisualizer: {
    visibility: {
      name: "Key Stroke Visualizer Visibility",
      value: false,
      type: "bool",
      min: 0,
      max: 1,
    },
    anchor: {
      name: "Key Stroke Visualizer Anchor",
      value: ["bottom"],
      type: "select",
      min: 0,
      max: 0,
    },
  },
  wallpaperSwitcher: {
    category: "defaults/sfw",
  },
  // Wallpaper Engine renderer (kirie). Everything the engine accepts live is
  // sent over its control socket as it changes; the rest is handed to the next
  // engine launch by the wallpaper daemon, hence the "restart" tooltips.
  wallpaperEngine: {
    fps: {
      name: "Frame Rate",
      value: 30,
      type: "int",
      min: 1,
      max: 240,
      tooltip: "Frames per second the wallpaper is rendered at.",
    },
    batteryFps: {
      name: "Battery Frame Rate",
      value: 10,
      type: "int",
      min: 0,
      max: 240,
      tooltip:
        "Frame rate used while running on battery.\n0 keeps the normal frame rate.",
    },
    renderScale: {
      name: "Render Scale",
      value: 1,
      type: "float",
      min: 0.5,
      max: 2,
      tooltip:
        "Resolution the wallpaper renders at, relative to the screen.\nBelow 1 costs quality and saves GPU.",
    },
    playbackSpeed: {
      name: "Playback Speed",
      value: 1,
      type: "float",
      min: 0.1,
      max: 2,
      tooltip: "Animation speed (1 = normal, 0.5 = half, 2 = double).",
    },
    volume: {
      name: "Volume",
      value: 15,
      type: "int",
      min: 0,
      max: 128,
      tooltip: "Volume of wallpapers that carry sound.",
    },
    mute: {
      name: "Mute",
      value: false,
      type: "bool",
      min: 0,
      max: 0,
      tooltip: "Silence wallpaper audio without pausing the wallpaper.",
    },
    audioDevice: {
      name: "Audio Source",
      value: "",
      type: "select",
      min: 0,
      max: 0,
      tooltip:
        "Source the audio-reactive wallpapers listen to.\nEmpty follows the default output.",
    },
    noAutomute: {
      name: "Keep Sound With Other Audio",
      value: false,
      type: "bool",
      min: 0,
      max: 0,
      tooltip:
        "Keep wallpaper audio playing while something else is making sound.",
    },
    noAudioProcessing: {
      name: "Disable Audio Reactivity",
      value: false,
      type: "bool",
      min: 0,
      max: 0,
      tooltip:
        "Stop capturing system audio entirely.\nApplies when the engine restarts.",
    },
    scaling: {
      name: "Scaling",
      value: "default",
      type: "select",
      min: 0,
      max: 0,
      tooltip: "How the wallpaper is fitted to the screen.",
    },
    clamp: {
      name: "Edge Handling",
      value: "clamp",
      type: "select",
      min: 0,
      max: 0,
      tooltip: "What is drawn beyond the wallpaper's edges.",
    },
    layer: {
      name: "Layer",
      value: "bottom",
      type: "select",
      min: 0,
      max: 0,
      tooltip:
        "Which desktop layer the wallpaper is drawn on.\nApplies when the engine restarts.",
    },
    gpu: {
      name: "GPU",
      value: "auto",
      type: "select",
      min: 0,
      max: 0,
      tooltip:
        "Which GPU renders the wallpaper.\nApplies when the engine restarts.",
    },
    assetsDir: {
      name: "Assets Directory",
      value: "",
      type: "string",
      min: 0,
      max: 512,
      tooltip:
        "Wallpaper Engine's builtin assets folder.\nEmpty detects it automatically. Applies when the engine restarts.",
    },
    disableMouse: {
      name: "Disable Mouse Interaction",
      value: false,
      type: "bool",
      min: 0,
      max: 0,
      tooltip: "Stop wallpapers from reacting to the pointer.",
    },
    disableParallax: {
      name: "Disable Parallax",
      value: false,
      type: "bool",
      min: 0,
      max: 0,
      tooltip: "Stop the camera from following the pointer.",
    },
    disableParticles: {
      name: "Disable Particles",
      value: false,
      type: "bool",
      min: 0,
      max: 0,
      tooltip:
        "Skip particle systems, the most expensive part of many scenes.\nApplies when the engine restarts.",
    },
    noFullscreenPause: {
      name: "Keep Rendering Under Fullscreen",
      value: false,
      type: "bool",
      min: 0,
      max: 0,
      tooltip:
        "Keep the wallpaper running while a window is fullscreen.\nCosts GPU for something nobody can see.",
    },
    fullscreenPauseOnlyActive: {
      name: "Pause Only For The Active Window",
      value: false,
      type: "bool",
      min: 0,
      max: 0,
      tooltip:
        "Pause only when the fullscreen window is the focused one.\nApplies when the engine restarts.",
    },
  },
  apiKeys: {
    openrouter: {
      user: {
        name: "OpenRouter API User",
        value: "",
        type: "string",
        min: 1,
        max: 256,
      },
      key: {
        name: "OpenRouter API Key",
        value: "",
        type: "string",
        min: 1,
        max: 256,
      },
    },
    danbooru: {
      user: {
        name: "Danbooru API User",
        value: "publicapi",
        type: "string",
        min: 1,
        max: 256,
      },
      key: {
        name: "Danbooru API Key",
        value: "Pr5ddYN7P889AnM6nq2nhgw1",
        type: "string",
        min: 1,
        max: 256,
      },
    },
    gelbooru: {
      user: {
        name: "Gelbooru API User",
        value: "1667355",
        type: "string",
        min: 1,
        max: 256,
      },
      key: {
        name: "Gelbooru API Key",
        value:
          "1ccd9dd7c457c2317e79bd33f47a1138ef9545b9ba7471197f477534efd1dd05",
        type: "string",
        min: 1,
        max: 256,
      },
    },
    safebooru: {
      user: {
        name: "Safebooru API User",
        value: "publicapi",
        type: "string",
        min: 1,
        max: 256,
      },
      key: {
        name: "Safebooru API Key",
        value: "Pr5ddYN7P889AnM6nq2nhgw1",
        type: "string",
        min: 1,
        max: 256,
      },
    },
  },
  weather: {
    city: "",
    lat: null,
    lon: null,
  },
};
