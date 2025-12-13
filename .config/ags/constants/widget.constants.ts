import { WidgetSelector } from "../interfaces/widgetSelector.interface";
import Calendar from "../widgets/Calendar";
import BooruViewer from "../widgets/leftPanel/components/BooruViewer";
import ChatBot from "../widgets/leftPanel/components/ChatBot";
import CustomScripts from "../widgets/leftPanel/components/CustomScripts";
import MediaWidget from "../widgets/MediaWidget";
import Waifu from "../widgets/rightPanel/components/Waifu";
import NotificationHistory from "../widgets/rightPanel/NotificationHistory";

import Workspaces from "../widgets/bar/components/Workspaces";
import Information from "../widgets/bar/components/Information";
import Utilities from "../widgets/bar/components/Utilities";
import ScriptTimer from "../widgets/rightPanel/components/ScriptTimer";
import Gtk from "gi://Gtk?version=4.0";
import { Accessor } from "ags";
import CryptoWidget from "../widgets/rightPanel/components/CryptoWidget";

export const barWidgetSelectors: WidgetSelector[] = [
  {
    name: "workspaces",
    icon: "󰒘",
    widget: (monitorName: string, halign: Accessor<Gtk.Align>) =>
      Workspaces({ monitorName, halign }),
  },
  {
    name: "information",
    icon: "󰒘",
    widget: (monitorName: string, halign: Accessor<Gtk.Align>) =>
      Information({ monitorName, halign }),
  },
  {
    name: "utilities",
    icon: "󰒘",
    widget: (monitorName: string, halign: Accessor<Gtk.Align>) =>
      Utilities({ monitorName, halign }),
  },
];

export const rightPanelWidgetSelectors: WidgetSelector[] = [
  {
    name: "Waifu",
    icon: "",
    widget: () => Waifu(),
  },
  {
    name: "Media",
    icon: "",
    widget: () => MediaWidget(),
  },
  {
    name: "NotificationHistory",
    icon: "",
    widget: () => NotificationHistory(),
  },
  // {
  //   name: "Calendar",
  //   icon: "",
  //   widget: () => Calendar(),
  // },
  {
    name: "ScriptTimer",
    icon: "󰀠",
    widget: () => ScriptTimer(),
  },
  // {
  //   name: "Resources",
  //   icon: "",
  //   widget: () => Resources(),
  // },
  {
    name: "Crypto",
    icon: "",
    widget: () => CryptoWidget(),
  },
];

export const leftPanelWidgetSelectors: WidgetSelector[] = [
  {
    name: "ChatBot",
    icon: "",
    widget: () => ChatBot(),
  },
  {
    name: "BooruViewer",
    icon: "",
    widget: () => BooruViewer(),
  },
  {
    name: "CustomScripts",
    icon: "",
    widget: () => CustomScripts(),
  },
];
