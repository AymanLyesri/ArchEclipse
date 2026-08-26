import { Gtk } from "ags/gtk4";
import Gdk from "gi://Gdk";

// A small colour picker that lives inside the panel.
//
// GTK's own `Gtk.ColorDialog` opens a full dialog window: under a layer-shell
// shell it has no parent to sit on, so the compositor drops it in the corner
// at whatever size it asks for — a palette grid taking a third of the screen
// to set one wallpaper colour. This is the same job as a popover on the swatch
// itself: an HSV wheel, a value/saturation square inside it, and a hex field.

/// Wheel side in pixels, and how thick the hue ring is.
const SIZE = 176;
const RING = 14;

/// Cells across the saturation/value square.
///
/// It is painted as a grid rather than with cairo gradients: two overlaid
/// gradients need a mesh or per-pixel surface to look right, while 26×26 flat
/// cells are exact, redraw in well under a frame, and never depend on which
/// cairo bindings gjs happens to expose.
const CELLS = 26;

/// HSV (each 0..1) to RGB (each 0..1).
const hsvToRgb = (h: number, s: number, v: number): [number, number, number] => {
  const i = Math.floor(h * 6);
  const f = h * 6 - i;
  const p = v * (1 - s);
  const q = v * (1 - f * s);
  const t = v * (1 - (1 - f) * s);
  switch (i % 6) {
    case 0:
      return [v, t, p];
    case 1:
      return [q, v, p];
    case 2:
      return [p, v, t];
    case 3:
      return [p, q, v];
    case 4:
      return [t, p, v];
    default:
      return [v, p, q];
  }
};

/// RGB (each 0..1) to HSV (each 0..1).
const rgbToHsv = (r: number, g: number, b: number): [number, number, number] => {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const d = max - min;
  let h = 0;
  if (d !== 0) {
    if (max === r) h = ((g - b) / d) % 6;
    else if (max === g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    h /= 6;
    if (h < 0) h += 1;
  }
  return [h, max === 0 ? 0 : d / max, max];
};

const clamp01 = (n: number) => Math.min(1, Math.max(0, n));

const toHex = (r: number, g: number, b: number) =>
  "#" +
  [r, g, b]
    .map((c) =>
      Math.round(clamp01(c) * 255)
        .toString(16)
        .padStart(2, "0"),
    )
    .join("");

/// Parse `#rgb`, `#rrggbb` or a bare hex triple; `null` when it is not one.
const fromHex = (text: string): [number, number, number] | null => {
  const hex = text.trim().replace(/^#/, "");
  const full =
    hex.length === 3
      ? hex
          .split("")
          .map((c) => c + c)
          .join("")
      : hex;
  if (!/^[0-9a-fA-F]{6}$/.test(full)) return null;
  return [
    parseInt(full.slice(0, 2), 16) / 255,
    parseInt(full.slice(2, 4), 16) / 255,
    parseInt(full.slice(4, 6), 16) / 255,
  ];
};

export default function ColorPicker({
  rgba,
  onPicked,
}: {
  /// The colour to open on.
  rgba: Gdk.RGBA;
  /// Called on every change, so the wallpaper follows the drag live.
  onPicked: (rgba: Gdk.RGBA) => void;
}) {
  let [h, s, v] = rgbToHsv(rgba.red, rgba.green, rgba.blue);

  // Painted rather than styled. `css` on a widget built outside JSX is gnim's
  // property, not GTK's, and the class list it works through is the same one
  // this code sets — so the swatch came out empty. A drawing area owes nothing
  // to the stylesheet and always shows the colour it is given.
  const swatch = new Gtk.DrawingArea({
    widthRequest: 34,
    heightRequest: 20,
    cssClasses: ["color-swatch"],
  });
  const hexEntry = new Gtk.Entry({
    maxWidthChars: 9,
    widthChars: 9,
    xalign: 0.5,
  });

  const wheel = new Gtk.DrawingArea({
    widthRequest: SIZE,
    heightRequest: SIZE,
    cssClasses: ["color-wheel"],
  });

  /// Push the current HSV everywhere: the wheel, the swatch, the hex field and
  /// the caller.
  const publish = (notify = true) => {
    const [r, g, b] = hsvToRgb(h, s, v);
    const hex = toHex(r, g, b);
    if (hexEntry.text !== hex) hexEntry.text = hex;
    swatch.queue_draw();
    wheel.queue_draw();
    if (!notify) return;
    const out = new Gdk.RGBA();
    out.red = r;
    out.green = g;
    out.blue = b;
    out.alpha = 1;
    onPicked(out);
  };

  wheel.set_draw_func((_area, cr, width, height) => {
    const cx = width / 2;
    const cy = height / 2;
    const outer = Math.min(width, height) / 2 - 1;
    const inner = outer - RING;

    // Hue ring, in wedges. A stroked arc per wedge, slightly overlapping so no
    // seams show between them.
    cr.setLineWidth(RING);
    for (let deg = 0; deg < 360; deg += 2) {
      const a0 = (deg * Math.PI) / 180;
      const a1 = ((deg + 2.6) * Math.PI) / 180;
      const [r, g, b] = hsvToRgb(deg / 360, 1, 1);
      cr.setSourceRGBA(r, g, b, 1);
      cr.arc(cx, cy, (outer + inner) / 2, a0, a1);
      cr.stroke();
    }

    // Saturation/value square, inscribed in the ring.
    const side = inner * Math.SQRT2 - 4;
    const x0 = cx - side / 2;
    const y0 = cy - side / 2;
    const step = side / CELLS;
    for (let ix = 0; ix < CELLS; ix += 1) {
      for (let iy = 0; iy < CELLS; iy += 1) {
        const [r, g, b] = hsvToRgb(
          h,
          (ix + 0.5) / CELLS,
          1 - (iy + 0.5) / CELLS,
        );
        cr.setSourceRGBA(r, g, b, 1);
        // Half a pixel of overlap, again to avoid hairlines between cells.
        cr.rectangle(x0 + ix * step, y0 + iy * step, step + 0.5, step + 0.5);
        cr.fill();
      }
    }

    // Hue marker.
    const angle = h * 2 * Math.PI;
    const mx = cx + Math.cos(angle) * ((outer + inner) / 2);
    const my = cy + Math.sin(angle) * ((outer + inner) / 2);
    cr.setLineWidth(2);
    cr.setSourceRGBA(0, 0, 0, 0.7);
    cr.arc(mx, my, RING / 2 - 1, 0, 2 * Math.PI);
    cr.stroke();
    cr.setSourceRGBA(1, 1, 1, 0.95);
    cr.arc(mx, my, RING / 2 - 2.5, 0, 2 * Math.PI);
    cr.stroke();

    // Saturation/value marker, outlined in both black and white so it stays
    // visible over every part of the square.
    const px = x0 + s * side;
    const py = y0 + (1 - v) * side;
    cr.setSourceRGBA(0, 0, 0, 0.8);
    cr.arc(px, py, 6, 0, 2 * Math.PI);
    cr.stroke();
    cr.setSourceRGBA(1, 1, 1, 0.95);
    cr.arc(px, py, 4.5, 0, 2 * Math.PI);
    cr.stroke();
  });

  swatch.set_draw_func((_area, cr, width, height) => {
    const [r, g, b] = hsvToRgb(h, s, v);
    const radius = 4;
    // A rounded rect, so the preview matches the pill shapes around it.
    cr.newPath();
    cr.arc(width - radius, radius, radius, -Math.PI / 2, 0);
    cr.arc(width - radius, height - radius, radius, 0, Math.PI / 2);
    cr.arc(radius, height - radius, radius, Math.PI / 2, Math.PI);
    cr.arc(radius, radius, radius, Math.PI, (3 * Math.PI) / 2);
    cr.closePath();
    cr.setSourceRGBA(r, g, b, 1);
    cr.fillPreserve();
    cr.setLineWidth(1);
    cr.setSourceRGBA(1, 1, 1, 0.25);
    cr.stroke();
  });

  /// Which control a press landed on. Decided once per gesture, so a drag that
  /// starts on the ring keeps setting the hue even when it leaves it.
  let dragging: "ring" | "square" | null = null;

  const pick = (x: number, y: number) => {
    const cx = SIZE / 2;
    const cy = SIZE / 2;
    const outer = SIZE / 2 - 1;
    const inner = outer - RING;
    const dx = x - cx;
    const dy = y - cy;
    const dist = Math.hypot(dx, dy);

    if (dragging === null) {
      dragging = dist > inner - 2 ? "ring" : "square";
    }

    if (dragging === "ring") {
      let angle = Math.atan2(dy, dx);
      if (angle < 0) angle += 2 * Math.PI;
      h = angle / (2 * Math.PI);
    } else {
      const side = inner * Math.SQRT2 - 4;
      const x0 = cx - side / 2;
      const y0 = cy - side / 2;
      s = clamp01((x - x0) / side);
      v = clamp01(1 - (y - y0) / side);
    }
    publish();
  };

  const click = new Gtk.GestureClick();
  click.connect("pressed", (_g, _n, x, y) => {
    dragging = null;
    pick(x, y);
  });
  click.connect("released", () => {
    dragging = null;
  });
  wheel.add_controller(click);

  const drag = new Gtk.GestureDrag();
  drag.connect("drag-update", (gesture, ox, oy) => {
    const [, sx, sy] = gesture.get_start_point();
    pick(sx + ox, sy + oy);
  });
  drag.connect("drag-end", () => {
    dragging = null;
  });
  wheel.add_controller(drag);

  hexEntry.connect("activate", () => {
    const parsed = fromHex(hexEntry.text);
    if (!parsed) {
      // Not a colour: put the current one back rather than leave a typo that
      // looks like it was accepted.
      publish(false);
      return;
    }
    [h, s, v] = rgbToHsv(...parsed);
    publish();
  });

  publish(false);

  return (
    <menubutton class="color-picker" halign={Gtk.Align.END}>
      {swatch}
      {/* Same reason as the combo list: opening downwards would cover the
          colours it is being matched against. */}
      <popover class="color-picker-popover" position={Gtk.PositionType.LEFT}>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
          {wheel}
          <box spacing={6} halign={Gtk.Align.CENTER}>
            {hexEntry}
          </box>
        </box>
      </popover>
    </menubutton>
  );
}
