import { createState, For, With } from "ags";
import { execAsync } from "ags/process";
import { Gtk } from "ags/gtk4";
import { timeout } from "ags/time";
import GLib from "gi://GLib";
import { readJson } from "../utils/json";
import { notify } from "../utils/notification";

const DAEMON = `${GLib.get_home_dir()}/.config/hypr/wallpaper-daemon`;

interface WeProp {
  key: string;
  type: string;
  text: string;
  value: any;
  options?: any[] | null;
  min?: number | null;
  max?: number | null;
  step?: number | null;
}

type RGB = [number, number, number];

const clamp255 = (n: number) => Math.max(0, Math.min(255, Math.round(n * 255)));

// "0.5 0.25 1" (WE color, components 0..1) -> [0.5, 0.25, 1].
function parseColor(value: any): RGB {
  const p = String(value).trim().split(/\s+/).map(Number);
  return [p[0] || 0, p[1] || 0, p[2] || 0];
}

function rgbCss([r, g, b]: RGB): string {
  return `rgb(${clamp255(r)},${clamp255(g)},${clamp255(b)})`;
}

function rgbToHex([r, g, b]: RGB): string {
  const h = (n: number) => clamp255(n).toString(16).padStart(2, "0");
  return `#${h(r)}${h(g)}${h(b)}`;
}

function hexToRgb(hex: string): RGB | null {
  const m = /^#?([0-9a-fA-F]{6})$/.exec(hex.trim());
  if (!m) return null;
  const n = parseInt(m[1], 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}

// linux-wallpaperengine reads a color WITHOUT a decimal point as 0..255 and WITH
// one as 0..1; we always emit floats 0..1 with a forced decimal point.
function rgbToWe([r, g, b]: RGB): string {
  return `${r.toFixed(5)} ${g.toFixed(5)} ${b.toFixed(5)}`;
}

function normalizeWeColor(value: any): string {
  return rgbToWe(parseColor(value));
}

function isTruthy(v: any): boolean {
  return v === true || v === 1 || v === "1" || v === "true";
}

// Show slider values with just enough precision to be useful but not noisy.
function fmtNumber(n: number): string {
  if (Number.isInteger(n)) return String(n);
  return n.toFixed(Math.abs(n) < 1 ? 3 : 2);
}

/**
 * Inline RGB colour picker. Replaces Gtk.ColorButton, whose system colour
 * chooser opens as a separate top-level window (a floating/tiled app window on
 * Hyprland). A nested popover renders inside the layer-shell surface instead, so
 * the picker stays attached to the menu — no stray window.
 */
function ColorControl({
  value,
  onChange,
}: {
  value: any;
  onChange: (we: string, debounce: boolean) => void;
}) {
  const init = parseColor(value);
  const [color, setColor] = createState<RGB>(init);

  const setChannel = (index: number, v: number) => {
    const next = [...color.peek()] as RGB;
    next[index] = v;
    setColor(next);
    onChange(rgbToWe(next), true);
  };

  const Channel = ({ label, index }: { label: string; index: number }) => (
    <box class="we-color-channel" spacing={6} valign={Gtk.Align.CENTER}>
      <label class="we-color-channel-label" label={label} />
      <slider
        class={`we-color-slider ch-${label.toLowerCase()}`}
        widthRequest={150}
        hexpand
        min={0}
        max={1}
        step={1 / 255}
        value={init[index]}
        onValueChanged={(self) => setChannel(index, self.get_value())}
      />
      <label
        class="we-color-channel-value"
        label={color((c) => String(clamp255(c[index])))}
      />
    </box>
  );

  return (
    <menubutton
      class="we-color-button"
      valign={Gtk.Align.CENTER}
      halign={Gtk.Align.START}
    >
      <box
        class="we-color-swatch"
        css={color((c) => `background-color: ${rgbCss(c)};`)}
      />
      <popover>
        <box
          class="we-color-popover"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={8}
        >
          <box
            class="we-color-preview"
            css={color((c) => `background-color: ${rgbCss(c)};`)}
          />
          <Channel label="R" index={0} />
          <Channel label="G" index={1} />
          <Channel label="B" index={2} />
          <box class="we-color-entry-row" spacing={6} valign={Gtk.Align.CENTER}>
            <label class="we-color-entry-label" label="Hex" />
            <entry
              class="we-color-hex"
              hexpand
              text={color((c) => rgbToHex(c))}
              onActivate={(self) => {
                const rgb = hexToRgb(self.text);
                if (rgb) {
                  setColor(rgb);
                  onChange(rgbToWe(rgb), false);
                }
              }}
            />
          </box>
        </box>
      </popover>
    </menubutton>
  );
}

/** Slider with a live numeric readout next to it. */
function SliderControl({
  prop,
  onChange,
}: {
  prop: WeProp;
  onChange: (value: string, debounce: boolean) => void;
}) {
  const [val, setVal] = createState<number>(Number(prop.value) || 0);
  return (
    <box class="we-slider-row" spacing={8} valign={Gtk.Align.CENTER} halign={Gtk.Align.START}>
      <slider
        widthRequest={180}
        hexpand={false}
        min={prop.min ?? 0}
        max={prop.max ?? 1}
        step={prop.step ?? 0.01}
        value={Number(prop.value) || 0}
        onValueChanged={(self) => {
          setVal(self.get_value());
          onChange(String(self.get_value()), true);
        }}
      />
      <label class="we-slider-value" label={val((v) => fmtNumber(v))} />
    </box>
  );
}

/**
 * Dynamic per-wallpaper Wallpaper Engine property editor. Reads whatever
 * properties the currently-applied wallpaper declares (bool / slider / color /
 * combo / textinput) and writes overrides that get passed via --set-property.
 */
export function WallpaperEngineProperties({
  monitorName,
}: {
  monitorName: string;
}) {
  const [weId, setWeId] = createState<string>("");
  const [props, setProps] = createState<WeProp[]>([]);

  // Debounce timers per property so dragging a slider doesn't relaunch the
  // engine on every tick.
  const timers = new Map<string, ReturnType<typeof timeout>>();

  const setProp = (key: string, value: string, debounce = false) => {
    const id = weId.peek();
    if (!id) return;
    const apply = () => {
      // Persist the override, then push it over the control socket. The engine applies everything
      // live: plain values update uniforms in place, and visibility-gating properties (coloring
      // combos, xray) trigger a flash-free in-process rebuild. Reload only if the socket is gone.
      execAsync(["bash", `${DAEMON}/wallpaperengine-properties.sh`, "--set", id, key, value])
        .then(() =>
          execAsync([
            "bash",
            `${DAEMON}/wallpaperengine-ctl.sh`,
            "property",
            key,
            value,
          ]).catch(() =>
            execAsync(["bash", `${DAEMON}/apply-current.sh`, monitorName]),
          ),
        )
        .catch((err) => notify({ summary: "Error", body: String(err) }));
    };
    if (debounce) {
      timers.get(key)?.cancel?.();
      timers.set(key, timeout(450, apply));
    } else {
      apply();
    }
  };

  const load = async () => {
    try {
      const id = (
        await execAsync(
          `bash ${DAEMON}/wallpaperengine-properties.sh --current ${monitorName}`,
        )
      ).trim();
      setWeId(id);
      if (!id) {
        setProps([]);
        return;
      }
      const out = await execAsync(
        `bash ${DAEMON}/wallpaperengine-properties.sh --list ${id}`,
      );
      setProps((readJson(out) as WeProp[]) || []);
    } catch (e) {
      setProps([]);
    }
  };

  const resetAll = () => {
    const id = weId.peek();
    if (!id) return;
    // Clearing overrides needs a reload to restore the wallpaper's defaults.
    execAsync(`bash ${DAEMON}/wallpaperengine-properties.sh --reset ${id}`)
      .then(() => execAsync(`bash ${DAEMON}/apply-current.sh ${monitorName}`))
      .then(load)
      .catch((err) => notify({ summary: "Error", body: String(err) }));
  };

  const Control = (p: WeProp) => {
    switch (p.type) {
      case "bool":
        return (
          <switch
            valign={Gtk.Align.CENTER}
            halign={Gtk.Align.START}
            hexpand={false}
            active={isTruthy(p.value)}
            onNotifyActive={(self) =>
              setProp(p.key, self.active ? "true" : "false")
            }
          />
        );
      case "slider":
        return (
          <SliderControl
            prop={p}
            onChange={(value, debounce) => setProp(p.key, value, debounce)}
          />
        );
      case "combo": {
        const opts = p.options || [];
        // Combos that ship no default value report value:null; Wallpaper Engine treats that as the
        // first option, so reflect that here instead of showing nothing selected.
        const firstValue = opts.length ? String(opts[0]?.value ?? opts[0]) : "";
        const current =
          p.value === null || p.value === undefined || p.value === ""
            ? firstValue
            : String(p.value);
        return (
          <box
            class="we-combo"
            spacing={4}
            halign={Gtk.Align.START}
            hexpand={false}
            $={(self: any) => {
              // A combo is single-choice. Link the option togglebuttons into one GTK radio group so
              // selecting one releases the others — previously they were independent toggles, so several
              // could read as "active" at once and a stray value could be written for the wrong key.
              let leader: any = null;
              for (let c = self.get_first_child(); c != null; c = c.get_next_sibling()) {
                if (leader === null) leader = c;
                else c.set_group?.(leader);
              }
            }}
          >
            {opts.map((o: any) => {
              const label = String(o?.label ?? o?.text ?? o?.value ?? o);
              const value = String(o?.value ?? o);
              return (
                <togglebutton
                  label={label}
                  active={current === value}
                  onToggled={({ active }) => active && setProp(p.key, value)}
                />
              );
            })}
          </box>
        );
      }
      case "color":
        return (
          <ColorControl
            value={p.value}
            onChange={(we, debounce) => setProp(p.key, we, debounce)}
          />
        );
      default:
        // textinput and anything unknown -> plain text entry
        return (
          <entry
            widthRequest={160}
            halign={Gtk.Align.START}
            hexpand={false}
            text={String(p.value ?? "")}
            onActivate={(self) => setProp(p.key, self.text)}
          />
        );
    }
  };

  return (
    <menubutton class="we-properties" halign={Gtk.Align.CENTER}>
      <label label=" Properties" />
      <popover
        $={(self) => {
          // (Re)load whenever the popover is opened.
          self.connect("show", load);
        }}
      >
        <box
          orientation={Gtk.Orientation.VERTICAL}
          spacing={8}
          class="popover we-properties-popover"
          widthRequest={340}
        >
          <With value={weId}>
            {(id) =>
              !id ? (
                <label
                  label="Apply a Wallpaper Engine wallpaper to customize it."
                  wrap
                />
              ) : (
                <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                  <Gtk.ScrolledWindow
                    hscrollbarPolicy={Gtk.PolicyType.NEVER}
                    vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
                    heightRequest={360}
                    propagateNaturalHeight
                  >
                    <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
                      <For each={props}>
                        {(p) => (
                          <box
                            class="we-property"
                            orientation={Gtk.Orientation.VERTICAL}
                            spacing={3}
                          >
                            <label
                              class="we-property-label"
                              label={p.text || p.key}
                              xalign={0}
                              wrap
                            />
                            {Control(p)}
                          </box>
                        )}
                      </For>
                    </box>
                  </Gtk.ScrolledWindow>
                  <button
                    class="we-property-reset"
                    label="Reset to defaults"
                    onClicked={resetAll}
                  />
                </box>
              )
            }
          </With>
        </box>
      </popover>
    </menubutton>
  );
}
