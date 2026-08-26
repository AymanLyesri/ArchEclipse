import { createState, With } from "ags";
import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib";
import Pango from "gi://Pango";
import Gdk from "gi://Gdk";
import GdkPixbuf from "gi://GdkPixbuf";
import { execAsync } from "ags/process";
import { timeout } from "ags/time";
import { notify } from "../utils/notification";
import {
  KirieWorkshopItem,
  kirieWorkshopJob,
  kirieWorkshopSearch,
  kirieWorkshopSubscribe,
  kirieWorkshopSupported,
} from "../services/kirie";

// Browse the Steam Workshop from the panel.
//
// The wallpaper switcher can only offer what is already installed; finding
// anything new meant leaving for Steam's own UI. kirie answers Workshop
// queries over its control socket (docs/compat-socket.md §13) by way of a
// short-lived Steam helper, so this is a view over that: search, filter,
// subscribe, and apply the moment the files land.
//
// Two things it deliberately does not do:
//
// * **Ask Steam per keystroke.** A search runs on Enter. Every query is a real
//   request to Valve, and the engine spawns a helper process for each one.
// * **Poll Steam for download progress.** The engine follows a subscription by
//   watching the filesystem, because initialising Steamworks announces the
//   process as playing Wallpaper Engine and accrues playtime. This asks the
//   engine, which already knows.

/// Results per page: three across, four down. Steam serves 50 per query, so a
/// page here is a slice of one — which keeps every thumbnail on screen at a
/// size worth looking at.
const COLUMNS = 3;
const ROWS = 4;
const PAGE_SIZE = COLUMNS * ROWS;

/// Thumbnail edge. Steam serves square preview images, so the card is square.
const TILE = 190;

/// Where downloaded preview thumbnails live.
const PREVIEW_DIR = `${GLib.get_user_cache_dir()}/ags/workshop-previews`;

const SORTS: { label: string; value: "popular" | "trend" | "recent" | "rated" }[] =
  [
    { label: "Popular", value: "popular" },
    { label: "Trending", value: "trend" },
    { label: "Newest", value: "recent" },
    { label: "Top rated", value: "rated" },
  ];

/// The Workshop's own filter vocabulary, grouped the way Steam's page groups
/// it. These are plain tags to the engine — the grouping is purely so the
/// panel can offer one dropdown per axis instead of a wall of chips.
///
/// Tags with spaces in them are why the socket grammar takes quoted values.
const FILTER_GROUPS: { label: string; tags: string[] }[] = [
  { label: "Type", tags: ["Scene", "Video", "Web", "Application"] },
  { label: "Age", tags: ["Everyone", "Questionable", "Mature"] },
  {
    label: "Genre",
    tags: [
      "Abstract",
      "Animal",
      "Anime",
      "Cartoon",
      "CGI",
      "Cyberpunk",
      "Fantasy",
      "Game",
      "Girls",
      "Guys",
      "Landscape",
      "Medieval",
      "Memes",
      "MMD",
      "Music",
      "Nature",
      "Pixel art",
      "Relaxing",
      "Retro",
      "Sci-Fi",
      "Sports",
      "Technology",
      "Television",
      "Vehicle",
      "Unspecified",
    ],
  },
  {
    label: "Resolution",
    tags: [
      "Standard Definition",
      "1280 x 720",
      "1920 x 1080",
      "2560 x 1440",
      "3840 x 2160",
      "Ultrawide Standard",
      "Ultrawide 2560 x 1080",
      "Ultrawide 3440 x 1440",
      "Dual Standard",
      "Dual 3840 x 1080",
      "Dual 5120 x 1440",
      "Triple Standard",
      "Triple 5760 x 1080",
      "Triple 7680 x 1440",
      "Portrait Standard",
      "Portrait 720 x 1280",
      "Portrait 1080 x 1920",
      "Portrait 1440 x 2560",
      "Portrait 2160 x 3840",
      "Other resolution",
      "Dynamic resolution",
    ],
  },
  { label: "Category", tags: ["Wallpaper", "Preset", "Asset"] },
  {
    label: "Features",
    tags: [
      "Approved",
      "Audio responsive",
      "3D",
      "Customizable",
      "Puppet Warp",
      "HDR",
      "Media Integration",
      "User Shortcut",
      "Video Texture",
      "Asset Pack",
    ],
  },
];

/// Tags that mark adult content. Excluded unless the user says otherwise —
/// this panel opens over a desktop.
const ADULT = ["Mature", "Questionable"];

/// Bytes as a short human string.
const humanSize = (bytes: number) => {
  for (const [unit, scale] of [
    ["G", 1024 ** 3],
    ["M", 1024 ** 2],
    ["K", 1024],
  ] as const) {
    if (bytes >= scale) return `${(bytes / scale).toFixed(1)}${unit}`;
  }
  return `${bytes}B`;
};

/// How many preview downloads may be in flight at once.
///
/// A page is 24 items and they all want their thumbnail at the same moment;
/// firing every request together makes the first screenful arrive *slower*,
/// because none of them finish first.
const PREVIEW_PARALLEL = 6;

let previewsRunning = 0;
const previewQueue: (() => void)[] = [];

/// Run `task` when a download slot is free.
const queued = <T,>(task: () => Promise<T>): Promise<T> =>
  new Promise((resolve, reject) => {
    const start = () => {
      previewsRunning += 1;
      task()
        .then(resolve, reject)
        .finally(() => {
          previewsRunning -= 1;
          previewQueue.shift()?.();
        });
    };
    if (previewsRunning < PREVIEW_PARALLEL) start();
    else previewQueue.push(start);
  });

/// Fetch an item's preview image once, and answer with its local path.
///
/// Hardened the same way the engine's own image fetches are: http(s) only,
/// including across redirects, with a time and a size cap, because the URL
/// comes from the network and the file lands on disk.
const ensurePreview = async (item: KirieWorkshopItem): Promise<string | null> => {
  if (!item.preview) return null;
  const path = `${PREVIEW_DIR}/${item.id}.img`;
  if (GLib.file_test(path, GLib.FileTest.EXISTS)) return path;

  GLib.mkdir_with_parents(PREVIEW_DIR, 0o755);
  try {
    await queued(() =>
      execAsync([
        "curl",
        "--silent",
        "--fail",
        "--location",
        "--proto",
        "=http,https",
        "--proto-redir",
        "=http,https",
        "--max-time",
        "20",
        "--max-filesize",
        "8000000",
        "--output",
        path,
        item.preview!,
      ]),
    );
  } catch (_err) {
    // A missing thumbnail is not worth a notification: the card still says
    // what the item is.
    return null;
  }
  return GLib.file_test(path, GLib.FileTest.EXISTS) ? path : null;
};

export default function WorkshopBrowser({
  onApply,
}: {
  /// Show an installed item. The caller owns which screen and slot that means.
  onApply: (dir: string) => void;
}) {
  const [items, setItems] = createState<KirieWorkshopItem[]>([]);
  const [status, setStatus] = createState<string>("");
  const [busy, setBusy] = createState<boolean>(false);
  const [sort, setSort] = createState<(typeof SORTS)[number]["value"]>("popular");
  // One chosen tag per filter group, keyed by group label. Steam ANDs across
  // groups, which is what a picker wants: Scene + Anime + 2560 x 1440.
  const [filters, setFilters] = createState<Record<string, string>>({});
  const [allowAdult, setAllowAdult] = createState<boolean>(false);
  const [page, setPage] = createState<number>(1);

  /// Set or clear one group's tag, then search from the first page again: a
  /// filter change makes the page number meaningless.
  const setFilter = (group: string, tag: string) => {
    const next = { ...filters.peek() };
    if (tag === "" || next[group] === tag) delete next[group];
    else next[group] = tag;
    setFilters(next);
    search(1);
  };

  let query = "";

  const search = (nextPage = 1) => {
    setBusy(true);
    setPage(nextPage);
    setStatus(nextPage === 1 ? "searching…" : `page ${nextPage}…`);
    const chosen = Object.values(filters.peek()).filter(Boolean);
    kirieWorkshopSearch({
      text: query,
      tags: chosen,
      // An explicit age choice wins over the blanket exclusion: asking for
      // "Mature" and getting nothing would just look broken.
      excludeTags:
        allowAdult.peek() || chosen.some((tag) => ADULT.includes(tag))
          ? []
          : ADULT,
      sort: sort.peek(),
      page: nextPage,
      limit: PAGE_SIZE,
    })
      .then((found) => {
        setItems(found);
        setStatus(
          found.length === 0
            ? "nothing matched"
            : `${found.length} result(s) — page ${nextPage}`,
        );
      })
      .catch((err) => {
        setItems([]);
        setStatus(String(err).replace(/^Error:\s*/, ""));
      })
      .finally(() => setBusy(false));
  };

  /// Follow a subscription to its end, reporting into the card's own button.
  ///
  /// `ready` is how the card remembers where the files landed: the button keeps
  /// one click handler that branches on it, rather than growing a second one
  /// that would re-subscribe on every press.
  const follow = (
    job: number,
    button: Gtk.Button,
    item: KirieWorkshopItem,
    ready: (dir: string) => void,
  ) => {
    kirieWorkshopJob(job)
      .then((state) => {
        switch (state.state) {
          case "installed":
            button.label = "Apply";
            button.set_css_classes(["subscribe", "ready"]);
            if (state.dir) ready(state.dir);
            setStatus(`${item.title} installed`);
            return;
          case "error":
            button.label = "Failed";
            setStatus(state.error ?? "the download failed");
            return;
          default:
            button.label = state.bytes
              ? `${humanSize(state.bytes)}…`
              : "Waiting…";
            timeout(1000, () => follow(job, button, item, ready));
        }
      })
      .catch((err) => {
        button.label = "Failed";
        setStatus(String(err));
      });
  };

  const searchEntry = (
    <entry
      hexpand
      maxWidthChars={1}
      placeholderText="Search the Workshop…"
      $={(self: Gtk.Entry) =>
        self.connect("changed", () => {
          query = self.text;
        })
      }
      onActivate={(self: Gtk.Entry) => {
        query = self.text;
        search(1);
      }}
    />
  ) as Gtk.Entry;

  const card = (item: KirieWorkshopItem) => {
    const preview = new Gtk.Picture({
      contentFit: Gtk.ContentFit.COVER,
      widthRequest: TILE,
      heightRequest: TILE,
      cssClasses: ["workshop-preview"],
    });
    ensurePreview(item).then((path) => {
      if (!path) return;
      // NOT `set_filename`: that goes through GdkTexture, which decodes only
      // PNG and JPEG, and a good half of Steam's previews are animated GIFs —
      // they came out blank. GdkPixbuf reads those (first frame), and scaling
      // at load keeps a 1080x1080 thumbnail from becoming a 4 MB texture.
      try {
        const pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
          path,
          TILE * 2,
          TILE * 2,
          true,
        );
        preview.set_paintable(Gdk.Texture.new_for_pixbuf(pixbuf));
      } catch (_err) {
        // An unreadable thumbnail leaves the placeholder tile.
      }
    });

    // Where this item's files are, once they exist. Set from the search
    // result for an item already installed, and from the job that fetches it.
    let installedDir: string | null = item.installed ? item.dir : null;

    const action = (
      <button
        class={installedDir ? "subscribe ready" : "subscribe"}
        label={installedDir ? "Apply" : item.subscribed ? "Waiting…" : "Get"}
        onClicked={(self: Gtk.Button) => {
          if (installedDir) {
            onApply(installedDir);
            return;
          }
          self.label = "Subscribing…";
          kirieWorkshopSubscribe(item.id)
            .then((job) =>
              follow(job, self, item, (dir) => {
                installedDir = dir;
              }),
            )
            .catch((err) => {
              self.label = "Get";
              notify({ summary: "Workshop", body: String(err) });
            });
        }}
      />
    ) as Gtk.Button;

    return (
      <box class="workshop-card" orientation={Gtk.Orientation.VERTICAL} spacing={4}>
        {preview}
        <label
          class="workshop-title"
          label={item.title}
          maxWidthChars={18}
          ellipsize={Pango.EllipsizeMode.END}
          tooltipText={item.title}
        />
        <box spacing={6} halign={Gtk.Align.CENTER}>
          <label class="workshop-kind" label={item.type} />
          <label
            class="workshop-meta"
            label={`${Math.round((item.score ?? 0) * 100)}% · ${humanSize(item.size ?? 0)}`}
          />
        </box>
        {/* Steam knows what the item is; kirie knows whether this build can
            render it, which is the part worth saying before installing. */}
        {!item.renderable && (
          <label
            class="workshop-warning"
            label="kirie cannot render this"
            tooltipText={item.reason ?? ""}
          />
        )}
        {action}
      </box>
    );
  };

  // Say up front when the engine is too old for any of this, rather than
  // letting every search fail with "unknown command".
  kirieWorkshopSupported().then((supported) => {
    if (supported) {
      search(1);
    } else {
      setStatus(
        "this engine has no Workshop support — update kirie (kirie workshop search)",
      );
    }
  });

  return (
    <box
      class="workshop-browser"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
      widthRequest={COLUMNS * (TILE + 26)}
      heightRequest={ROWS * (TILE + 96)}
    >
      <box spacing={6}>
        {searchEntry}
        <menubutton class="workshop-sort">
          <label label={sort((s) => SORTS.find((o) => o.value === s)!.label)} />
          <popover position={Gtk.PositionType.BOTTOM}>
            <box orientation={Gtk.Orientation.VERTICAL} class="popover">
              {SORTS.map((option) => (
                <button
                  label={option.label}
                  onClicked={(self: Gtk.Button) => {
                    setSort(option.value);
                    (self.get_ancestor(Gtk.Popover) as Gtk.Popover)?.popdown();
                    search(1);
                  }}
                />
              ))}
            </box>
          </popover>
        </menubutton>
      </box>

      <Gtk.FlowBox
        class="workshop-filters"
        columnSpacing={6}
        rowSpacing={6}
        selectionMode={Gtk.SelectionMode.NONE}
        homogeneous={false}
        minChildrenPerLine={3}
        maxChildrenPerLine={7}
      >
        {FILTER_GROUPS.map((group) => (
          <menubutton class="workshop-filter">
            {/* The button says what is chosen, not what the group is called:
                a row of "Type / Age / Genre" tells you nothing about the
                query you are actually looking at. */}
            <label
              label={filters((f) => f[group.label] ?? group.label)}
              maxWidthChars={16}
              ellipsize={Pango.EllipsizeMode.END}
            />
            <popover position={Gtk.PositionType.BOTTOM}>
              <scrolledwindow
                hscrollbarPolicy={Gtk.PolicyType.NEVER}
                maxContentHeight={360}
                propagateNaturalHeight
              >
                <box orientation={Gtk.Orientation.VERTICAL} class="popover">
                  <button
                    class="clear"
                    label={`Any ${group.label.toLowerCase()}`}
                    onClicked={(self: Gtk.Button) => {
                      (self.get_ancestor(Gtk.Popover) as Gtk.Popover)?.popdown();
                      setFilter(group.label, "");
                    }}
                  />
                  {group.tags.map((tag) => (
                    <button
                      class={filters((f) =>
                        f[group.label] === tag ? "selected" : "",
                      )}
                      label={tag}
                      onClicked={(self: Gtk.Button) => {
                        (self.get_ancestor(Gtk.Popover) as Gtk.Popover)?.popdown();
                        setFilter(group.label, tag);
                      }}
                    />
                  ))}
                </box>
              </scrolledwindow>
            </popover>
          </menubutton>
        ))}
        <togglebutton
          class="adult"
          label="18+"
          tooltipText="Include Mature and Questionable items"
          active={allowAdult((a) => a)}
          onToggled={({ active }) => {
            if (allowAdult.peek() === active) return;
            setAllowAdult(active);
            search(1);
          }}
        />
        <button
          class="clear-filters"
          label="Clear"
          tooltipText="Drop every filter"
          onClicked={() => {
            setFilters({});
            search(1);
          }}
        />
      </Gtk.FlowBox>

      <scrolledwindow vexpand hscrollbarPolicy={Gtk.PolicyType.NEVER}>
        <With value={items}>
          {(list) => (
            <Gtk.FlowBox
              columnSpacing={8}
              rowSpacing={8}
              homogeneous={true}
              selectionMode={Gtk.SelectionMode.NONE}
              minChildrenPerLine={COLUMNS}
              maxChildrenPerLine={COLUMNS}
            >
              {list.map(card)}
            </Gtk.FlowBox>
          )}
        </With>
      </scrolledwindow>

      <box spacing={8}>
        <label class="workshop-status" hexpand xalign={0} label={status((s) => s)} />
        <button
          label="‹"
          tooltipText="Previous page"
          sensitive={page((p) => p > 1)}
          onClicked={() => search(Math.max(1, page.peek() - 1))}
        />
        <button
          label="›"
          tooltipText="Next page"
          sensitive={busy((b) => !b)}
          onClicked={() => search(page.peek() + 1)}
        />
      </box>
    </box>
  );
}
