import Gtk from "gi://Gtk?version=4.0";
import { BooruImage } from "../../../classes/BooruImage";
import { execAsync } from "ags/process";
import { readJson } from "../../../utils/json";
import {
  globalSettings,
  globalTransition,
  setGlobalSetting,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { createState, createComputed, For, With, Accessor } from "ags";
import { booruApis } from "../../../constants/api.constants";
import Picture from "../../Picture";
import Gdk from "gi://Gdk?version=4.0";
import { Progress } from "../../Progress";
import { connectPopoverEvents } from "../../../utils/window";
import { booruPath } from "../../../constants/path.constants";
import Adw from "gi://Adw";
import Pango from "gi://Pango?version=1.0";

const [images, setImages] = createState<BooruImage[]>([]);
const [cacheSize, setCacheSize] = createState<string>("0kb");
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");
const [fetchedTags, setFetchedTags] = createState<string[]>([]);

const [selectedTab, setSelectedTab] = createState<string>("");
const [scrolledWindow, setScrolledWindow] =
  createState<Gtk.ScrolledWindow | null>(null);

const calculateCacheSize = async () =>
  execAsync(
    `bash -c "du -sb ${booruPath}/${
      globalSettings.peek().booru.api.value
    }/previews | cut -f1"`,
  ).then((res) => {
    // Convert bytes to megabytes
    setCacheSize(`${Math.round(Number(res) / (1024 * 1024))}mb`);
  });

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
      notify({ summary: "Error", body: String(err) });
    });
};
const fetchImages = async () => {
  try {
    setProgressStatus("loading");

    const settings = globalSettings.peek();
    const escapedTags = settings.booru.tags.map((t) =>
      t.replace(/'/g, "'\\''"),
    );

    const res = await execAsync(`
      python ./scripts/search-booru.py \
        --api ${settings.booru.api.value} \
        --tags '${escapedTags.join(",")}' \
        --limit ${settings.booru.limit} \
        --page ${settings.booru.page}
    `);

    const jsonData = readJson(res);
    if (!jsonData || !Array.isArray(jsonData)) {
      throw new Error("Invalid response from booru API");
    }

    const images: BooruImage[] = jsonData.map(
      (img: any) =>
        new BooruImage({
          ...img,
          api: settings.booru.api,
        }),
    );

    await execAsync(`
      bash -c '
        set -e
        DIR="${booruPath}/${settings.booru.api.value}/previews"
        mkdir -p "$DIR"

        for img in ${images
          .map(
            (i) =>
              `"${i.id}|${i.extension}|${i.preview!.replace(/"/g, '\\"')}"`,
          )
          .join(" ")}
        do
          IFS="|" read -r id ext url <<< "$img"
          file="$DIR/$id.$ext"
          [ -f "$file" ] || curl -sSf -o "$file" "$url"
        done
      '
    `);

    setImages(images);
    calculateCacheSize();
    setProgressStatus("success");
  } catch (err) {
    console.error(err);
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
  }
};
const fetchBookmarkImages = async () => {
  try {
    setProgressStatus("loading");

    const bookmarks = globalSettings.peek().booru.bookmarks;

    await execAsync(`
      bash -c '
        set -e

        for img in ${bookmarks
          .map(
            (i) =>
              `"${i.api.value}|${i.id}|${i.extension}|${i.preview!.replace(
                /"/g,
                '\\"',
              )}"`,
          )
          .join(" ")}
        do
          IFS="|" read -r api id ext url <<< "$img"
          DIR="${booruPath}/$api/previews"
          mkdir -p "$DIR"
          file="$DIR/$id.$ext"
          [ -f "$file" ] || curl -sSf -o "$file" "$url"
        done
      '
    `);

    // Convert bookmarks to BooruImage instances
    const bookmarkImages = bookmarks.map((b: any) => new BooruImage(b));
    setImages(bookmarkImages);
    calculateCacheSize();
    setProgressStatus("success");
  } catch (err) {
    console.error(err);
    notify({ summary: "Error", body: String(err) });
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
          fetchBookmarkImages();
        }
      }}
    />
  </box>
);

const fetchTags = async (tag: string) => {
  const escapedTag = tag.replace(/'/g, "'\\'''");
  const res = await execAsync(
    `python ./scripts/search-booru.py 
    --api ${globalSettings.peek().booru.api.value} 
    --tag '${escapedTag}'`,
  );
  const jsonData = readJson(res);
  if (!jsonData || !Array.isArray(jsonData)) {
    console.error("Invalid response from tag search");
    setFetchedTags([]);
    return;
  }
  setFetchedTags(jsonData);
};

const Images = () => {
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

  const imageColumns = createComputed(
    [images, globalSettings(({ booru }) => booru.columns)],
    (imgs, cols) => masonry(imgs, cols),
  );
  const columnWidth = globalSettings(
    ({ leftPanel }) => leftPanel.width / imageColumns.peek().length - 10,
  );

  return (
    <scrolledwindow
      hexpand
      vexpand
      $={async (self) => {
        setScrolledWindow(self);
        images.subscribe(() => {
          const vadjustment = self.get_vadjustment();
          vadjustment.set_value(0);
        });
      }}
    >
      <box class={"images"} spacing={5}>
        <For each={imageColumns}>
          {(column) => (
            <box orientation={Gtk.Orientation.VERTICAL} spacing={5} hexpand>
              {column.map((image: BooruImage) => (
                <menubutton
                  class="image-button"
                  hexpand
                  widthRequest={columnWidth}
                  heightRequest={columnWidth(
                    (w) => w * (image.height / image.width),
                  )}
                  $={(self) => {
                    const gesture = new Gtk.GestureClick();
                    gesture.set_button(3);
                    gesture.set_propagation_phase(Gtk.PropagationPhase.BUBBLE);

                    gesture.connect("released", () => {
                      image.openInBrowser();
                    });

                    self.add_controller(gesture);

                    connectPopoverEvents(self);
                  }}
                  direction={Gtk.ArrowType.RIGHT}
                  tooltipMarkup={`Click to Open\nLeft Click to Open in Browser\n<b>ID:</b> ${image.id}\n<b>Dimensions:</b> ${image.width}x${image.height}`}
                >
                  <Picture
                    file={`${booruPath}/${image.api.value}/previews/${image.id}.${image.extension}`}
                  />
                  <popover
                    $={(self) => {
                      self.connect("notify::visible", () => {
                        if (self.visible) self.add_css_class("popover-open");
                        else if (self.get_child())
                          self.remove_css_class("popover-open");
                      });
                    }}
                  >
                    {image.renderAsImageDialog()}
                  </popover>
                </menubutton>
              ))}
            </box>
          )}
        </For>
      </box>
    </scrolledwindow>
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
              onClicked={() => setGlobalSetting("booru.page", 1)}
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
              onClicked={() =>
                pageNum !== settings.booru.page
                  ? setGlobalSetting("booru.page", pageNum)
                  : fetchImages()
              }
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

const [bottomIsRevealed, setBottomIsRevealed] = createState<boolean>(false);

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
        tooltipText={"SHIFT"}
      />
      <button
        label=""
        onClicked={() => {
          const currentPage = globalSettings.peek().booru.page;
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

const [page, setPage] = createState<number>(1);
const [tags, setTags] = createState<string[]>([]);
const [limit, setLimit] = createState<number>(100);

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
          // shift to reveal/hide bottom
          if (keyval === Gdk.KEY_Shift_L || keyval === Gdk.KEY_Shift_R) {
            setBottomIsRevealed(!bottomIsRevealed.get());
            return true;
          }
          // scroll up
          if (keyval === Gdk.KEY_Up && !bottomIsRevealed.get()) {
            const sw = scrolledWindow.get();
            if (sw) {
              const vadjustment = sw.get_vadjustment();
              const currentValue = vadjustment.get_value();
              const pageSize = vadjustment.get_page_size();
              vadjustment.set_value(
                Math.max(0, currentValue - pageSize * 0.15),
              );
            }
            return true;
          }
          // scroll down
          if (keyval === Gdk.KEY_Down && !bottomIsRevealed.get()) {
            const sw = scrolledWindow.get();
            if (sw) {
              const vadjustment = sw.get_vadjustment();
              const currentValue = vadjustment.get_value();
              const pageSize = vadjustment.get_page_size();
              const maxValue = vadjustment.get_upper() - pageSize;
              vadjustment.set_value(
                Math.min(maxValue, currentValue + pageSize * 0.15),
              );
            }
            return true;
          }
          if (keyval === Gdk.KEY_Right) {
            const currentPage = globalSettings.peek().booru.page;
            setGlobalSetting("booru.page", currentPage + 1);
            return true;
          }
          if (keyval === Gdk.KEY_Left) {
            const currentPage = globalSettings.peek().booru.page;
            if (currentPage > 1) {
              setGlobalSetting("booru.page", currentPage - 1);
            }
            return true;
          }
          return false;
        });
        self.add_controller(keyController);

        // Initial fetch
        ensureRatingTagFirst();
        setSelectedTab(globalSettings.peek().booru.api.name);
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
