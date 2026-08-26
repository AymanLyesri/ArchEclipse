import { createState, For, With } from "ags";
import { Gtk } from "ags/gtk4";
import Gdk from "gi://Gdk";
import GLib from "gi://GLib";
import { execAsync } from "ags/process";
import { timeout } from "ags/time";
import { notify } from "../utils/notification";
import ColorPicker from "./ColorPicker";
import { readJSONFile, writeJSONFile } from "../utils/json";
import {
  KirieItem,
  KirieProperty,
  kirieCurrentItem,
  kirieItemProperties,
  kirieOk,
  kirieProperties,
} from "../services/kirie";

// Every Wallpaper Engine wallpaper ships its own settings — bloom, colour
// schemes, speeds, the odd file picker — and kirie serves that schema as JSON.
// The controls below are generated from it, so a wallpaper nobody has seen
// before is editable without a line of code for it.
//
// The engine keeps live overrides in memory only, so what is edited here is
// also written to a per-item file that the wallpaper daemon stages back in the
// next time the item is loaded.

const overridePath = (id: string) =>
  `${GLib.get_home_dir()}/.config/ags/cache/wallpaper-engine/${id}.json`;

const readOverrides = (id: string): Record<string, any> =>
  readJSONFile(overridePath(id), {});

function saveOverride(id: string, key: string, value: any) {
  const overrides = readOverrides(id);
  overrides[key] = value;
  writeJSONFile(overridePath(id), overrides);
}

/** The wire form of a property value: the engine reads booleans as
 * `true`/`false`, sliders as decimals and everything else verbatim, which is
 * what String() already produces for each of them. */
const wireValue = (value: any): string => String(value);

/** Wallpapers that were translated carry a localization key where their label
 * should be ("ui_browse_properties_scheme_color"); show something readable. */
/// Turn a wallpaper author's label into one line of readable text.
///
/// A `project.json` label is whatever its author typed, and plenty of them are
/// HTML — banners, credit links, whole `<img>` tags. GTK renders that verbatim
/// on one enormous line, so the panel ended up wider than the screen showing
/// markup nobody can read. Tags come out, entities are decoded, whitespace
/// collapses, and a label that was *only* markup falls back to its key.
function plainText(raw: string): string {
  // Entities are decoded FIRST and tags stripped after, repeatedly: a label
  // that arrives as `&lt;center&gt;&lt;a href=…` is markup wearing a
  // disguise, and stripping before decoding just unwraps it into visible
  // tag soup — which is exactly what the settings panel was showing.
  const decode = (text: string) =>
    text
      .replace(/&nbsp;/gi, " ")
      .replace(/&lt;/gi, "<")
      .replace(/&gt;/gi, ">")
      .replace(/&quot;/gi, '"')
      .replace(/&#0?39;/g, "'")
      .replace(/&amp;/gi, "&");

  let text = raw;
  for (let pass = 0; pass < 3; pass += 1) {
    const next = decode(text).replace(/<[^>]*>/g, " ");
    if (next === text) break;
    text = next;
  }

  const stripped = text.replace(/\s+/g, " ").trim();
  // A bare URL left behind by a stripped link is not a label either.
  return /^https?:\/\/\S*$/.test(stripped) ? "" : stripped;
}

/// Whether a property is a banner rather than a setting.
///
/// Wallpaper authors use label-only properties as decoration — a credit link,
/// a QQ group, a picture of themselves. Their `text` is pure markup, and the
/// key kirie derives from it is that same markup with the punctuation gone
/// ("centerahrefhttpsspacebilibilicom5890295imgsrc…"), so neither is showable.
/// The row carries no control worth keeping either, so it does not get drawn.
function isBanner(property: KirieProperty): boolean {
  const raw = property.text ?? "";
  if (!raw.trim()) return false;
  // Wrote something, and none of it survived being read as text ⇒ it was
  // markup all the way down.
  return plainText(raw) === "";
}

function propertyLabel(property: KirieProperty): string {
  const text = plainText(property.text || "") || property.key;
  if (!text.startsWith("ui_")) return text;

  return text
    .replace(/^ui_(browse_)?(properties_)?/, "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

const rgbaToTriple = (rgba: Gdk.RGBA) =>
  `${rgba.red.toFixed(6)} ${rgba.green.toFixed(6)} ${rgba.blue.toFixed(6)}`;

function tripleToRgba(triple: any): Gdk.RGBA {
  const [r, g, b] = String(triple ?? "0 0 0")
    .trim()
    .split(/\s+/)
    .map((n) => parseFloat(n) || 0);
  const rgba = new Gdk.RGBA();
  rgba.red = r ?? 0;
  rgba.green = g ?? 0;
  rgba.blue = b ?? 0;
  rgba.alpha = 1;
  return rgba;
}

export default function WallpaperEngineProperties({
  monitor,
  item,
}: {
  monitor: string;
  item: KirieItem;
}) {
  const [properties, setProperties] = createState<KirieProperty[]>([]);
  const [status, setStatus] = createState("Loading…");
  // Only the wallpaper actually on screen can be changed live; the rest are
  // edited for the next time they are applied.
  let live = false;

  async function load() {
    try {
      live = (await kirieCurrentItem(monitor)) === item.dir;
      const schema = live
        ? await kirieProperties(monitor)
        : await kirieItemProperties(item.dir);
      setProperties(schema);
      setStatus(
        schema.length === 0
          ? "This wallpaper has no settings."
          : live
            ? ""
            : "Not on this monitor — changes apply when it is.",
      );
    } catch (err) {
      setProperties([]);
      setStatus(String(err));
    }
  }

  function apply(property: KirieProperty, value: any) {
    saveOverride(item.id, property.key, value);
    if (live) kirieOk(`property ${monitor} ${property.key} ${wireValue(value)}`);
  }

  function reset() {
    writeJSONFile(overridePath(item.id), {});
    if (live)
      for (const property of properties.peek())
        kirieOk(
          `property ${monitor} ${property.key} ${wireValue(property.value)}`,
        );
    load();
    notify({ summary: item.title, body: "Wallpaper settings reset." });
  }

  const Property = (property: KirieProperty) => {
    const saved = readOverrides(item.id)[property.key];
    const value = saved !== undefined ? saved : property.value;
    const title = (
      <label
        class="property-name"
        hexpand
        xalign={0}
        // Wrapped and capped: a long label is the author's business, but a row
        // that sets the panel's width is ours.
        wrap={true}
        maxWidthChars={28}
        label={propertyLabel(property)}
        tooltipText={propertyLabel(property)}
      />
    );

    switch (property.type) {
      case "bool":
        return (
          <box class="property" spacing={5}>
            {title}
            <switch
              halign={Gtk.Align.END}
              active={value === true || value === "true"}
              onNotifyActive={(self) => apply(property, self.active)}
            />
          </box>
        );

      case "slider": {
        const readout = (
          <label class="property-value" label={Number(value).toFixed(2)} />
        ) as Gtk.Label;
        let pending: any = null;

        return (
          <box class="property" spacing={5}>
            {title}
            <box halign={Gtk.Align.END} spacing={5}>
              <slider
                class="slider"
                widthRequest={140}
                drawValue={false}
                min={property.min ?? 0}
                max={property.max ?? 1}
                step={property.step ?? 0.01}
                value={Number(value) || 0}
                onValueChanged={(self) => {
                  const next = parseFloat(self.get_value().toFixed(3));
                  readout.label = next.toFixed(2);
                  // The engine rebuilds the scene per change; coalesce a drag
                  // into one write.
                  pending?.cancel?.();
                  pending = timeout(150, () => apply(property, next));
                }}
              />
              {readout}
            </box>
          </box>
        );
      }

      case "combo":
        return (
          <box class="property" spacing={5}>
            {title}
            <menubutton class="property-combo" halign={Gtk.Align.END}>
              <label
                label={
                  property.options?.find(
                    (option) => String(option.value) === String(value),
                  )?.label ?? String(value)
                }
              />
              {/* Beside the row, not on top of it: the panel is a dense
                  column, and a popover pointing down covers the very settings
                  the choice is being compared against. */}
              <popover position={Gtk.PositionType.LEFT}>
                <box orientation={Gtk.Orientation.VERTICAL} class="popover">
                  {(property.options ?? []).map((option) => (
                    <button
                      class={
                        String(option.value) === String(value)
                          ? "selected"
                          : ""
                      }
                      label={option.label}
                      onClicked={(self) => {
                        apply(property, option.value);
                        (
                          self.get_ancestor(Gtk.Popover) as Gtk.Popover
                        )?.popdown();
                        load();
                      }}
                    />
                  ))}
                </box>
              </popover>
            </menubutton>
          </box>
        );

      case "color":
        return (
          <box class="property" spacing={5}>
            {title}
            <ColorPicker
              rgba={tripleToRgba(value)}
              onPicked={(picked) => apply(property, rgbaToTriple(picked))}
            />
          </box>
        );

      case "file":
      case "directory":
        return (
          <box class="property" spacing={5}>
            {title}
            <button
              class="property-file"
              halign={Gtk.Align.END}
              tooltipText={String(value || "")}
              label={String(value || "Choose…")
                .split("/")
                .pop()
                ?.slice(0, 20)}
              onClicked={(self) => {
                // No shell: a property's label is whatever its author wrote.
                const picker = ["zenity", "--file-selection"];
                if (property.type === "directory") picker.push("--directory");
                picker.push("--title", propertyLabel(property));

                execAsync(picker)
                  .then((path) => {
                    const chosen = path.trim();
                    if (!chosen) return;
                    apply(property, chosen);
                    self.label = (chosen.split("/").pop() ?? chosen).slice(0, 20);
                    self.tooltipText = chosen;
                  })
                  .catch(() => {});
              }}
            />
          </box>
        );

      default:
        return (
          <box class="property" spacing={5}>
            {title}
            <entry
              halign={Gtk.Align.END}
              text={String(value ?? "")}
              onActivate={(self) => apply(property, self.text)}
            />
          </box>
        );
    }
  };

  return (
    <box
      class="wallpaper-engine-properties"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
      $={load}
    >
      <box spacing={10}>
        {/* Item titles carry the same author-written markup the labels do. */}
        <label
          class="title"
          hexpand
          xalign={0}
          wrap={true}
          maxWidthChars={30}
          label={plainText(item.title) || item.id}
          tooltipText={plainText(item.title) || item.id}
        />
        <button
          class="reset"
          label="󰑐"
          tooltipText="Reset this wallpaper's settings"
          onClicked={reset}
        />
      </box>

      <With value={status}>
        {(text) => text && <label class="status" wrap label={text} />}
      </With>

      <scrolledwindow
        class="properties"
        propagateNaturalHeight
        maxContentHeight={420}
        hscrollbarPolicy={Gtk.PolicyType.NEVER}
      >
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
          <For each={properties}>
            {(property) =>
              isBanner(property) ? (
                <box visible={false} />
              ) : (
                Property(property)
              )
            }
          </For>
        </box>
      </scrolledwindow>
    </box>
  );
}
