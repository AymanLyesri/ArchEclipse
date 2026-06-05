import { Gtk } from "ags/gtk4";
import { execAsync } from "ags/process";
import { Manga, Chapter, Page } from "../../../interfaces/manga.interface";
import { createState, createComputed, For, With } from "ags";
import { notify } from "../../../utils/notification";
import Picture from "../../Picture";
import { Progress } from "../../Progress";
import Pango from "gi://Pango";
import { Gdk } from "ags/gtk4";
import { globalSettings, globalTransition } from "../../../variables";
import GLib from "gi://GLib";
import Gio from "gi://Gio";

const [mangaList, setMangaList] = createState<Manga[]>([]);
const [selectedManga, setSelectedManga] = createState<Manga | null>(null);
const [chapters, setChapters] = createState<Chapter[]>([]);
const [selectedChapter, setSelectedChapter] = createState<Chapter | null>(null);
const [pages, setPages] = createState<Page[]>([]);
const [pageCache, setPageCache] = createState<Record<number, Page>>({});
const [currentPageIndex, setCurrentPageIndex] = createState(0);
const [currentTab, setCurrentTab] = createState<string>("Manga");
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");
const [searchQuery, setSearchQuery] = createState<string>("");
const [initialized, setInitialized] = createState(false);
const [bottomIsRevealed, setBottomIsRevealed] = createState<boolean>(false);

const [currentApi, setCurrentApi] = createState<string>("mangadex");

const pageInfo = createComputed(() => {
  const all = pages();
  const idx = currentPageIndex();
  return {
    label: all.length > 0 ? `Page ${idx + 1} / ${all.length}` : "No pages",
    canPrev: idx > 0,
    canNext: all.length > 0 && idx < all.length - 1,
  };
});

const displayedPage = createComputed(
  () => pageCache()[currentPageIndex()] ?? null,
);

const panelWidth = createComputed(() => globalSettings().leftPanel.width);

const scriptPath = `${GLib.get_home_dir()}/.config/ags/scripts/manga.py`;

const getProviderFlag = () => `--provider ${currentApi.get()}`;

const getSortedChaptersList = (chaptersList: Chapter[]) => {
  return [...chaptersList]
    .sort((a, b) => {
      // 1. Sorting by volumes
      const volA = parseFloat(a.volume || "0");
      const volB = parseFloat(b.volume || "0");

      const isVolANum = !isNaN(volA);
      const isVolBNum = !isNaN(volB);

      if (isVolANum && isVolBNum && volA !== volB) {
        return volB - volA; // New volumes on top (in reverse order)
      }

      // 2. If the volumes are the same, sort by chapter numbers.
      const numA = parseFloat(a.chapter || "0");
      const numB = parseFloat(b.chapter || "0");

      const isNumA = !isNaN(numA);
      const isNumB = !isNaN(numB);

      if (isNumA && isNumB && numA !== numB) {
        return numB - numA; // New chapters on top
      }

      // 3. If the numbers match, check the alternative versions
      const titleA = a.title || "";
      const titleB = b.title || "";
      const numStrA = a.chapter || "";
      const numStrB = b.chapter || "";

      const isGenericA =
        !titleA ||
        titleA === `Глава ${numStrA}` ||
        titleA === `Chapter ${numStrA}`;
      const isGenericB =
        !titleB ||
        titleB === `Глава ${numStrB}` ||
        titleB === `Chapter ${numStrB}`;

      if (!isGenericA && isGenericB) return -1;
      if (isGenericA && !isGenericB) return 1;

      // 4. Sort by date
      if (a.publish_date && b.publish_date) {
        return (
          new Date(b.publish_date).getTime() -
          new Date(a.publish_date).getTime()
        );
      }

      return 0;
    })
    .map((chapter, index, array) => {
      // Alternative version: both the chapter number and the volume number match!
      const isAttachment =
        index > 0 &&
        array[index - 1].chapter === chapter.chapter &&
        array[index - 1].volume === chapter.volume &&
        chapter.chapter !== "";

      return {
        ...chapter,
        isAttachment,
      };
    });
};

const goToChapter = async (direction: "prev" | "next") => {
  const current = selectedChapter.get();
  if (!current) return;

  const list = getSortedChaptersList(chapters.get());
  const index = list.findIndex((c) => c.id === current.id);
  if (index === -1) return;

  const targetIndex = direction === "prev" ? index + 1 : index - 1;
  if (targetIndex < 0 || targetIndex >= list.length) return;

  const target = list[targetIndex];

  setSelectedChapter(target);
  await fetchPages(target.id);
};

const fetchPopular = async () => {
  setProgressStatus("loading");
  try {
    const output = await execAsync(
      `python3 ${scriptPath} ${getProviderFlag()} --popular --limit 10`,
    );
    const data = JSON.parse(output);
    setMangaList(data);
    setProgressStatus("success");
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
  }
};

const searchManga = async (query: string) => {
  setProgressStatus("loading");
  if (!query.trim()) return fetchPopular();
  try {
    const output = await execAsync(
      `python3 ${scriptPath} ${getProviderFlag()} --search "${query}" --limit 10`,
    );
    const data = JSON.parse(output);
    setMangaList(data);
    setProgressStatus("success");
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
  }
};

const fetchChapters = async (mangaId: string) => {
  try {
    setProgressStatus("loading");
    const output = await execAsync(
      `python3 ${scriptPath} ${getProviderFlag()} --chapters --manga-id ${mangaId}`,
    );
    const data = JSON.parse(output);
    setChapters(data);
    setCurrentTab("Chapters");
    setProgressStatus("success");
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
  }
};

const loadPageAt = async (
  index: number,
  quiet = false,
): Promise<Page | null> => {
  const allPages = pages.get();
  if (index < 0 || index >= allPages.length) return null;

  const cached = pageCache.get()[index];
  if (cached?.path) return cached;

  const fetched = await fetchPage(allPages[index].url, quiet);
  if (fetched) {
    setPageCache({ ...pageCache.get(), [index]: fetched });
    return fetched;
  }
  return null;
};

const navigateToPage = async (index: number) => {
  const total = pages.get().length;
  if (index < 0 || index >= total) return;

  setCurrentPageIndex(index);

  if (!pageCache.get()[index]?.path) {
    await loadPageAt(index);
    if (currentPageIndex.get() !== index) return;
  }

  if (index + 1 < total) loadPageAt(index + 1, true);
  if (index - 1 >= 0) loadPageAt(index - 1, true);
};

const goToPage = (direction: "prev" | "next") => {
  const index = currentPageIndex.get();
  const target = direction === "next" ? index + 1 : index - 1;
  navigateToPage(target);
};

const fetchPages = async (chapterId: string) => {
  try {
    setProgressStatus("loading");
    const output = await execAsync(
      `python3 ${scriptPath} ${getProviderFlag()} --pages --chapter-id ${chapterId}`,
    );
    const data = JSON.parse(output);

    setPages(data);
    setPageCache({});
    setCurrentPageIndex(0);
    setCurrentTab("Pages");

    if (data?.length > 0) {
      await navigateToPage(0);
    }

    setProgressStatus("success");
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
  }
};

const fetchPage = async (pageUrl: string, quiet = false) => {
  if (!quiet) setProgressStatus("loading");
  try {
    const output = await execAsync(
      `python3 ${scriptPath} ${getProviderFlag()} --page "${pageUrl}"`,
    );
    const data = JSON.parse(output) as Page;
    if (!quiet) setProgressStatus("success");
    return data;
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    if (!quiet) setProgressStatus("error");
    return null;
  }
};

const MangaTab = () => (
  <scrolledwindow vexpand hexpand>
    <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      <For each={mangaList}>
        {(manga) => (
          <button
            class="manga-item"
            onClicked={() => {
              setSelectedManga(manga);
              fetchChapters(manga.id);
            }}
          >
            <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
              <Picture
                file={manga.cover_path}
                height={globalSettings(({ leftPanel }) =>
                  manga.cover_width && manga.cover_height
                    ? (manga.cover_height / manga.cover_width) * leftPanel.width
                    : leftPanel.width,
                )}
              />
              <box
                class={"manga-info"}
                orientation={Gtk.Orientation.VERTICAL}
                spacing={2}
              >
                <label
                  class={"title"}
                  label={manga.title}
                  ellipsize={Pango.EllipsizeMode.END}
                />
                <label
                  class={"description"}
                  label={
                    manga.description
                      ? manga.description.substring(0, 100) + "..."
                      : "No description"
                  }
                  wrap
                />
                <label
                  class={"tags"}
                  label={`Tags: ${manga.tags ? manga.tags.slice(0, 3).join(", ") : "N/A"}`}
                  ellipsize={Pango.EllipsizeMode.END}
                />
              </box>
            </box>
          </button>
        )}
      </For>
    </box>
  </scrolledwindow>
);

const ChaptersTab = () => {
  // 1. Smart formatting of titles
  const formatChapterLabel = (
    chapter: Chapter & { isAttachment?: boolean },
  ) => {
    const num = chapter.chapter;
    const vol = chapter.volume ? `Vol. ${chapter.volume} ` : "";
    const title = chapter.title?.trim();

    if (chapter.isAttachment) {
      // If this is an attachment and it has a default name, we write a placeholder
      if (!title || title === `Chapter ${num}` || title === `Глава ${num}`) {
        return "↳ Alternative version";
      }
      return `↳ ${title}`;
    }

    // Logic for the main chapters
    if (!num) return title || "Unknown Chapter";

    if (!title || title === `Chapter ${num}` || title === `Глава ${num}`) {
      return `${vol}Chapter ${num}`;
    }
    if (title.includes(`Chapter ${num}`) || title.includes(`Глава ${num}`)) {
      return `${vol}${title}`;
    }

    return `${vol}Chapter ${num}: ${title}`;
  };

  // 2. Sorting, grouping and marking attachments
  const sortedChapters = chapters((chaptersList) => {
    return getSortedChaptersList(chaptersList);
  });

  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      {selectedManga && (
        <label label={`Chapters for: ${selectedManga.get()!.title}`} />
      )}
      <scrolledwindow vexpand hexpand>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          <For each={sortedChapters}>
            {(chapter) => (
              // A box wrapper with left indentation nicely shifts the nesting
              <box marginStart={chapter.isAttachment ? 25 : 0} hexpand>
                <button
                  class={
                    chapter.isAttachment
                      ? "chapter-item chapter-child"
                      : "chapter-item"
                  }
                  label={formatChapterLabel(chapter)}
                  hexpand
                  onClicked={() => {
                    fetchPages(chapter.id);
                    setSelectedChapter(chapter);
                  }}
                />
              </box>
            )}
          </For>
        </box>
      </scrolledwindow>
    </box>
  );
};

// Compute the display height for a manga page image.
//
// Strategy: always scale proportionally to the panel width so the image
// fills the full available width. CONTAIN is then used so GTK never
// distorts the aspect ratio — it simply renders the image inside the
// exact bounding box we provide.
//
// Wide pages (imgW > imgH): scaledH < panelWidth → image fits in one screen.
// Tall pages (imgH >> imgW): scaledH >> panelWidth → ScrolledWindow lets user scroll.
//
// Returns -1 if pixel dimensions cannot be read (GTK falls back to natural size).
const getPageHeight = (path: string): number => {
  try {
    const file = Gio.File.new_for_path(path);
    const texture = Gdk.Texture.new_from_file(file);
    if (!texture) return -1;
    const imgW = texture.get_width();
    const imgH = texture.get_height();
    if (imgW <= 0 || imgH <= 0) return -1;
    const containerW = panelWidth.get();
    // Scale height proportionally: h = (imgH / imgW) * containerW
    return Math.round((imgH / imgW) * containerW);
  } catch {
    return -1;
  }
};

const PagesTab = () => (
  <box
    class="pages-view"
    orientation={Gtk.Orientation.VERTICAL}
    vexpand
    hexpand
    $={() => {
      const idx = currentPageIndex.get();
      if (pages.get().length > 0 && !pageCache.get()[idx]?.path) {
        navigateToPage(idx);
      }
    }}
  >
    {/*
     * Use Gtk.ScrolledWindow (capital S) — the correct AGS/GTK4 JSX tag.
     * Picture receives `file` and `height` as plain props so the overlay
     * wrapper inside Picture.tsx sizes correctly without needing `$` hacks.
     * Height is recomputed from pixel aspect ratio so tall vertical pages
     * fill the full width and scroll, while wide pages fit normally.
     */}
    <Gtk.ScrolledWindow
      vexpand
      hexpand
      vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
      hscrollbarPolicy={Gtk.PolicyType.NEVER}
      $={(scroll) => {
        // Reset to top on every page change
        const unsub = currentPageIndex.subscribe(() => {
          const adj = scroll.get_vadjustment();
          if (adj) adj.set_value(0);
        });
        scroll.connect("destroy", () => unsub());
      }}
    >
      <With value={displayedPage}>
        {(page) => {
          if (!page?.path) {
            return <label class="page-loading" label="Loading page..." />;
          }

          // Derive height reactively so it updates when the page changes
          const scaledHeight = displayedPage((p) =>
            p?.path ? getPageHeight(p.path) : -1
          );

          return (
            <Picture
              file={displayedPage((p) => p?.path ?? "")}
              height={scaledHeight}
              contentFit={Gtk.ContentFit.CONTAIN}
            />
          );
        }}
      </With>
    </Gtk.ScrolledWindow>
    <label class="page-counter" label={pageInfo((info) => info.label)} />
  </box>
);

const PageNavigation = () => (
  <box
    class="page-navigation"
    orientation={Gtk.Orientation.VERTICAL}
    spacing={5}
    visible={currentTab((tab) => tab === "Pages")}
  >
    <box spacing={10}>
      <button
        label="◀ Previous Page"
        hexpand
        sensitive={pageInfo((info) => info.canPrev)}
        onClicked={() => goToPage("prev")}
      />
      <button
        label="Next Page ▶"
        hexpand
        sensitive={pageInfo((info) => info.canNext)}
        onClicked={() => goToPage("next")}
      />
    </box>
  </box>
);

const ChapterNavigation = () => (
  <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
    <box spacing={10}>
      <button
        label="◀ Previous Chapter" // Symbols Examples: ◀ ,  ,  ,  , ←
        hexpand
        sensitive={selectedChapter((c) => c !== null)}
        onClicked={() => goToChapter("prev")}
      />

      <button
        label="Next Chapter ▶" // Symbols Examples: ▶ ,  ,  , , →
        hexpand
        sensitive={selectedChapter((c) => c !== null)}
        onClicked={() => goToChapter("next")}
      />
    </box>

    <label
      useMarkup
      class="current-chapter"
      sensitive={selectedChapter((c) => c !== null)}
      hexpand
      ellipsize={Pango.EllipsizeMode.END}
      xalign={0.5}
      label={selectedChapter((chapter) => {
        if (!chapter) return "<b>No chapter selected</b>";

        const vol = chapter.volume ? `Vol. ${chapter.volume} ` : "";
        const num = chapter.chapter || "?";
        const title = chapter.title?.trim();

        if (!title || title === `Chapter ${num}` || title === `Volume ${num}`)
          return `<b>${vol}Chapter ${num}</b>`;

        return `<b>${vol}Chapter ${num}: ${title}</b>`;
      })}
    />
  </box>
);

// Build a real browser URL from current state depending on the active provider.
// MangaDex manga:   https://mangadex.org/title/{uuid}/{slug}
// MangaDex chapter: https://mangadex.org/chapter/{chapterUuid}
// MangaLib manga:   https://mangalib.org/ru/manga/{slug}
// MangaLib chapter: https://mangalib.org/ru/{mangaSlug}/read/v{volume}/c{chapter}
const buildUrl = (
  api: string,
  manga: ReturnType<typeof selectedManga.get>,
  chapter: ReturnType<typeof selectedChapter.get>,
): string => {
  if (api === "mangadex") {
    if (chapter) {
      return `https://mangadex.org/chapter/${chapter.id}`;
    }
    if (manga) {
      const slug = manga.title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "");
      return `https://mangadex.org/title/${manga.id}/${slug}`;
    }
    return "https://mangadex.org";
  }

  if (api === "mangalib") {
    if (chapter) {
      // Parse the format ID: {mangaSlug}/v{volume}/c{chapterNum}
      const parts = chapter.id.split("/");
      let mangaSlug = parts[0];

      // MangaLib requires a clean slug WITHOUT "ID--" in the read URL (e.g. just "wind-breaker")
      if (mangaSlug.includes("--")) {
        mangaSlug = mangaSlug.split("--")[1];
      }

      // Extract pure numeric values ​​of volume and chapter
      const rawVol =
        chapter.volume || (parts[1] ? parts[1].replace("v", "") : "1");
      const rawCh =
        chapter.chapter || (parts[2] ? parts[2].replace("c", "") : "0");

      return `https://mangalib.org/ru/${mangaSlug}/read/v${rawVol}/c${rawCh}`;
    }
    if (manga) {
      return `https://mangalib.org/ru/manga/${manga.id}`;
    }
    return "https://mangalib.org";
  }

  return "";
};

const UrlBar = () => {
  const getUrl = () => {
    try {
      return buildUrl(
        currentApi.get(),
        selectedManga.get(),
        selectedChapter.get(),
      );
    } catch (e) {
      notify({ summary: "Error", body: String(e) });
      return "";
    }
  };

  return (
    <box class="url-bar" spacing={5}>
      <label
        class="url-label"
        hexpand
        xalign={0}
        ellipsize={Pango.EllipsizeMode.END}
        label={getUrl()}
        $={(self) => {
          try {
            currentApi.subscribe(() => {
              self.label = getUrl();
            });
            selectedManga.subscribe(() => {
              self.label = getUrl();
            });
            selectedChapter.subscribe(() => {
              self.label = getUrl();
            });
          } catch (e) {
            notify({ summary: "Error", body: String(e) });
          }
        }}
      />
      <button
        class="url-copy-button"
        label="󰆏 Copy" // Symbols Examples: 󰆏 ,  , ⎘
        onClicked={() => {
          const url = getUrl();
          execAsync(
            `bash -c "echo -n '${url}' | wl-copy 2>/dev/null || echo -n '${url}' | xclip -selection clipboard"`,
          ).catch((err) => notify({ summary: "Error", body: String(err) }));
        }}
      />
    </box>
  );
};

const Sections = () => (
  <box class="tab-list" spacing={10}>
    <togglebutton
      active={currentTab((tab) => tab === "Manga")}
      label="Manga"
      onToggled={({ active }) => active && setCurrentTab("Manga")}
      hexpand
    />
    <togglebutton
      active={currentTab((tab) => tab === "Chapters")}
      label="Chapters"
      sensitive={selectedManga((manga) => manga !== null)}
      onToggled={({ active }) =>
        active && selectedManga.get() && setCurrentTab("Chapters")
      }
      hexpand
    />
    <togglebutton
      active={currentTab((tab) => tab === "Pages")}
      label="Pages"
      sensitive={selectedChapter((chapter) => chapter !== null)}
      onToggled={({ active }) =>
        active && selectedChapter.get() && setCurrentTab("Pages")
      }
      hexpand
    />
  </box>
);

const mangaApis = [
  { label: "MangaDex", id: "mangadex" },
  { label: "MangaLib", id: "mangalib" },
];

const Tabs = () => (
  <box class="tab-list" spacing={10}>
    {mangaApis.map((api) => (
      <togglebutton
        hexpand
        label={api.label}
        active={currentApi((current) => current === api.id)}
        onToggled={({ active }) => {
          if (active && currentApi.get() !== api.id) {
            setCurrentApi(api.id);
            setSelectedManga(null);
            setSelectedChapter(null);
            setChapters([]);
            setPages([]);
            setPageCache({});
            setCurrentPageIndex(0);
            setCurrentTab("Manga");
            fetchPopular();
          }
        }}
      />
    ))}
  </box>
);

const Content = () => {
  return (
    <box class="content">
      <With value={currentTab}>
        {(tab) => {
          switch (tab) {
            case "Manga":
              return MangaTab();
            case "Chapters":
              return ChaptersTab();
            case "Pages":
              return PagesTab();
            default:
              return MangaTab();
          }
        }}
      </With>
    </box>
  );
};

const Actions = () => {
  const revealer = (
    <revealer
      class="revealer"
      transitionType={Gtk.RevealerTransitionType.SWING_UP}
      revealChild={bottomIsRevealed}
      transitionDuration={globalTransition}
    >
      <box class="options" orientation={Gtk.Orientation.VERTICAL} spacing={10}>
        <entry
          placeholderText="Search manga..."
          text={searchQuery.get()}
          onActivate={() => searchManga(searchQuery.get())}
          $={(self) =>
            self.connect("changed", () => setSearchQuery(self.get_text()))
          }
        />
        <button
          label=" Search" // Symbols Examples:  , 🔍
          onClicked={() => searchManga(searchQuery.get())}
        />
        <button label=" Popular" onClicked={() => fetchPopular()} />
        {/* Symbols Examples:  ,  , ☆ ,  */}
      </box>
    </revealer>
  );

  // action box
  const actions = (
    <box class="navigation" spacing={10}>
      <button
        hexpand
        class="reveal-button"
        label={bottomIsRevealed((revealed) => (!revealed ? "" : ""))}
        onClicked={(self) => {
          setBottomIsRevealed(!bottomIsRevealed.get());
        }}
      />
    </box>
  );

  return (
    <box class={"actions"} orientation={Gtk.Orientation.VERTICAL}>
      {actions}
      {revealer}
    </box>
  );
};

export default () => {
  if (!initialized.get()) {
    setInitialized(true);
    fetchPopular();
  }
  return (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      class="manga-viewer"
      spacing={10}
      $={(self) => {
        const keyController = new Gtk.EventControllerKey();
        keyController.connect("key-pressed", (_, keyval: number) => {
          if (currentTab.get() === "Pages") {
            if (keyval === Gdk.KEY_Left) {
              goToPage("prev");
              return true;
            }
            if (keyval === Gdk.KEY_Right) {
              goToPage("next");
              return true;
            }
          }
          if (keyval === Gdk.KEY_Up && !bottomIsRevealed.get()) {
            setBottomIsRevealed(true);
            return true;
          }
          if (keyval === Gdk.KEY_Down && bottomIsRevealed.get()) {
            setBottomIsRevealed(false);
            return true;
          }
          return false;
        });
        self.add_controller(keyController);
      }}
    >
      <Content />
      <box
        class={"bottom-bar"}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
      >
        <Actions />
        <PageNavigation />
        <ChapterNavigation />
        <UrlBar />
        <Sections />
        <Tabs />
      </box>
      <Progress status={progressStatus} />
    </box>
  );
};
