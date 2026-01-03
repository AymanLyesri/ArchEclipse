import { WidgetSelector } from "../interfaces/widgetSelector.interface";
import BooruViewer from "../widgets/leftPanel/components/BooruViewer";
import ChatBot from "../widgets/leftPanel/components/ChatBot";
import CustomScripts from "../widgets/leftPanel/components/CustomScripts";
import MediaWidget from "../widgets/MediaWidget";
import Waifu from "../widgets/rightPanel/components/Waifu";

import Workspaces from "../widgets/bar/components/Workspaces";
import Information from "../widgets/bar/components/Information";
import Utilities from "../widgets/bar/components/Utilities";
import ScriptTimer from "../widgets/rightPanel/components/ScriptTimer";
import Gtk from "gi://Gtk?version=4.0";
import { Accessor } from "ags";
import CryptoWidget from "../widgets/rightPanel/components/CryptoWidget";
import MangaViewer from "../widgets/leftPanel/components/MangaViewer";
import SettingsWidget from "../widgets/leftPanel/components/SettingsWidget";
import Calendar from "../widgets/rightPanel/components/Calendar";
import NotificationHistory from "../widgets/rightPanel/components/NotificationHistory";

export const barWidgetSelectors: WidgetSelector[] = [
  {
    name: "workspaces",
    icon: "󰒘",
    widget: (monitorName: string, halign: Gtk.Align) =>
      Workspaces({ monitorName, halign }),
    enabled: true,
  },
  {
    name: "information",
    icon: "󰒘",
    widget: (monitorName: string, halign: Gtk.Align) =>
      Information({ monitorName, halign }),
    enabled: true,
  },
  {
    name: "utilities",
    icon: "󰒘",
    widget: (monitorName: string, halign: Gtk.Align) =>
      Utilities({ monitorName, halign }),
    enabled: true,
  },
];

export const rightPanelWidgetSelectors: WidgetSelector[] = [
  {
    name: "Waifu",
    icon: "",
    widget: () => Waifu(),
    enabled: true,
  },
  {
    name: "Media",
    icon: "",
    widget: (rightPanelWidth?: number, rightPanelHeight?: number) =>
      MediaWidget({ width: rightPanelWidth, height: rightPanelHeight }),
    enabled: true,
  },
  {
    name: "NotificationHistory",
    icon: "",
    widget: () => NotificationHistory(),
    enabled: true,
  },
  {
    name: "ScriptTimer",
    icon: "󰀠",
    widget: () => ScriptTimer(),

    enabled: false,
  },
  {
    name: "Crypto",
    icon: "",
    widget: () => CryptoWidget(),
    enabled: false,
  },
  {
    name: "Calendar",
    icon: "󰃰",
    widget: () => Calendar(),
    enabled: true,
  },
];

export const leftPanelWidgetSelectors: WidgetSelector[] = [
  {
    name: "ChatBot",
    icon: "",
    widget: () => ChatBot(),
    enabled: true,
  },
  {
    name: "BooruViewer",
    icon: "",
    widget: () => BooruViewer(),
    enabled: false,
  },
  {
    name: "MangaViewer",
    icon: "",
    widget: () => MangaViewer(),
    enabled: false,
  },
  {
    name: "Settings",
    icon: "",
    widget: () => SettingsWidget(),
    enabled: false,
  },
  {
    name: "CustomScripts",
    icon: "",
    widget: () => CustomScripts(),
    enabled: false,
  },
];
