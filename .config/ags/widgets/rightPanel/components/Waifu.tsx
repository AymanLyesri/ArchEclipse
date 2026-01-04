import { createState, With } from "ags";
import { globalSettings, setGlobalSetting } from "../../../variables";
import Gtk from "gi://Gtk?version=4.0";
import { BooruImage } from "../../../classes/BooruImage";

function WaifuDisplay() {
  return (
    <With value={globalSettings(({ waifuWidget }) => waifuWidget.current)}>
      {(waifuData: any) => {
        if (!waifuData || !waifuData.id) {
          return (
            <box
              halign={Gtk.Align.CENTER}
              valign={Gtk.Align.CENTER}
              class="no-image"
            >
              <label label="No image selected" />
            </box>
          );
        }

        // Convert plain object to BooruImage instance
        const image = new BooruImage(waifuData);

        console.table(image);

        // All rendering and actions are handled by BooruImage.renderAsWaifuWidget()
        return image.renderAsWaifuWidget({
          width: globalSettings.peek().rightPanel.width,
        });
      }}
    </With>
  );
}

export default () => {
  return (
    <box class="waifu" orientation={Gtk.Orientation.VERTICAL}>
      <WaifuDisplay />
    </box>
  );
};

export function WaifuVisibility() {
  return (
    <togglebutton
      active={globalSettings((s) => s.waifuWidget.visibility)}
      onToggled={({ active }) =>
        setGlobalSetting("waifuWidget.visibility", active)
      }
      label="󰉣"
      class="waifu icon"
    />
  );
}
