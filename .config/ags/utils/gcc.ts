import { exec } from "ags/process";

export async function compileBinaries() {
  exec(`bash -c "mkdir -p ./assets/binaries"`);
  exec(`gcc -o ./assets/binaries/bandwidth ./scripts/bandwidth.c`);
  exec(
    `gcc -o ./assets/binaries/system-resources ./scripts/get-system-resources.c`,
  );
}
