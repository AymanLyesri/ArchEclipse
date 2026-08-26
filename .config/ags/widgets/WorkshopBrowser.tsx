import { createState, With } from "ags";
import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib";
import Pango from "gi://Pango";
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

/// Results per page. Steam serves 50; a grid of 24 previews is what fits on
/// screen without making the popover a scrolling chore.
const PAGE_SIZE = 24;

/// Where downloaded preview thumbnails live.
const PREVIEW_DIR = `${GLib.get_user_cache_dir()}/ags/workshop-previews`;

const SORTS: { label: string; value: "popular" | "trend" | "recent" | "rated" }[] =
  [
    { label: "Popular", value: "popular" },
    { label: "Trending", value: "trend" },
    { label: "Newest", value: "recent" },
    { label: "Top rated", value: "rated" },
  ];

/// Type filters, which are Workshop tags like any other.
const KINDS = ["Scene", "Video", "Web"];

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
    await execAsync([
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
      item.preview,
    ]);
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
  const [kind, setKind] = createState<string>("");
  const [allowAdult, setAllowAdult] = createState<boolean>(false);
  const [page, setPage] = createState<number>(1);

  let query = "";

  const search = (nextPage = 1) => {
    setBusy(true);
    setPage(nextPage);
    setStatus(nextPage === 1 ? "searching…" : `page ${nextPage}…`);
    kirieWorkshopSearch({
      text: query,
      tags: kind.peek() ? [kind.peek()] : [],
      excludeTags: allowAdult.peek() ? [] : ADULT,
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
      widthRequest: 150,
      heightRequest: 84,
      cssClasses: ["workshop-preview"],
    });
    ensurePreview(item).then((path) => {
      if (path) preview.set_filename(path);
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
      widthRequest={700}
      heightRequest={520}
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

      <box spacing={6} class="workshop-filters">
        {KINDS.map((tag) => (
          <togglebutton
            label={tag}
            active={kind((k) => k === tag)}
            onToggled={({ active }) => {
              const next = active ? tag : "";
              if (kind.peek() === next) return;
              setKind(next);
              search(1);
            }}
          />
        ))}
        <box hexpand />
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
      </box>

      <scrolledwindow vexpand hscrollbarPolicy={Gtk.PolicyType.NEVER}>
        <With value={items}>
          {(list) => (
            <Gtk.FlowBox
              columnSpacing={8}
              rowSpacing={8}
              homogeneous={true}
              selectionMode={Gtk.SelectionMode.NONE}
              minChildrenPerLine={2}
              maxChildrenPerLine={4}
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
