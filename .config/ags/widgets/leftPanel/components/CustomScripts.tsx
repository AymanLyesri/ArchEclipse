import Gtk from "gi://Gtk?version=4.0";
import KeyBind from "../../KeyBind";
import { customScripts } from "../../../constants/customScript.constant";

export default () => {
  return (
    <box
      class="custom-scripts"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      spacing={10}
    >
      {customScripts().map((script) => {
        return (
          <button
            onClicked={() => {
              script.script();
            }}
            tooltipText={script.description}
            $={(self) => {
              const isSensitive = async () => {
                if (typeof script.sensitive === "boolean") {
                  return script.sensitive;
                } else if (script.sensitive instanceof Promise) {
                  return await script.sensitive;
                } else {
                  return true;
                }
              };

              isSensitive().then((sensitive) => {
                self.sensitive = sensitive;
                if (!sensitive) {
                  self.tooltipText = `${script.name} (Requires installation)`;
                }
              });
            }}
          >
            <box class="script" spacing={10}>
              <label
                class="icon"
                halign={Gtk.Align.START}
                wrap
                label={`${script.icon}`}
              />
              <label
                class="name"
                halign={Gtk.Align.START}
                wrap
                wrapMode={Gtk.WrapMode.WORD_CHAR}
                label={script.name}
                hexpand
              />
              {script.keybind && <KeyBind bindings={script.keybind} />}
            </box>
          </button>
        );
      })}
    </box>
  );
};
