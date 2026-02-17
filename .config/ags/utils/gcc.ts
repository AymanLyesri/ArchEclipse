import { execAsync } from "ags/process";
import GLib from "gi://GLib";

export async function compileBinaries() {
  const homeDir = GLib.get_home_dir();
  const tmpDir = `/tmp/ags`;
  const scriptsDir = `${homeDir}/.config/ags/scripts`;

  await execAsync(`bash -c "mkdir -p ${tmpDir}"`);

  await Promise.all([
    execAsync(
      `gcc -o ${tmpDir}/bandwidth-loop-ags ${scriptsDir}/bandwidth-loop-ags.c`,
    ),
    execAsync(
      `gcc -o ${tmpDir}/system-resources-loop-ags ${scriptsDir}/system-resources-loop-ags.c`,
    ),
    execAsync(
      `gcc -o ${tmpDir}/keystroke-loop-ags ${scriptsDir}/keystroke-loop-ags.c`,
    ),
  ]);
}
