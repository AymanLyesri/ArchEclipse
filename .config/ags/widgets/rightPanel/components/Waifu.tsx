import { Accessor, createState, With } from "ags";
import { globalSettings, setGlobalSetting } from "../../../variables";
import Gtk from "gi://Gtk?version=4.0";
import { BooruImage } from "../../../classes/BooruImage";
import app from "ags/gtk4/app";
import { showWindow } from "../../../utils/window";
import { leftPanelWidgetSelectors } from "../../../constants/widget.constants";

function WaifuDisplay() {
  return (
    <With value={globalSettings(({ waifuWidget }) => waifuWidget.current)}>
      {(waifuData: any) => {
        if (!waifuData || !waifuData.id) {
          return (
            <button
              onClicked={(self) => {
                showWindow(
                  `left-panel-${(self.get_root() as any).monitorName}`
                );
                setGlobalSetting(
                  "leftPanel.widget",
                  leftPanelWidgetSelectors[1]
                );
                // setGlobalSetting("rightPanel.vi", "booruViewer");
              }}
            >
              <box
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.CENTER}
                class="no-image"
                orientation={Gtk.Orientation.VERTICAL}
              >
                <label label={"<b>No image selected</b>"} useMarkup />
                <label label={"Open Booru Viewer"} useMarkup />
                <label label={"Select an image"} useMarkup />
                <label label={"Download then Waifu it"} useMarkup />
              </box>
            </button>
          );
        }

        // Convert plain object to BooruImage instance
        const image = new BooruImage(waifuData);

        // All rendering and actions are handled by BooruImage.renderAsWaifuWidget()
        return image.renderAsWaifuWidget({
          width: globalSettings.peek().rightPanel.width,
        });
      }}
    </With>
  );
}

export default ({ className }: { className?: string | Accessor<string> }) => {
  return (
    <box
      class={`waifu ${className ?? ""}`}
      orientation={Gtk.Orientation.VERTICAL}
      css={"border-radius: 10px;"}
    >
      <WaifuDisplay />
    </box>
  );
};
