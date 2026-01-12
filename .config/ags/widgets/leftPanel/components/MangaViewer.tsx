import Gtk from "gi://Gtk?version=4.0";
import { execAsync } from "ags/process";
import { Manga, Chapter, Page } from "../../../interfaces/manga.interface";
import { createState, For, With } from "ags";
import { notify } from "../../../utils/notification";
import Picture from "../../Picture";
import { Progress } from "../../Progress";
import Pango from "gi://Pango?version=1.0";
import Gdk from "gi://Gdk?version=4.0";
import { globalSettings, globalTransition } from "../../../variables";

const [mangaList, setMangaList] = createState<Manga[]>([]);
const [selectedManga, setSelectedManga] = createState<Manga | null>(null);
const [chapters, setChapters] = createState<Chapter[]>([]);
const [selectedChapter, setSelectedChapter] = createState<Chapter | null>(null);
const [pages, setPages] = createState<Page[]>([]);
const [loadedPages, setLoadedPages] = createState<Page[]>([]);
const [currentTab, setCurrentTab] = createState<string>("Manga");
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");
const [searchQuery, setSearchQuery] = createState<string>("");
const [initialized, setInitialized] = createState(false);
const [bottomIsRevealed, setBottomIsRevealed] = createState<boolean>(false);

const scriptPath = "./scripts/manga.py";

const fetchPopular = async () => {
  setProgressStatus("loading");
  try {
    const output = await execAsync(
      `python3 ${scriptPath} --popular --limit 10`
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
      `python3 ${scriptPath} --search "${query}" --limit 10`
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
      `python3 ${scriptPath} --chapters --manga-id ${mangaId}`
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

const fetchPages = async (chapterId: string) => {
  try {
    setProgressStatus("loading");
    print(`python3 ${scriptPath} --pages --chapter-id ${chapterId}`);
    const output = await execAsync(
      `python3 ${scriptPath} --pages --chapter-id ${chapterId}`
    );
    const data = JSON.parse(output);
    setPages(data);
    setLoadedPages([]);
    setCurrentTab("Pages");
    setProgressStatus("success");
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
  }
};

const loadMorePages = async () => {
  try {
    setProgressStatus("loading");
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
    setProgressStatus("success");
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
  }
};

const fetchPage = async (pageUrl: string) => {
  setProgressStatus("loading");
  try {
    print(`python3 ${scriptPath} --page "${pageUrl}"`);
    const output = await execAsync(`python3 ${scriptPath} --page "${pageUrl}"`);
    const data = JSON.parse(output) as Page;
    print(data.url, data.path);
    setProgressStatus("success");
    return data;
  } catch (err) {
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
    return null;
  }
};

const MangaTab = () => (
  <scrolledwindow vexpand hexpand>
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
              <Picture
                file={manga.cover_path}
                height={globalSettings(({ leftPanel }) =>
                  manga.cover_width && manga.cover_height
                    ? (manga.cover_height / manga.cover_width) * leftPanel.width
                    : leftPanel.width
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
                  label={manga.description.substring(0, 100) + "..."}
                  wrap
                />
                <label
                  class={"tags"}
                  label={`Tags: ${manga.tags.slice(0, 3).join(", ")}`}
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
      <scrolledwindow vexpand hexpand>
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
    <scrolledwindow
      hexpand
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
              height={globalSettings(({ leftPanel }) =>
                page.width && page.height
                  ? (page.height / page.width) * leftPanel.width
                  : leftPanel.width
              )}
            />
          )}
        </For>
      </box>
    </scrolledwindow>
  </box>
);

const mangaApis = ["MangaDex", "WIP"];

const Tabs = () => (
  <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
    <box class="tab-list" spacing={5}>
      <togglebutton
        active={currentTab((tab) => tab === "Manga")}
        label="Manga"
        onToggled={({ active }) => active && setCurrentTab("Manga")}
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
    <box class="tab-list" spacing={5}>
      {mangaApis.map((api) => (
        <togglebutton
          hexpand
          label={api}
          // active={currentApi((current) => current === api)}
          // onToggled={({ active }) => active && setCurrentApi(api)}
        />
      ))}
    </box>
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

const Bottom = () => {
  const revealer = (
    <revealer
      class="bottom-revealer"
      transitionType={Gtk.RevealerTransitionType.SWING_UP}
      revealChild={bottomIsRevealed}
      transitionDuration={globalTransition}
    >
      <box
        class="bottom-bar"
        orientation={Gtk.Orientation.VERTICAL}
        spacing={10}
      >
        <entry
          placeholderText="Search manga..."
          text={searchQuery.get()}
          onActivate={() => searchManga(searchQuery.get())}
          $={(self) =>
            self.connect("changed", () => setSearchQuery(self.get_text()))
          }
        />
        <button
          label="Search"
          onClicked={() => searchManga(searchQuery.get())}
        />
        <button label="Popular" onClicked={() => fetchPopular()} />
      </box>
    </revealer>
  );

  // action box
  const actions = (
    <box class="actions" spacing={5}>
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
    <box class={"bottom"} orientation={Gtk.Orientation.VERTICAL}>
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
      spacing={5}
      $={(self) => {
        const keyController = new Gtk.EventControllerKey();
        keyController.connect("key-pressed", (_, keyval: number) => {
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
      <Progress status={progressStatus} />
      <Bottom />
      <Tabs />
    </box>
  );
};
