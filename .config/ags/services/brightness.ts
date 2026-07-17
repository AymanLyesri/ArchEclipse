import { monitorFile, readFileAsync } from "ags/file";
import { exec, execAsync } from "ags/process";
import GObject, { register, getter, setter } from "ags/gobject";

// 1. Gather all available backlight devices safely
const getDevices = (): string[] => {
  try {
    // Use absolute path /bin/ls and -1 to bypass 'lsd' or other shell aliases
    return exec(`/bin/ls -1 /sys/class/backlight`).split('\n').filter(Boolean);
  } catch (e) {
    console.error("Failed to list backlight devices:", e);
    return [];
  }
};

const devices = getDevices();

// Helper to get values explicitly targeting a specific device
const get = (dev: string, args: string) => {
  try {
    return Number(exec(`brightnessctl --device=${dev} ${args}`));
  } catch {
    return 0; // Failsafe if a specific device doesn't respond
  }
};

@register({ GTypeName: "Brightness" })
export default class Brightness extends GObject.Object {
  static instance: Brightness;
  static get_default() {
    if (!this.instance) this.instance = new Brightness();
    return this.instance;
  }

  // Use the first found device as the source of truth for the UI's initial state
  #primaryDevice = devices[0];
  #screenMax = this.#primaryDevice ? get(this.#primaryDevice, "max") : 1;
  #screen = this.#primaryDevice ? (get(this.#primaryDevice, "get") / this.#screenMax) : 0;

  @getter(Number)
  get screen() {
    return this.#screen;
  }

  @getter(Boolean)
  get hasBacklight() {
    return devices.length > 0;
  }

  @setter(Number)
  set screen(percent) {
    if (percent < 0) percent = 0;
    if (percent > 1) percent = 1;

    if (this.#screen === percent) return;
    if (devices.length === 0) return;

    this.#screen = percent;

    // 2. Fire the brightness command to ALL devices asynchronously
    const promises = devices.map(dev =>
      execAsync(`brightnessctl --device=${dev} set ${Math.floor(percent * 100)}% -q`)
        .catch(err => console.error(`Failed to set brightness for ${dev}:`, err))
    );

    Promise.all(promises).then(() => {
      this.notify("screen");
    });
  }

  constructor() {
    super();
    
    // 3. Monitor all devices so hardware keys keep the UI in sync
    devices.forEach(dev => {
      monitorFile(`/sys/class/backlight/${dev}/brightness`, async (f) => {
        try {
          const v = await readFileAsync(f);
          const max = get(dev, "max") || 1;
          this.#screen = Number(v) / max;
          this.notify("screen");
        } catch (err) {
          console.error(`Failed to read brightness for ${dev}:`, err);
        }
      });
    });
  }
}
