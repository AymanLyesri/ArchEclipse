import { Gtk } from "ags/gtk4";
import { BooruImage } from "../../../class/BooruImage";
import { execAsync } from "ags/process";
import {
  globalSettings,
  globalTransition,
  setGlobalSetting,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { createState, createComputed, For, With, Accessor } from "ags";
import { booruApis } from "../../../constants/api.constants";
import { Gdk } from "ags/gtk4";
import Gio from "gi://Gio";
import { Progress } from "../../Progress";
import { booruPath } from "../../../constants/path.constants";
import Adw from "gi://Adw";
import Pango from "gi://Pango";
import GLib from "gi://GLib";

type BooruErrorEnvelope = {
  error?: boolean;
  code?: string;
  message?: string;
};

const booruScriptPath = `${GLib.get_home_dir()}/.config/ags/scripts/booru.py`;

const formatBooruError = (envelope: BooruErrorEnvelope) => {
  return envelope.message?.trim() || "Unknown booru error";
};

const parseJson = (raw: string): unknown => {
  return JSON.parse(raw) as unknown;
};

const parseBooruArrayResponse = <T,>(
  raw: string,
  invalidFormatMessage: string,
): T[] => {
  if (!raw?.trim()) {
    throw new Error("Received empty response from booru script");
  }

  let parsed: unknown;
  try {
    parsed = parseJson(raw);
  } catch {
    throw new Error(`${invalidFormatMessage}: ${raw.trim()}`);
  }

  if (
    typeof parsed === "object" &&
    parsed !== null &&
    "error" in parsed &&
    (parsed as BooruErrorEnvelope).error === true
  ) {
    throw new Error(formatBooruError(parsed as BooruErrorEnvelope));
  }

  if (!Array.isArray(parsed)) {
    throw new Error(invalidFormatMessage);
  }

  return parsed as T[];
};

const booruErrorMessageFromUnknown = (
  err: unknown,
  fallback: string,
): string => {
  const primary =
    err instanceof Error ? err.message?.trim() : String(err ?? "").trim();
  const text = primary || String(err ?? "").trim();

  if (!text) return fallback;

  try {
    const parsed = parseJson(text);
    if (
      typeof parsed === "object" &&
      parsed !== null &&
      "error" in parsed &&
      (parsed as BooruErrorEnvelope).error === true
    ) {
      return formatBooruError(parsed as BooruErrorEnvelope);
    }
  } catch {
    // Non-JSON error text
  }

  return text;
};

const [images, setImages] = createState<BooruImage[]>([]);
const [cacheSize, setCacheSize] = createState<string>("0kb");
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");
const [fetchedTags, setFetchedTags] = createState<string[]>([]);

const [selectedTab, setSelectedTab] = createState<string>("");
const [scrolledWindow, setScrolledWindow] =
  createState<Gtk.ScrolledWindow | null>(null);

const [bottomIsRevealed, setBottomIsRevealed] = createState<boolean>(false);

const [page, setPage] = createState<number>(1);
const [pageStack, setPageStack] = createState<Gtk.Stack | null>(null);
const [pageDirection, setPageDirection] = createState<"next" | "prev">("next");
const [tags, setTags] = createState<string[]>([]);
const [limit, setLimit] = createState<number>(100);

const calculateCacheSize = async () => {
  try {
    const res = await execAsync(
      `bash -c "du -sb ${booruPath}/${
        globalSettings.peek().booru.api.value
      }/previews | cut -f1"`,
    );
    // Convert bytes to megabytes
    setCacheSize(`${Math.round(Number(res) / (1024 * 1024))}mb`);
  } catch (err) {
    console.error("Error calculating cache size:", err);
    const errorMessage = err instanceof Error ? err.message : String(err);
    notify({
      summary: "Error calculating cache size",
      body: errorMessage,
    });
    setCacheSize("0mb");
  }
};

const ensureRatingTagFirst = () => {
  let tags: string[] = globalSettings.peek().booru.tags;
  // Find existing rating tag
  const ratingTag = tags.find((tag) =>
    tag.match(/[-]rating:explicit|rating:explicit/),
  );
  // Remove any existing rating tag
  tags = tags.filter((tag) => !tag.match(/[-]rating:explicit|rating:explicit/));
  // Add the previous rating tag at the beginning, or default to "-rating:explicit"
  tags.unshift(ratingTag ?? "-rating:explicit");
  setGlobalSetting("booru.tags", tags);
};

const cleanUp = () => {
  const promises = [
    execAsync(
      `bash -c "rm -rf ${booruPath}/${
        globalSettings.peek().booru.api.value
      }/previews/*"`,
    ),
    execAsync(
      `bash -c "rm -rf ${booruPath}/${
        globalSettings.peek().booru.api.value
      }/images/*"`,
    ),
  ];

  Promise.all(promises)
    .then(() => {
      notify({ summary: "Success", body: "Cache cleared successfully" });
      calculateCacheSize();
    })
    .catch((err) => {
      console.error("Error clearing cache:", err);
      const errorMessage = err instanceof Error ? err.message : String(err);
      notify({
        summary: "Error clearing cache",
        body: `Failed to clear cache: ${errorMessage}`,
      });
    });
};
const fetchImages = async () => {
  try {
    setProgressStatus("loading");

    const settings = globalSettings.peek();
    const limit = settings.booru.limit;
    const currentPage = Math.max(1, settings.booru.page);
    const startIndex = limit > 0 ? (currentPage - 1) * limit : 0;

    let imagesToDisplay: BooruImage[] = [];

    // Determine source: bookmarks or API
    if (selectedTab.peek() === "Bookmarks") {
      // Fetch bookmarks from backend
      const response = await execAsync([
        "python",
        booruScriptPath,
        "--action",
        "list-bookmarks",
      ]);
      const bookmarks = parseBooruArrayResponse<any>(
        response,
        "Invalid response format from bookmark list",
      );
      BooruImage.syncBookmarkCache(bookmarks);
      setGlobalSetting("booru.bookmarks", bookmarks);

      // Apply pagination
      const pagedBookmarks =
        limit > 0 ? bookmarks.slice(startIndex, startIndex + limit) : bookmarks;
      imagesToDisplay = pagedBookmarks.map((b: any) => new BooruImage(b));
    } else {
      // Fetch from API
      const apiValue = settings.booru.api.value;
      const credentials =
        settings.apiKeys[apiValue as keyof typeof settings.apiKeys];

      const args = [
        "python",
        booruScriptPath,
        "--api",
        apiValue,
        "--tags",
        settings.booru.tags.join(","),
        "--limit",
        String(settings.booru.limit),
        "--page",
        String(settings.booru.page),
      ];

      if (credentials?.user.value && credentials?.key.value) {
        args.push(
          "--api-user",
          credentials.user.value,
          "--api-key",
          credentials.key.value,
        );
      }

      const res = await execAsync(args);
      const jsonData = parseBooruArrayResponse<any>(
        res,
        "Invalid response format from booru API",
      );

      imagesToDisplay = jsonData.map(
        (img: any) =>
          new BooruImage({
            ...img,
            api: settings.booru.api,
          }),
      );
    }

    // Download all previews in parallel (unified for both sources)
    await Promise.all(
      imagesToDisplay.map(async (img) => {
        const previewDir = `${booruPath}/${img.api.value}/previews`;
        const filePath = `${previewDir}/${img.id}.${img.extension}`;

        await execAsync(`mkdir -p "${previewDir}"`);

        try {
          await execAsync(`test -f "${filePath}"`);
        } catch {
          await execAsync(`curl -sSf -o "${filePath}" "${img.preview}"`);
        }
      }),
    );

    setImages(imagesToDisplay);
    calculateCacheSize();
    setProgressStatus("success");
  } catch (err) {
    console.error(err);
    const errorMessage =
      selectedTab.peek() === "Bookmarks"
        ? booruErrorMessageFromUnknown(err, "Failed to load bookmarks")
        : booruErrorMessageFromUnknown(err, "Failed to fetch images");
    notify({
      summary:
        selectedTab.peek() === "Bookmarks"
          ? "Error loading bookmarks"
          : "Error fetching images",
      body: errorMessage,
    });
    setProgressStatus("error");
  }
};

const Tabs = () => (
  <box class="tab-list" spacing={5}>
    {booruApis.map((api) => (
      <togglebutton
        hexpand
        active={selectedTab((tab) => tab === api.name)}
        class="api"
        label={api.name}
        onToggled={({ active }) => {
          if (active) {
            setGlobalSetting("booru.api", api);
            setSelectedTab(api.name);
            setGlobalSetting("booru.selectedTab", api.name);
            fetchImages();
          }
        }}
      />
    ))}
    <togglebutton
      class="bookmarks"
      label=""
      active={selectedTab((tab) => tab === "Bookmarks")}
      onToggled={({ active }) => {
        if (active) {
          setSelectedTab("Bookmarks");
          setGlobalSetting("booru.selectedTab", "Bookmarks");
          fetchImages();
        }
      }}
    />
  </box>
);

const fetchTags = async (tag: string) => {
  try {
    const settings = globalSettings.peek();
    const apiValue = settings.booru.api.value;
    const credentials =
      settings.apiKeys[apiValue as keyof typeof settings.apiKeys];

    const args = ["python", booruScriptPath, "--api", apiValue, "--tag", tag];

    if (credentials?.user.value && credentials?.key.value) {
      args.push(
        "--api-user",
        credentials.user.value,
        "--api-key",
        credentials.key.value,
      );
    }

    const res = await execAsync(args);
    const jsonData = parseBooruArrayResponse<string>(
      res,
      "Invalid response format from tag search",
    );
    setFetchedTags(jsonData);
  } catch (err) {
    console.error("Error fetching tags:", err);
    const errorMessage = booruErrorMessageFromUnknown(
      err,
      "Failed to fetch tags",
    );
    notify({
      summary: "Error fetching tags",
      body: errorMessage,
    });
    setFetchedTags([]);
  }
};

const showImagesPage = (
  imagesWidget: Gtk.Widget,
  direction: "next" | "prev",
) => {
  const stack = pageStack.get();
  if (!stack) return;

  stack.set_transition_type(
    direction === "next"
      ? Gtk.StackTransitionType.SLIDE_LEFT
      : Gtk.StackTransitionType.SLIDE_RIGHT,
  );

  const name = `page-${Date.now()}`;
  stack.add_named(imagesWidget, name);
  stack.set_visible_child_name(name);
};

const createImagesContent = () => {
  function masonry(images: BooruImage[], columnsCount: number) {
    const columns = Array.from({ length: columnsCount }, () => ({
      height: 0,
      items: [] as BooruImage[],
    }));

    for (const image of images) {
      const ratio = image.height / image.width;
      const target = columns.reduce((a, b) => (a.height < b.height ? a : b));

      target.items.push(image);
      target.height += ratio;
    }

    return columns.map((c) => c.items);
  }

  const currentImages = images.peek();
  const columns = globalSettings.peek().booru.columns;
  const imageColumns = masonry(currentImages, columns);
  const columnWidth =
    globalSettings.peek().leftPanel.width / imageColumns.length - 10;

  // Create scrolled window element
  const scrolled = (
    <scrolledwindow hexpand vexpand>
      <box class={"images"} spacing={5}>
        {imageColumns.map((column) => (
          <box orientation={Gtk.Orientation.VERTICAL} spacing={5} hexpand>
            {column.map((image: BooruImage) => {
              return image.renderAsImageDialog({
                columnWidth,
              });
            })}
          </box>
        ))}
      </box>
    </scrolledwindow>
  ) as Gtk.ScrolledWindow;

  setScrolledWindow(scrolled);

  return scrolled;
};

const Images = () => {
  return (
    <stack
      transitionDuration={globalTransition}
      hexpand
      vexpand
      $={(self) => {
        setPageStack(self);

        let isFirstRender = true;

        images.subscribe(() => {
          const content = createImagesContent() as Gtk.Widget;

          if (isFirstRender) {
            // First render: add without transition
            const name = `page-${Date.now()}`;
            self.add_named(content, name);
            self.set_visible_child_name(name);
            isFirstRender = false;
          } else {
            // Subsequent renders: use transition
            showImagesPage(content, pageDirection.peek());
          }

          // Scroll to top after transition
          setTimeout(() => {
            const sw = scrolledWindow.get();
            if (sw) {
              const vadjustment = sw.get_vadjustment();
              vadjustment.set_value(0);
            }
          }, globalTransition);
        });
      }}
    />
  );
};

const PageDisplay = () => (
  <box class="pages" spacing={5} halign={Gtk.Align.CENTER}>
    <With value={globalSettings}>
      {(settings) => {
        const buttons = [];
        const totalPagesToShow = settings.leftPanel.width / 100 + 2;

        // Show "1" button if the current page is greater than 3
        if (settings.booru.page > 3) {
          buttons.push(
            <button
              class="first"
              label="1"
              onClicked={() => {
                setPageDirection("prev");
                setGlobalSetting("booru.page", 1);
              }}
            />,
          );
          buttons.push(<label label={"..."}></label>);
        }

        // Generate 5-page range dynamically without going below 1
        // const startPage = Math.max(1, computed[0] - 2);
        // const endPage = Math.max(5, computed[0] + 2);
        let startPage = Math.max(
          1,
          settings.booru.page - Math.floor(totalPagesToShow / 2),
        );
        let endPage = startPage + totalPagesToShow - 1;

        // Adjust if endPage exceeds totalPagesToShow
        if (endPage - startPage + 1 < totalPagesToShow) {
          endPage = startPage + totalPagesToShow - 1;
        }

        for (let pageNum = startPage; pageNum <= endPage; pageNum++) {
          buttons.push(
            <button
              label={pageNum !== settings.booru.page ? String(pageNum) : ""}
              onClicked={() => {
                if (pageNum !== settings.booru.page) {
                  setPageDirection(
                    pageNum > settings.booru.page ? "next" : "prev",
                  );
                  setGlobalSetting("booru.page", pageNum);
                } else {
                  fetchImages();
                }
              }}
            />,
          );
        }
        return <box spacing={5}>{buttons}</box>;
      }}
    </With>
  </box>
);

const SliderSetting = ({
  label,
  getValue,
  setValue,
  sliderMin,
  sliderMax,
  sliderStep,
  displayTransform,
}: {
  label: string;
  getValue: Accessor<number>;
  setValue: (v: number) => void;
  sliderMin: number;
  sliderMax: number;
  sliderStep: number;
  displayTransform: (v: number) => string;
}) => {
  let debounceTimer: any;

  return (
    <box class="setting" spacing={5}>
      <label label={label} hexpand xalign={0} />
      <box spacing={5} halign={Gtk.Align.END}>
        <slider
          value={getValue}
          widthRequest={globalSettings(
            (settings) => settings.leftPanel.width / 2,
          )}
          class="slider"
          drawValue={false}
          hexpand
          $={(self) => {
            self.set_range(sliderMin, sliderMax);
            self.set_increments(sliderStep, sliderStep);
            const adjustment = self.get_adjustment();
            adjustment.connect("value-changed", () => {
              // Clear the previous timeout if any
              if (debounceTimer) clearTimeout(debounceTimer);

              // Set a new timeout with the desired delay (e.g., 300ms)
              debounceTimer = setTimeout(() => {
                setValue(adjustment.get_value());
              }, 300);
            });
          }}
        />
        <label
          label={getValue((v) => displayTransform(v))}
          widthRequest={50}
        ></label>
      </box>
    </box>
  );
};

const LimitDisplay = () => (
  <SliderSetting
    label="Limit"
    getValue={globalSettings(({ booru }) => booru.limit / 100)}
    setValue={(v) => setGlobalSetting("booru.limit", Math.round(v * 100))}
    sliderMin={0}
    sliderMax={1}
    sliderStep={0.1}
    displayTransform={(v) => String(Math.round(v * 100))}
  />
);

const ColumnDisplay = () => (
  <SliderSetting
    label="Columns"
    getValue={globalSettings(({ booru }) => (booru.columns - 1) / 4)}
    setValue={(v) => setGlobalSetting("booru.columns", Math.round(v * 4) + 1)}
    sliderMin={0}
    sliderMax={1}
    sliderStep={0.25}
    displayTransform={(v) => String(Math.round(v * 4) + 1)}
  />
);
const TagDisplay = () => (
  <Adw.Clamp
    class={"tags"}
    maximumSize={globalSettings((settings) => settings.leftPanel.width - 20)}
  >
    <box widthRequest={100} orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <Gtk.FlowBox
        columnSpacing={5}
        rowSpacing={5}
        selectionMode={Gtk.SelectionMode.NONE}
        homogeneous={false}
      >
        <For each={fetchedTags}>
          {(tag) => (
            <button
              class="tag fetched"
              tooltipText={tag}
              onClicked={() => {
                setGlobalSetting("booru.tags", [
                  ...new Set([...globalSettings.peek().booru.tags, tag]),
                ]);
              }}
            >
              <label
                ellipsize={Pango.EllipsizeMode.END}
                maxWidthChars={10}
                label={tag}
              ></label>
            </button>
          )}
        </For>
      </Gtk.FlowBox>
      <Gtk.FlowBox columnSpacing={5} rowSpacing={5}>
        <For each={globalSettings(({ booru }) => booru.tags)}>
          {(tag: string) =>
            // match -rating:explicit or rating:explicit
            tag.match(/[-]rating:explicit|rating:explicit/) ? (
              <button
                class={`tag rating`}
                tooltipText={tag}
                onClicked={() => {
                  const newRatingTag = tag.startsWith("-")
                    ? "rating:explicit"
                    : "-rating:explicit";

                  const newTags = globalSettings
                    .peek()
                    .booru.tags.filter(
                      (t) => !t.match(/[-]rating:explicit|rating:explicit/),
                    );

                  newTags.unshift(newRatingTag);
                  setGlobalSetting("booru.tags", newTags);
                  console.log(globalSettings.peek().booru.tags);
                }}
              >
                <label
                  ellipsize={Pango.EllipsizeMode.END}
                  maxWidthChars={10}
                  label={tag}
                ></label>
              </button>
            ) : (
              <button
                class="tag enabled"
                tooltipText={tag}
                onClicked={() => {
                  const newTags = globalSettings
                    .peek()
                    .booru.tags.filter((t) => t !== tag);
                  setGlobalSetting("booru.tags", newTags);
                }}
              >
                <label
                  ellipsize={Pango.EllipsizeMode.END}
                  maxWidthChars={10}
                  label={tag}
                ></label>
              </button>
            )
          }
        </For>
      </Gtk.FlowBox>
    </box>
  </Adw.Clamp>
);

const Entry = () => {
  let debounceTimer: any;
  const onChanged = async (self: Gtk.Entry) => {
    // Clear the previous timeout if any
    if (debounceTimer) clearTimeout(debounceTimer);

    // Set a new timeout with the desired delay (e.g., 300ms)
    debounceTimer = setTimeout(() => {
      const text = self.get_text();
      if (!text) {
        setFetchedTags([]);
        return;
      }
      fetchTags(text);
    }, 200);
  };

  const addTags = (self: Gtk.Entry) => {
    const currentTags = globalSettings.peek().booru.tags;
    const text = self.get_text();
    const newTags = text.split(" ");

    // Create a Set to remove duplicates
    const uniqueTags = [...new Set([...currentTags, ...newTags])];

    setGlobalSetting("booru.tags", uniqueTags);
  };

  return (
    <entry
      hexpand
      placeholderText="Add a Tag"
      $={(self) => {
        self.connect("changed", () => onChanged(self));
        self.connect("activate", () => addTags(self));
      }}
    />
  );
};

const ClearCacheButton = () => {
  return (
    <button
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      label={cacheSize}
      class="clear"
      tooltipText="Clear Cache"
      onClicked={() => {
        cleanUp();
      }}
    />
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
        <PageDisplay />
        <LimitDisplay />
        <ColumnDisplay />
        <box class="input" spacing={5} orientation={Gtk.Orientation.VERTICAL}>
          <TagDisplay />
          <box spacing={5}>
            <Entry />
            <ClearCacheButton />
          </box>
        </box>
      </box>
    </revealer>
  );

  // action box (previous, revealer, next)
  const actions = (
    <box class="actions" spacing={5}>
      <button
        label=""
        onClicked={() => {
          const currentPage = globalSettings.peek().booru.page;
          if (currentPage > 1) {
            setPageDirection("prev");
            setGlobalSetting("booru.page", currentPage - 1);
          }
        }}
        tooltipText={"KEY-LEFT"}
      />
      <button
        hexpand
        class="reveal-button"
        label={bottomIsRevealed((revealed) => (!revealed ? "" : ""))}
        onClicked={(self) => {
          setBottomIsRevealed(!bottomIsRevealed.get());
        }}
        tooltipText={"Toggle Settings (KEY-UP/DOWN)"}
      />
      <button
        label=""
        onClicked={() => {
          const currentPage = globalSettings.peek().booru.page;
          setPageDirection("next");
          setGlobalSetting("booru.page", currentPage + 1);
        }}
        tooltipText={"KEY-RIGHT"}
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
  return (
    <box
      class="booru"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      spacing={5}
      $={async (self) => {
        const keyController = new Gtk.EventControllerKey();
        keyController.connect("key-pressed", (_, keyval: number) => {
          // scroll up
          if (keyval === Gdk.KEY_Up) {
            setBottomIsRevealed(true);
            return true;
          }
          // scroll down
          if (keyval === Gdk.KEY_Down) {
            setBottomIsRevealed(false);
            return true;
          }
          if (keyval === Gdk.KEY_Right) {
            const currentPage = globalSettings.peek().booru.page;
            setPageDirection("next");
            setGlobalSetting("booru.page", currentPage + 1);
            return true;
          }
          if (keyval === Gdk.KEY_Left) {
            const currentPage = globalSettings.peek().booru.page;
            if (currentPage > 1) {
              setPageDirection("prev");
              setGlobalSetting("booru.page", currentPage - 1);
            }
            return true;
          }
          return false;
        });
        self.add_controller(keyController);

        // Initial fetch
        ensureRatingTagFirst();
        // Restore selected tab from global settings, or default to API name
        const savedTab = globalSettings.peek().booru.selectedTab;
        setSelectedTab(savedTab || globalSettings.peek().booru.api.name);
        fetchImages();

        globalSettings.subscribe(() => {
          if (globalSettings.peek().booru.page !== page.peek()) {
            setPage(globalSettings.peek().booru.page);
            fetchImages();
          }
          if (globalSettings.peek().booru.limit !== limit.peek()) {
            setLimit(globalSettings.peek().booru.limit);
            fetchImages();
          }
          if (
            globalSettings.peek().booru.tags.toString() !==
            tags.peek().toString()
          ) {
            setTags(globalSettings.peek().booru.tags);
            if (selectedTab.peek() !== "Bookmarks") {
              fetchImages();
            }
          }
          if (globalSettings.peek().booru.selectedTab !== selectedTab.peek()) {
            setSelectedTab(globalSettings.peek().booru.selectedTab);
            fetchImages();
          }
        });
      }}
    >
      <box orientation={Gtk.Orientation.VERTICAL}>
        <Images />
        <Progress
          status={progressStatus}
          transitionType={Gtk.RevealerTransitionType.SWING_UP}
          custom_class="booru-progress"
        />
      </box>
      <Bottom />
      <Tabs />
    </box>
  );
};
