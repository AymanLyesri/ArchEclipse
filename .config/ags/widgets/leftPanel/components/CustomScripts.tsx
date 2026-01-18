import Gtk from "gi://Gtk?version=4.0";
import KeyBind from "../../KeyBind";
import { customScripts } from "../../../constants/customScript.constant";
import { execAsync } from "ags/process";

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
            class="script"
            onClicked={() => {
              script.script();
            }}
            $={(self) => {
              if (script.app) {
                execAsync(
                  `bash -c "command -v ${script.app} >/dev/null 2>&1 && echo true || echo false"`,
                )
                  .then((res) => {
                    self.sensitive = res.trim() === "true";
                    res.trim() !== "true"
                      ? (self.tooltipText = `${script.app} (Requires installation)`)
                      : (self.tooltipText = script.description);
                  })
                  .catch(() => {
                    self.sensitive = false;
                    self.tooltipText = `${script.app} (Requires installation)`;
                  });
              }
            }}
          >
            <box spacing={10}>
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
