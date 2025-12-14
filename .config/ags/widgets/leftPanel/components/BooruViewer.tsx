import Gtk from "gi://Gtk?version=4.0";
import { Waifu } from "../../../interfaces/waifu.interface";
import { execAsync } from "ags/process";
import { Api } from "../../../interfaces/api.interface";
import { readJson } from "../../../utils/json";
import {
  booruApi,
  booruLimit,
  booruPage,
  booruTags,
  globalTransition,
  leftPanelWidth,
  waifuCurrent,
  setBooruApi,
  setBooruLimit,
  setBooruPage,
  setBooruTags,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { createState, For, With } from "ags";
import { booruApis } from "../../../constants/api.constants";
import { ImageDialog } from "./ImageDialog";
import Picture from "../../Picture";
import Gdk from "gi://Gdk?version=4.0";

const [images, setImages] = createState<Waifu[]>([]);
const [cacheSize, setCacheSize] = createState<string>("0kb");

const [fetchedTags, setFetchedTags] = createState<string[]>([]);

const imagePreviewPath = "./assets/booru/previews";
const imageUrlPath = "./assets/booru/images";

const calculateCacheSize = async () =>
  execAsync(`bash -c "du -sb ${imagePreviewPath} | cut -f1"`).then((res) => {
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
    execAsync(`bash -c "rm -rf ${imagePreviewPath}/*"`),
    execAsync(`bash -c "rm -rf ${imageUrlPath}/*"`),
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
    // openProgress();
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
      api: booruApi.get(),
    }));

    // 4. Prepare directory in background
    execAsync(`bash -c "mkdir -p ${imagePreviewPath}"`).catch((err) =>
      notify({ summary: "Error", body: String(err) })
    );

    // 5. Download images in parallel
    const downloadPromises = newImages.map((image) =>
      execAsync(
        `bash -c "[ -e "${imagePreviewPath}/${image.id}.webp" ] || curl -o "${imagePreviewPath}/${image.id}.webp" "${image.preview}""`
      )
        .then(() => {
          image.preview_path = `${imagePreviewPath}/${image.id}.webp`;
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
      // closeProgress();
    });
  } catch (err) {
    console.error(err);
    notify({ summary: "Error", body: String(err) });
    // closeProgress();
  }
};
const Apis = () => (
  <box class="api-list" spacing={5}>
    {booruApis.map((api) => (
      <togglebutton
        hexpand
        active={booruApi((a) => a.name === api.name)}
        class="api"
        label={api.name}
        onToggled={({ active }) => {
          if (active) setBooruApi(api);
        }}
      />
    ))}
  </box>
);

const fetchTags = async (tag: string) => {
  const escapedTag = tag.replace(/'/g, "'\\'''");
  const res = await execAsync(
    `python ./scripts/search-booru.py 
    --api ${booruApi.get().value} 
    --tag '${escapedTag}'`
  );
  setFetchedTags(readJson(res));
};

const Images = () => {
  const imageRows = images((imgs) =>
    imgs.reduce((rows: any[][], image, index) => {
      if (index % 2 === 0) rows.push([]);
      rows[rows.length - 1].push(image);
      return rows;
    }, [])
  );

  return (
    <scrolledwindow hexpand vexpand>
      <box class="images" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
        <For each={imageRows}>
          {(row) => (
            <box spacing={5}>
              {row.map((image: Waifu) => {
                const dialog = new ImageDialog(image);
                return (
                  <menubutton
                    direction={Gtk.ArrowType.RIGHT}
                    hexpand
                    heightRequest={leftPanelWidth((w) => w / 2)}
                    class="image-button"
                  >
                    <Picture file={image.preview_path || ""}></Picture>
                    <popover>{dialog.getBox()}</popover>
                  </menubutton>
                );
              })}
            </box>
          )}
        </For>
      </box>
    </scrolledwindow>
  );
};

const PageDisplay = () => (
  <box class="pages" spacing={5} halign={Gtk.Align.CENTER}>
    <With value={booruPage}>
      {(p) => {
        const buttons = [];

        // Show "1" button if the current page is greater than 3
        if (p > 3) {
          buttons.push(
            <button class="first" label="1" onClicked={() => setBooruPage(1)} />
          );
          buttons.push(<label>...</label>);
        }

        // Generate 5-page range dynamically without going below 1
        const startPage = Math.max(1, p - 2);
        const endPage = Math.max(5, p + 2);

        for (let pageNum = startPage; pageNum <= endPage; pageNum++) {
          buttons.push(
            <button
              label={pageNum !== p ? String(pageNum) : ""}
              onClicked={() =>
                pageNum !== p ? setBooruPage(pageNum) : fetchImages()
              }
            />
          );
        }
        return <box spacing={5}>{buttons}</box>;
      }}
    </With>
  </box>
);

const LimitDisplay = () => {
  let debounceTimer: any;

  return (
    <box class="limits" spacing={5} hexpand>
      <label label="Limit"></label>
      <slider
        value={booruLimit((l) => l / 100)}
        class="slider"
        drawValue={false}
        hexpand
        $={(self) => {
          self.set_range(0, 1);
          self.set_increments(0.1, 0.1);
          const adjustment = self.get_adjustment();
          adjustment.connect("value-changed", () => {
            // Clear the previous timeout if any
            if (debounceTimer) clearTimeout(debounceTimer);

            // Set a new timeout with the desired delay (e.g., 300ms)
            debounceTimer = setTimeout(() => {
              setBooruLimit(Math.round(adjustment.get_value() * 100));
            }, 300);
          });
        }}
      />
      <label label={booruLimit((l) => String(l))}></label>
    </box>
  );
};

const TagDisplay = () => (
  <scrolledwindow hexpand vscrollbarPolicy={Gtk.PolicyType.NEVER}>
    <box class="tags" spacing={10}>
      <box class="applied-tags" spacing={5}>
        <For each={booruTags}>
          {(tag) =>
            tag.match(/[-+]rating:explicit/) ? (
              <button
                class={`rating ${tag.startsWith("+") ? "explicit" : "safe"}`}
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
            ) : (
              <button
                label={tag}
                onClicked={() => {
                  const newTags = booruTags.get().filter((t) => t !== tag);
                  setBooruTags(newTags);
                }}
              />
            )
          }
        </For>
      </box>
      <box class="fetched-tags" spacing={5}>
        <For each={fetchedTags}>
          {(tag) => (
            <button
              label={tag}
              onClicked={() => {
                setBooruTags([...new Set([...booruTags.get(), tag])]);
              }}
            />
          )}
        </For>
      </box>
    </box>
  </scrolledwindow>
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
      onClicked={() => {
        cleanUp();
      }}
    />
  );
};

const [bottomIsRevealed, setBottomIsRevealed] = createState<boolean>(false);

const BottomBar = () => {
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
        <TagDisplay />
        <box spacing={5}>
          <Entry />
          <ClearCacheButton />
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
      />
      <button
        hexpand
        class="reveal-button"
        label=""
        onClicked={(self) => {
          const currentlyRevealed = bottomIsRevealed.get();
          setBottomIsRevealed(!currentlyRevealed);
          self.set_label(currentlyRevealed ? "" : "");
        }}
      />
      <button
        label=""
        onClicked={() => {
          const currentPage = booruPage.get();
          setBooruPage(currentPage + 1);
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
  ensureRatingTagFirst();
  booruPage.subscribe(() => fetchImages());
  booruTags.subscribe(() => fetchImages());
  booruApi.subscribe(() => fetchImages());
  booruLimit.subscribe(() => fetchImages());
  fetchImages();

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
      }}
    >
      <Apis />
      <Images />
      <BottomBar />
    </box>
  );
};
