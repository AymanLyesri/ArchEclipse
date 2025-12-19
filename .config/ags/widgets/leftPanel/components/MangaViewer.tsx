import Gtk from "gi://Gtk?version=4.0";
import { exec, execAsync } from "ags/process";
import { Manga, Chapter, Page } from "../../../interfaces/manga.interface";
import { createComputed, createState, For, With } from "ags";
import { notify } from "../../../utils/notification";
import Picture from "../../Picture";
import { Progress } from "../../Progress";
import Pango from "gi://Pango?version=1.0";
import { load } from "mime";
import { leftPanelWidth } from "../../../variables";

const [mangaList, setMangaList] = createState<Manga[]>([]);
const [selectedManga, setSelectedManga] = createState<Manga | null>(null);
const [chapters, setChapters] = createState<Chapter[]>([]);
const [selectedChapter, setSelectedChapter] = createState<Chapter | null>(null);
const [pages, setPages] = createState<Page[]>([]);
const [loadedPages, setLoadedPages] = createState<Page[]>([]);
const [currentTab, setCurrentTab] = createState<string>("Providers");
const [isLoading, setIsLoading] = createState<boolean>(false);
const [searchQuery, setSearchQuery] = createState<string>("");
const [initialized, setInitialized] = createState(false);

const scriptPath = "/home/ayman/.config/ags/scripts/manga.py";

const fetchPopular = async () => {
  setIsLoading(true);
  try {
    const output = await execAsync(`python3 ${scriptPath} --popular --limit 5`);
    const data = JSON.parse(output);
    setMangaList(data);
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
  } finally {
    setIsLoading(false);
  }
};

const searchManga = async (query: string) => {
  if (!query.trim()) return fetchPopular();
  setIsLoading(true);
  try {
    const output = await execAsync(
      `python3 ${scriptPath} --search "${query}" --limit 5`
    );
    const data = JSON.parse(output);
    setMangaList(data);
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
  } finally {
    setIsLoading(false);
  }
};

const fetchChapters = async (mangaId: string) => {
  setIsLoading(true);
  try {
    const output = await execAsync(
      `python3 ${scriptPath} --chapters --manga-id ${mangaId}`
    );
    const data = JSON.parse(output);
    setChapters(data);
    setCurrentTab("Chapters");
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
  } finally {
    setIsLoading(false);
  }
};

const fetchPages = async (chapterId: string) => {
  setIsLoading(true);
  try {
    print(`python3 ${scriptPath} --pages --chapter-id ${chapterId}`);
    const output = await execAsync(
      `python3 ${scriptPath} --pages --chapter-id ${chapterId}`
    );
    const data = JSON.parse(output);
    print(data);
    setPages(data);
    setLoadedPages([]);
    setCurrentTab("Pages");
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
  } finally {
    setIsLoading(false);
  }
};

const loadMorePages = async () => {
  try {
    const currentLoaded = loadedPages.get();
    const allPages = pages.get();

    const nextPages = allPages.slice(
      currentLoaded.length,
      currentLoaded.length + 5
    );

    print(allPages.length, currentLoaded.length, nextPages.length);

    if (nextPages.length === 0) return;
    const newLoaded = [];
    for (const page of nextPages) {
      const fetchedPage = await fetchPage(page.url);
      if (fetchedPage) {
        newLoaded.push(fetchedPage);
      }
    }
    setLoadedPages([...currentLoaded, ...newLoaded]);
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
  }
};

const fetchPage = async (pageUrl: string) => {
  setIsLoading(true);
  try {
    print(`python3 ${scriptPath} --page "${pageUrl}"`);
    const output = await execAsync(`python3 ${scriptPath} --page "${pageUrl}"`);
    const data = JSON.parse(output) as Page;
    print(data.url, data.path);
    return data;
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    return null;
  } finally {
    setIsLoading(false);
  }
};

const ProvidersTab = () => (
  <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
    <entry
      placeholderText="Search manga..."
      text={searchQuery.get()}
      onActivate={() => searchManga(searchQuery.get())}
      $={(self) =>
        self.connect("changed", () => setSearchQuery(self.get_text()))
      }
    />
    <button label="Search" onClicked={() => searchManga(searchQuery.get())} />
    <button label="Popular" onClicked={() => fetchPopular()} />
    <scrolledwindow vexpand>
      <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
        <For each={mangaList}>
          {(manga) => (
            <button
              class="manga-item"
              onClicked={() => {
                setSelectedManga(manga);
                fetchChapters(manga.id);
              }}
            >
              <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
                <Picture file={manga.cover_path} width={150} height={200} />
                <label
                  label={manga.title}
                  halign={Gtk.Align.START}
                  ellipsize={Pango.EllipsizeMode.END}
                />
                <label
                  label={manga.description.substring(0, 100) + "..."}
                  halign={Gtk.Align.START}
                  wrap
                />
                <label
                  label={`Tags: ${manga.tags.slice(0, 3).join(", ")}`}
                  halign={Gtk.Align.START}
                  ellipsize={Pango.EllipsizeMode.END}
                />
              </box>
            </button>
          )}
        </For>
      </box>
    </scrolledwindow>
  </box>
);

const ChaptersTab = () => {
  // sort by publish_date descending if available
  const sortedChapters = chapters((chapters) => {
    return [...chapters].sort((a, b) => {
      if (a.publish_date && b.publish_date) {
        return (
          new Date(b.publish_date).getTime() -
          new Date(a.publish_date).getTime()
        );
      }
      return 0;
    });
  });
  return (
    <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
      {selectedManga && (
        <label label={`Chapters for: ${selectedManga.get()!.title}`} />
      )}
      <scrolledwindow vexpand>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          <For each={sortedChapters}>
            {(chapter) => (
              <button
                class="chapter-item"
                label={`Ch. ${chapter.chapter || "N/A"} - ${chapter.title}`}
                onClicked={() => {
                  fetchPages(chapter.id);
                  setSelectedChapter(chapter);
                }}
              />
            )}
          </For>
        </box>
      </scrolledwindow>
    </box>
  );
};

const PagesTab = () => (
  <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
    {selectedChapter && (
      <label
        label={`Pages for: Ch. ${selectedChapter.get()!.chapter || "N/A"}`}
      />
    )}
    <scrolledwindow
      vexpand
      $={(self: any) => {
        loadMorePages();
        self.connect("edge-reached", (sw: any, pos: any) => {
          if (pos === Gtk.PositionType.BOTTOM) {
            loadMorePages();
          }
        });
      }}
    >
      <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
        <For each={loadedPages}>
          {(page) => (
            <Picture
              file={page.path || ""}
              // width={page.width}
              height={leftPanelWidth((width: number) =>
                page.width && page.height
                  ? (page.height / page.width) * width
                  : width
              )}
            />
          )}
        </For>
      </box>
    </scrolledwindow>
  </box>
);

const Tabs = () => (
  <box class="tab-list" spacing={5}>
    <togglebutton
      active={currentTab((tab) => tab === "Providers")}
      label="Providers"
      onToggled={({ active }) => active && setCurrentTab("Providers")}
    />
    <togglebutton
      active={currentTab((tab) => tab === "Chapters")}
      label="Chapters"
      sensitive={selectedManga((manga) => manga !== null)}
      onToggled={({ active }) =>
        active && selectedManga.get() && setCurrentTab("Chapters")
      }
    />
    <togglebutton
      active={currentTab((tab) => tab === "Pages")}
      label="Pages"
      sensitive={selectedChapter((chapter) => chapter !== null)}
      onToggled={({ active }) =>
        active && selectedChapter.get() && setCurrentTab("Pages")
      }
    />
  </box>
);

const Content = () => {
  return (
    <With value={currentTab}>
      {(tab) => {
        switch (tab) {
          case "Providers":
            return ProvidersTab();
          case "Chapters":
            return ChaptersTab();
          case "Pages":
            return PagesTab();
          default:
            return ProvidersTab();
        }
      }}
    </With>
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
    >
      <Tabs />
      <Progress revealed={isLoading} text={""} />
      <Content />
    </box>
  );
};
