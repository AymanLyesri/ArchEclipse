import { exec } from "ags/process";

export async function compileBinaries() {
  exec(`bash -c "mkdir -p ./assets/binaries"`);
  exec(
    `gcc -o ./assets/binaries/bandwidth-loop-ags ./scripts/bandwidth-loop-ags.c`,
  );
  exec(
    `gcc -o ./assets/binaries/system-resources-loop-ags ./scripts/system-resources-loop-ags.c`,
  );
  exec(
    `gcc -o ./assets/binaries/keystroke-loop-ags ./scripts/keystroke-loop-ags.c`,
  );
}
