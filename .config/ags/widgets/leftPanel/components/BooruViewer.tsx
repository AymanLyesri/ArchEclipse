import Gtk from "gi://Gtk?version=4.0";
import { Waifu } from "../../../interfaces/waifu.interface";
import { execAsync } from "ags/process";
import { createState, createBinding, createComputed } from "ags";
import { Api } from "../../../interfaces/api.interface";
import { readJson } from "../../../utils/json";
import {
  booruApi,
  setBooruApi,
  booruLimit,
  setBooruLimit,
  booruPage,
  setBooruPage,
  booruTags,
  setBooruTags,
  globalTransition,
  leftPanelWidth,
  waifuCurrent,
} from "../../../variables";
import { notify } from "../../../utils/notification";
import { closeProgress, openProgress } from "../../Progress";

import { booruApis } from "../../../constants/api.constants";
import { ImageDialog } from "./ImageDialog";

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
  let tags: string[] = booruTags();
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
    openProgress();
    const escapedTags = booruTags().map((tag) => tag.replace(/'/g, "'\\''"));
    const res = await execAsync(
      `python ./scripts/search-booru.py 
      --api ${booruApi().value} 
      --tags '${escapedTags.join(",")}' 
      --limit ${booruLimit()} 
      --page ${booruPage()}`
    );

    // 2. Process metadata without blocking
    const newImages: Waifu[] = readJson(res).map((image: any) => ({
      id: image.id,
      url: image.url,
      preview: image.preview,
      width: image.width,
      height: image.height,
      api: booruApi(),
    })); // 4. Prepare directory in background
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
      closeProgress();
    });
  } catch (err) {
    console.error(err);
    notify({ summary: "Error", body: String(err) });
    closeProgress();
  }
};
const Apis = () => (
  <box class="api-list" spacing={5}>
    {booruApis.map((api) => (
      <togglebutton
        hexpand
        active={createComputed(() => booruApi().name === api.name)}
        class="api"
        label={api.name}
        onToggled={() => setBooruApi(api)}
      />
    ))}
  </box>
);

const fetchTags = async (tag: string) => {
  const escapedTag = tag.replace(/'/g, "'\\''");
  const res = await execAsync(
    `python ./scripts/search-booru.py 
    --api ${booruApi().value} 
    --tag '${escapedTag}'`
  );
  setFetchedTags(readJson(res));
};

const Images = () => {
  return (
    <scrolledwindow
      hexpand
      vexpand
      child={
        <box class="images" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          {createComputed(() =>
            images()
              .reduce((rows: any[][], image, index) => {
                if (index % 2 === 0) rows.push([]); // Create a new row every 2 items
                rows[rows.length - 1].push(image); // Add the image to the current row
                return rows;
              }, [])
              .map((row) => (
                <box spacing={5}>
                  {row.map((image) => {
                    return (
                      <button
                        onClick={() => {
                          new ImageDialog(image);
                        }}
                        hexpand
                        heightRequest={createComputed(
                          () => leftPanelWidth() / 2
                        )}
                        class="image"
                        css={`
                          background-image: url("${image.preview_path}");
                        `}
                      />
                    );
                  })}
                </box>
              ))
          )}
        </box>
      }
    ></scrolledwindow>
  );
};

const PageDisplay = () => (
  <box class="pages" spacing={5} halign={Gtk.Align.CENTER}>
    {createComputed(() => {
      const p = booruPage();
      const buttons = [];

      // Show "1" button if the current page is greater than 3
      if (p > 3) {
        buttons.push(
          <button
            class={"first"}
            label="1"
            onClicked={() => setBooruPage(1)}
          />,
          <label>...</label>
        );
      }

      // Generate 5-page range dynamically without going below 1
      const startPage = Math.max(1, p - 2);
      const endPage = Math.max(5, p + 2);

      for (let pageNum = startPage; pageNum <= endPage; pageNum++) {
        buttons.push(
          <button
            label={pageNum !== p ? String(pageNum) : ""}
            onClicked={() =>
              pageNum !== p ? setBooruPage(pageNum) : fetchImages()
            }
          />
        );
      }
      return buttons;
    })}
  </box>
);

const LimitDisplay = () => {
  let debounceTimer: any;

  return (
    <box class="limits" spacing={5} hexpand>
      <label label={"Limit"}></label>
      <slider
        value={createComputed(() => booruLimit() / 100)}
        class={"slider"}
        // min={4}
        // max={20}
        step={0.1}
        hexpand
        onValueChanged={(self) => {
          // Clear the previous timeout if any
          if (debounceTimer) clearTimeout(debounceTimer);

          // Set a new timeout with the desired delay (e.g., 300ms)
          debounceTimer = setTimeout(() => {
            setBooruLimit(Math.round(self.value * 100));
          }, 300);
        }}
      />
      <label label={createComputed(() => String(booruLimit()))}></label>
    </box>
  );
};

const TagDisplay = () => (
  <scrolledwindow
    hexpand
    vscroll={Gtk.PolicyType.NEVER}
    child={
      <box class={"tags"} spacing={10}>
        <box class="applied-tags" spacing={5}>
          {createComputed(() =>
            booruTags().map((tag) => {
              // check if tag is rating tag
              if (tag.match(/[-+]rating:explicit/)) {
                return (
                  <button
                    class={`rating ${
                      tag.startsWith("+") ? "explicit" : "safe"
                    }`}
                    label={tag}
                    onClicked={() => {
                      const newRatingTag = tag.startsWith("-")
                        ? "+rating:explicit"
                        : "-rating:explicit";
                      const newTags = booruTags().filter(
                        (t) => !t.match(/[-+]rating:explicit/)
                      );
                      newTags.unshift(newRatingTag);
                      setBooruTags(newTags);
                    }}
                  />
                );
              }
              return (
                <button
                  label={tag}
                  onClicked={() => {
                    const newTags = booruTags().filter((t) => t !== tag);
                    setBooruTags(newTags);
                  }}
                />
              );
            })
          )}
        </box>
        <box class={"fetched-tags"} spacing={5}>
          {createComputed(() =>
            fetchedTags().map((tag) => (
              <button
                label={tag}
                onClicked={() => {
                  setBooruTags([...new Set([...booruTags(), tag])]);
                }}
              />
            ))
          )}
        </box>
      </box>
    }
  />
);

const Entry = () => {
  let debounceTimer: any;
  const onChanged = async (self: Gtk.Entry) => {
    // Clear the previous timeout if any
    if (debounceTimer) clearTimeout(debounceTimer);

    // Set a new timeout with the desired delay (e.g., 300ms)
    debounceTimer = setTimeout(() => {
      if (!self.text) {
        setFetchedTags([]);
        return;
      }
      fetchTags(self.text);
    }, 200);
  };

  const addTags = (self: Gtk.Entry) => {
    const currentTags = booruTags();
    const newTags = self.text.split(" ");

    // Create a Set to remove duplicates
    const uniqueTags = [...new Set([...currentTags, ...newTags])];

    setBooruTags(uniqueTags);
  };

  return (
    <entry
      hexpand
      placeholderText="Add a Tag"
      onChanged={onChanged}
      onActivate={addTags}
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
      onClicked={(self) => {
        cleanUp();
      }}
    />
  );
};

const BottomBar = () => (
  <Eventbox
    class={"bottom-Eventbox"}
    child={
      <box class={"bottom"} spacing={5} orientation={Gtk.Orientation.VERTICAL}>
        <PageDisplay />
        <LimitDisplay />
        <box
          class="bottom-bar"
          orientation={Gtk.Orientation.VERTICAL}
          spacing={5}
        >
          <TagDisplay />
          <box spacing={5}>
            <Entry />
            <ClearCacheButton />
          </box>
        </box>
      </box>
    }
  />
);

export default () => {
  ensureRatingTagFirst();
  // Note: If booruPage, booruTags, booruApi, booruLimit are Accessors, subscriptions are handled automatically
  fetchImages();
  return (
    <box
      class="booru"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      spacing={10}
    >
      <Apis />
      <Images />
      <BottomBar />
    </box>
  );
};
