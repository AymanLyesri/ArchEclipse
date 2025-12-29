import Gtk from "gi://Gtk?version=4.0";
import { Waifu } from "../../../interfaces/waifu.interface";
import { execAsync } from "ags/process";
import { readJson } from "../../../utils/json";
import {
  booruApi,
  booruLimit,
  booruPage,
  booruTags,
  booruColumns,
  globalTransition,
  leftPanelWidth,
  setBooruApi,
  setBooruLimit,
  setBooruPage,
  setBooruTags,
  setBooruColumns,
  booruBookMarkWaifus,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { createState, createComputed, For, With, Accessor } from "ags";
import { booruApis } from "../../../constants/api.constants";
import Picture from "../../Picture";
import Gdk from "gi://Gdk?version=4.0";
import { Progress } from "../../Progress";
import { connectPopoverEvents } from "../../../utils/window";
import ImageDialog from "./ImageDialog";
import { booruPath } from "../../../constants/path.constants";
import { OpenInBrowser } from "../../../utils/image";
import Adw from "gi://Adw?version=1";
import { get } from "http";

const [images, setImages] = createState<Waifu[]>([]);
const [cacheSize, setCacheSize] = createState<string>("0kb");
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");
const [fetchedTags, setFetchedTags] = createState<string[]>([]);

const [selectedTab, setSelectedTab] = createState<string>(booruApis[0].name);

const calculateCacheSize = async () =>
  execAsync(
    `bash -c "du -sb ${booruPath}/${booruApi.get().value}/previews | cut -f1"`
  ).then((res) => {
    // Convert bytes to megabytes
    setCacheSize(`${Math.round(Number(res) / (1024 * 1024))}mb`);
  });

const ensureRatingTagFirst = () => {
  let tags: string[] = booruTags.get();
  // Find existing rating tag
  const ratingTag = tags.find((tag) => tag.match(/[-+]rating:explicit/));
  // Remove any existing rating tag
  tags = tags.filter((tag) => !tag.match(/[-+]rating:explicit/));
  // Add the previous rating tag at the beginning, or default to "-rating:explicit"
  tags.unshift(ratingTag ?? "-rating:explicit");
  setBooruTags(tags);
};

const cleanUp = () => {
  const promises = [
    execAsync(
      `bash -c "rm -rf ${booruPath}/${booruApi.get().value}/previews/*"`
    ),
    execAsync(`bash -c "rm -rf ${booruPath}/${booruApi.get().value}/images/*"`),
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
    const escapedTags = booruTags
      .get()
      .map((tag) => tag.replace(/'/g, "'\\''"));
    const res = await execAsync(
      `python ./scripts/search-booru.py 
      --api ${booruApi.get().value} 
      --tags '${escapedTags.join(",")}' 
      --limit ${booruLimit.get()} 
      --page ${booruPage.get()}`
    );

    // 2. Process metadata without blocking
    const newImages: Waifu[] = readJson(res).map((image: any) => ({
      id: image.id,
      url: image.url,
      preview: image.preview,
      width: image.width,
      height: image.height,
      extension: image.extension,
      api: booruApi.get(),
    }));

    // 4. Prepare directory in background
    execAsync(
      `bash -c "mkdir -p ${booruPath}/${booruApi.get().value}/previews"`
    ).catch((err) => notify({ summary: "Error", body: String(err) }));

    // 5. Download images in parallel
    const downloadPromises = newImages.map((image) =>
      execAsync(
        `bash -c "[ -e "${booruPath}/${booruApi.get().value}/previews/${
          image.id
        }.${image.extension}" ] || curl -o "${booruPath}/${
          booruApi.get().value
        }/previews/${image.id}.${image.extension}" "${image.preview}""`
      )
        .then(() => {
          return image;
        })
        .catch((err) => {
          notify({ summary: "Error", body: String(err) });
          return null;
        })
    );

    // 6. Update UI when all downloads complete
    Promise.all(downloadPromises).then((downloadedImages) => {
      // Filter out failed downloads (null values)
      const successfulDownloads = downloadedImages.filter(
        (img) => img !== null
      );
      setImages(successfulDownloads);
      calculateCacheSize();
      setProgressStatus("success");
    });
  } catch (err) {
    console.error(err);
    notify({ summary: "Error", body: String(err) });
    setProgressStatus("error");
  }
};

const fetchBookmarkImages = async () => {
  try {
    setProgressStatus("loading");

    // 5. Download images in parallel
    const downloadPromises = booruBookMarkWaifus.get().map((image) =>
      execAsync(
        `bash -c "[ -e "${booruPath}/${booruApi.get().value}/previews/${
          image.id
        }.${image.extension}" ] || curl -o "${booruPath}/${
          booruApi.get().value
        }/previews/${image.id}.${image.extension}" "${image.preview}""`
      )
        .then(() => {
          return image;
        })
        .catch((err) => {
          notify({ summary: "Error", body: String(err) });
          return null;
        })
    );

    // 6. Update UI when all downloads complete
    Promise.all(downloadPromises).then((downloadedImages) => {
      // Filter out failed downloads (null values)
      const successfulDownloads = downloadedImages.filter(
        (img) => img !== null
      );
      setImages(successfulDownloads);
      calculateCacheSize();
      setProgressStatus("success");
    });
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
            setBooruApi(api);
            setSelectedTab(api.name);
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
    --api ${booruApi.get().value} 
    --tag '${escapedTag}'`
  );
  print(res);
  setFetchedTags(readJson(res));
};

const Images = () => {
  function masonry(images: Waifu[], columnsCount: number) {
    const columns = Array.from({ length: columnsCount }, () => ({
      height: 0,
      items: [] as Waifu[],
    }));

    for (const image of images) {
      const ratio = image.height / image.width;
      const target = columns.reduce((a, b) => (a.height < b.height ? a : b));

      target.items.push(image);
      target.height += ratio;
    }

    return columns.map((c) => c.items);
  }

  const imageColumns = createComputed([images, booruColumns], (imgs, cols) =>
    masonry(imgs, cols)
  );
  const columnWidth = leftPanelWidth((w) => w / imageColumns.get().length - 10);

  return (
    <scrolledwindow
      hexpand
      vexpand
      $={(self) => {
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
              {column.map((image: Waifu) => (
                <menubutton
                  class="image-button"
                  hexpand
                  widthRequest={columnWidth}
                  heightRequest={columnWidth(
                    (w) => w * (image.height / image.width)
                  )}
                  $={(self) => {
                    const gesture = new Gtk.GestureClick();
                    gesture.set_button(3);
                    gesture.set_propagation_phase(Gtk.PropagationPhase.BUBBLE);

                    gesture.connect("released", () => {
                      OpenInBrowser(image);
                    });

                    self.add_controller(gesture);

                    connectPopoverEvents(self);
                  }}
                  direction={Gtk.ArrowType.RIGHT}
                  tooltipText={`ID: ${image.id}\n${image.width}x${image.height}`}
                >
                  <Picture
                    file={`${booruPath}/${booruApi.get().value}/previews/${
                      image.id
                    }.${image.extension}`}
                  />
                  <popover>
                    <ImageDialog image={image} />
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
    <With value={createComputed([booruPage, leftPanelWidth])}>
      {(computed: [number, number]) => {
        const buttons = [];
        const totalPagesToShow = computed[1] / 100 + 2;

        // Show "1" button if the current page is greater than 3
        if (computed[0] > 3) {
          buttons.push(
            <button class="first" label="1" onClicked={() => setBooruPage(1)} />
          );
          buttons.push(<label label={"..."}></label>);
        }

        // Generate 5-page range dynamically without going below 1
        // const startPage = Math.max(1, computed[0] - 2);
        // const endPage = Math.max(5, computed[0] + 2);
        let startPage = Math.max(
          1,
          computed[0] - Math.floor(totalPagesToShow / 2)
        );
        let endPage = startPage + totalPagesToShow - 1;

        // Adjust if endPage exceeds totalPagesToShow
        if (endPage - startPage + 1 < totalPagesToShow) {
          endPage = startPage + totalPagesToShow - 1;
        }

        for (let pageNum = startPage; pageNum <= endPage; pageNum++) {
          buttons.push(
            <button
              label={pageNum !== computed[0] ? String(pageNum) : ""}
              onClicked={() =>
                pageNum !== computed[0] ? setBooruPage(pageNum) : fetchImages()
              }
            />
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
          widthRequest={leftPanelWidth((width) => width / 2)}
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
    getValue={booruLimit((limit) => limit / 100)}
    setValue={(v) => setBooruLimit(Math.round(v * 100))}
    sliderMin={0}
    sliderMax={1}
    sliderStep={0.1}
    displayTransform={(v) => String(Math.round(v * 100))}
  />
);

const ColumnDisplay = () => (
  <SliderSetting
    label="Columns"
    getValue={booruColumns((columns) => (columns - 1) / 4)}
    setValue={(v) => setBooruColumns(Math.round(v * 4) + 1)}
    sliderMin={0}
    sliderMax={1}
    sliderStep={0.25}
    displayTransform={(v) => String(Math.round(v * 4) + 1)}
  />
);
const TagDisplay = () => (
  <Adw.Clamp class={"tags"} maximumSize={leftPanelWidth((w) => w - 20)}>
    <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
      <Gtk.FlowBox
        columnSpacing={5}
        rowSpacing={5}
        selectionMode={Gtk.SelectionMode.NONE}
        homogeneous={false}
      >
        <For each={fetchedTags}>
          {(tag) => (
            <Gtk.FlowBoxChild>
              <button
                class="tag fetched"
                label={tag}
                onClicked={() => {
                  setBooruTags([...new Set([...booruTags.get(), tag])]);
                }}
              />
            </Gtk.FlowBoxChild>
          )}
        </For>
      </Gtk.FlowBox>
      <Gtk.FlowBox
        columnSpacing={5}
        rowSpacing={5}
        selectionMode={Gtk.SelectionMode.NONE}
        homogeneous={false}
      >
        <For each={booruTags}>
          {(tag) =>
            tag.match(/[-+]rating:explicit/) ? (
              <Gtk.FlowBoxChild>
                <button
                  class={`tag rating ${
                    tag.startsWith("+") ? "explicit" : "safe"
                  }`}
                  label={tag}
                  onClicked={() => {
                    const newRatingTag = tag.startsWith("-")
                      ? "+rating:explicit"
                      : "-rating:explicit";

                    const newTags = booruTags
                      .get()
                      .filter((t) => !t.match(/[-+]rating:explicit/));

                    newTags.unshift(newRatingTag);
                    setBooruTags(newTags);
                  }}
                />
              </Gtk.FlowBoxChild>
            ) : (
              <Gtk.FlowBoxChild>
                <button
                  label={tag}
                  class="tag enabled"
                  onClicked={() => {
                    const newTags = booruTags.get().filter((t) => t !== tag);
                    setBooruTags(newTags);
                  }}
                />
              </Gtk.FlowBoxChild>
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
    const currentTags = booruTags.get();
    const text = self.get_text();
    const newTags = text.split(" ");

    // Create a Set to remove duplicates
    const uniqueTags = [...new Set([...currentTags, ...newTags])];

    setBooruTags(uniqueTags);
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
    <box
      class="actions"
      spacing={5}
      // halign={Gtk.Align.CENTER}
      // orientation={Gtk.Orientation.VERTICAL}
    >
      <button
        label=""
        onClicked={() => {
          const currentPage = booruPage.get();
          if (currentPage > 1) {
            setBooruPage(currentPage - 1);
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
        tooltipText={bottomIsRevealed((revealed) =>
          revealed ? "KEY-DOWN" : "KEY-UP"
        )}
      />
      <button
        label=""
        onClicked={() => {
          const currentPage = booruPage.get();
          setBooruPage(currentPage + 1);
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
      spacing={10}
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
          if (keyval === Gdk.KEY_Right) {
            const currentPage = booruPage.get();
            setBooruPage(currentPage + 1);
            return true;
          }
          if (keyval === Gdk.KEY_Left) {
            const currentPage = booruPage.get();
            if (currentPage > 1) {
              setBooruPage(currentPage - 1);
            }
            return true;
          }
          return false;
        });
        self.add_controller(keyController);

        // Initial fetch
        ensureRatingTagFirst();
        booruPage.subscribe(() => fetchImages());
        booruTags.subscribe(() => fetchImages());
        booruApi.subscribe(() => fetchImages());
        booruLimit.subscribe(() => fetchImages());
        booruBookMarkWaifus.subscribe(() => {
          if (selectedTab.get() == "bookmarks") fetchBookmarkImages();
        });
        fetchImages();
      }}
    >
      <Tabs />
      <box orientation={Gtk.Orientation.VERTICAL}>
        <Images />
        <Progress
          status={progressStatus}
          transitionType={Gtk.RevealerTransitionType.SWING_UP}
          custom_class="booru-progress"
        />
      </box>
      <Bottom />
    </box>
  );
};
