import { Gtk } from "ags/gtk4";
import { globalSettings } from "../../../variables";
import { WidgetSelector } from "../../../interfaces/widgetSelector.interface";
import Workspaces from "../components/Workspaces";
import Information from "../components/Information";
import Utilities from "../components/Utilities";

const layout = globalSettings.peek().bar.layout;

export default () =>
  (
    <centerbox hexpand>
      {layout
        .filter((widget) => widget.enabled)
        .map((widget: WidgetSelector, key) => {
          switch (widget.name) {
            case "workspaces":
              return (
                <box $type="start">
                  <Workspaces />
                </box>
              );
            case "information":
              return (
                <box $type="center">
                  <Information />
                </box>
              );
            case "utilities":
              return (
                <box $type="end">
                  <Utilities />
                </box>
              );
            default:
              return <box />;
          }
        })}
    </centerbox>
  ) as Gtk.Widget;
