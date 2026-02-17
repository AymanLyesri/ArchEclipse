import { exec } from "ags/process";
import GLib from "gi://GLib";

export async function compileBinaries() {
  exec(`bash -c "mkdir -p ${GLib.get_home_dir()}/.cache/binaries"`);
  exec(
    `gcc -o ${GLib.get_home_dir()}/.cache/binaries/bandwidth-loop-ags ${GLib.get_home_dir()}/.config/ags/scripts/bandwidth-loop-ags.c`,
  );
  exec(
    `gcc -o ${GLib.get_home_dir()}/.cache/binaries/system-resources-loop-ags ${GLib.get_home_dir()}/.config/ags/scripts/system-resources-loop-ags.c`,
  );
  exec(
    `gcc -o ${GLib.get_home_dir()}/.cache/binaries/keystroke-loop-ags ${GLib.get_home_dir()}/.config/ags/scripts/keystroke-loop-ags.c`,
  );
}
