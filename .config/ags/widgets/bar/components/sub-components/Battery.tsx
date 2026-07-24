import { createBinding, createComputed } from "ags";
import { Gtk } from "ags/gtk4";
import AstalBattery from "gi://AstalBattery";
import AstalPowerProfiles from "gi://AstalPowerProfiles";
import { connectPopoverEvents } from "../../../../utils/window";

export default () => {
  const battery = AstalBattery.get_default();
  const powerprofiles = AstalPowerProfiles.get_default();

  const percent = createBinding(
    battery,
    "percentage",
  )((p) => `${Math.floor(p * 100)}%`);

  const setProfile = (profile: string) => {
    powerprofiles.set_active_profile(profile);
  };

  const popover = (
    <popover
      $={(self) => {
        self.connect("notify::visible", () => {
          if (self.visible) self.add_css_class("popover-open");
          else if (self.get_child()) self.remove_css_class("popover-open");
        });
      }}
    >
      <box orientation={Gtk.Orientation.VERTICAL}>
        {powerprofiles.get_profiles().map(({ profile }) => (
          <button onClicked={() => setProfile(profile)}>
            <label label={profile} xalign={0} />
          </button>
        ))}
      </box>
    </popover>
  ) as Gtk.Popover;

  return (
    <menubutton
      visible={createBinding(battery, "isPresent")}
      tooltipMarkup={createComputed(
        [percent, createBinding(powerprofiles, "activeProfile")], 
        (p, profile) => `Battery: ${p} \nProfile: ${profile}`
      )}
      $={(self) => connectPopoverEvents(self, "barWindow", popover)}
    >
      <box spacing={5} class="battery">
        <image iconName={createBinding(battery, "iconName")} />
        <label label={percent} />
      </box>
      {popover}
    </menubutton>
  );
};