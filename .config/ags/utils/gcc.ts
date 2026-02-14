import { exec } from "ags/process";

export async function compileBinaries() {
  exec(`bash -c "mkdir -p ./cache/binaries"`);
  exec(
    `gcc -o ./cache/binaries/bandwidth-loop-ags ./scripts/bandwidth-loop-ags.c`,
  );
  exec(
    `gcc -o ./cache/binaries/system-resources-loop-ags ./scripts/system-resources-loop-ags.c`,
  );
  exec(
    `gcc -o ./cache/binaries/keystroke-loop-ags ./scripts/keystroke-loop-ags.c`,
  );
}
