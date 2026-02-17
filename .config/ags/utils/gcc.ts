import { exec } from "ags/process";
import GLib from "gi://GLib";

export function compileBinaries() {
  const homeDir = GLib.get_home_dir();
  const tmpDir = `/tmp/ags`;
  const scriptsDir = `${homeDir}/.config/ags/scripts`;

  exec(`bash -c "mkdir -p ${tmpDir}"`);
  exec(
    `gcc -o ${tmpDir}/bandwidth-loop-ags ${scriptsDir}/bandwidth-loop-ags.c`,
  );
  exec(
    `gcc -o ${tmpDir}/system-resources-loop-ags ${scriptsDir}/system-resources-loop-ags.c`,
  );
  exec(
    `gcc -o ${tmpDir}/keystroke-loop-ags ${scriptsDir}/keystroke-loop-ags.c`,
  );
}
