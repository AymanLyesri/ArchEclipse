import { exec } from "ags/process";

export async function compileBinaries() {
  exec(
    `bash -c "mkdir -p ./assets/binaries && gcc -o ./assets/binaries/bandwidth ./scripts/bandwidth.c"`
  );
}
