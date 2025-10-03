import { Gtk } from "astal/gtk3";
import { Waifu } from "../../../interfaces/waifu.interface";
import { bind, exec, execAsync, Variable } from "astal";
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
} from "../../../variables";
import ToggleButton from "../../toggleButton";
import { notify } from "../../../utils/notification";
import { closeProgress, openProgress } from "../../Progress";

import { booruApis } from "../../../constants/api.constants";
import { ImageDialog } from "./ImageDialog";

const images = Variable<Waifu[]>([]);
const cacheSize = Variable<string>("0kb");

const fetchedTags = Variable<string[]>([]);

const imagePreviewPath = "./assets/booru/previews";
const imageUrlPath = "./assets/booru/images";

const calculateCacheSize = async () =>
  execAsync(`bash -c "du -sb ${imagePreviewPath} | cut -f1"`).then((res) => {
    // Convert bytes to megabytes
    cacheSize.set(`${Math.round(Number(res) / (1024 * 1024))}mb`);
  });

const ensureRatingTagFirst = () => {
  let tags: string[] = booruTags.get();
  // Find existing rating tag
  const ratingTag = tags.find((tag) => tag.match(/[-+]rating:explicit/));
  // Remove any existing rating tag
  tags = tags.filter((tag) => !tag.match(/[-+]rating:explicit/));
  // Add the previous rating tag at the beginning, or default to "-rating:explicit"
  tags.unshift(ratingTag ?? "-rating:explicit");
  booruTags.set(tags);
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
      images.set(successfulDownloads);
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
  <box className="api-list" spacing={5}>
    {booruApis.map((api) => (
      <ToggleButton
        hexpand
        state={bind(booruApi).as((a) => a.name === api.name)}
        className="api"
        label={api.name}
        onToggled={() => booruApi.set(api)}
      />
    ))}
  </box>
);

const fetchTags = async (tag: string) => {
  const escapedTag = tag.replace(/'/g, "'\\''");
  const res = await execAsync(
    `python ./scripts/search-booru.py 
    --api ${booruApi.get().value} 
    --tag '${escapedTag}'`
  );
  fetchedTags.set(readJson(res));
};

const Images = () => {
  return (
    <scrollable
      hexpand
      vexpand
      child={
        <box className="images" vertical spacing={5}>
          {bind(images).as((images) =>
            images
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
                        heightRequest={bind(leftPanelWidth).as((w) => w / 2)}
                        className="image"
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
    ></scrollable>
  );
};

const PageDisplay = () => (
  <box className="pages" spacing={5} halign={Gtk.Align.CENTER}>
    {bind(booruPage).as((p) => {
      const buttons = [];

      // Show "1" button if the current page is greater than 3
      if (p > 3) {
        buttons.push(
          <button
            className={"first"}
            label="1"
            onClicked={() => booruPage.set(1)}
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
            label={pageNum !== p ? String(pageNum) : ""}
            onClicked={() =>
              pageNum !== p ? booruPage.set(pageNum) : fetchImages()
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
    <box className="limits" spacing={5} hexpand>
      <label label={"Limit"}></label>
      <slider
        value={bind(booruLimit).as((l) => l / 100)}
        className={"slider"}
        // min={4}
        // max={20}
        step={0.1}
        hexpand
        onValueChanged={(self) => {
          // Clear the previous timeout if any
          if (debounceTimer) clearTimeout(debounceTimer);

          // Set a new timeout with the desired delay (e.g., 300ms)
          debounceTimer = setTimeout(() => {
            booruLimit.set(Math.round(self.value * 100));
          }, 300);
        }}
      />
      <label label={bind(booruLimit).as((l) => String(l))}></label>
    </box>
  );
};

const TagDisplay = () => (
  <scrollable
    hexpand
    vscroll={Gtk.PolicyType.NEVER}
    child={
      <box className={"tags"} spacing={10}>
        <box className="applied-tags" spacing={5}>
          {bind(booruTags).as((tags) =>
            tags.map((tag) => {
              // check if tag is rating tag
              if (tag.match(/[-+]rating:explicit/)) {
                return (
                  <button
                    className={`rating ${
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
                      booruTags.set(newTags);
                    }}
                  />
                );
              }
              return (
                <button
                  label={tag}
                  onClicked={() => {
                    const newTags = booruTags.get().filter((t) => t !== tag);
                    booruTags.set(newTags);
                  }}
                />
              );
            })
          )}
        </box>
        <box className={"fetched-tags"} spacing={5}>
          {bind(fetchedTags).as((tags) =>
            tags.map((tag) => (
              <button
                label={tag}
                onClicked={() => {
                  booruTags.set([...new Set([...booruTags.get(), tag])]);
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
        fetchedTags.set([]);
        return;
      }
      fetchTags(self.text);
    }, 200);
  };

  const addTags = (self: Gtk.Entry) => {
    const currentTags = booruTags.get();
    const newTags = self.text.split(" ");

    // Create a Set to remove duplicates
    const uniqueTags = [...new Set([...currentTags, ...newTags])];

    booruTags.set(uniqueTags);
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
      label={bind(cacheSize)}
      className="clear"
      onClicked={(self) => {
        cleanUp();
      }}
    />
  );
};

const BottomBar = () => (
  <eventbox
    className={"bottom-eventbox"}
    child={
      <box className={"bottom"} spacing={5} vertical>
        <PageDisplay />
        <LimitDisplay />
        <box className="bottom-bar" vertical spacing={5}>
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
  booruPage.subscribe(() => fetchImages());
  booruTags.subscribe(() => fetchImages());
  booruApi.subscribe(() => fetchImages());
  booruLimit.subscribe(() => fetchImages());
  fetchImages();
  return (
    <box className="booru" vertical hexpand spacing={10}>
      <Apis />
      <Images />
      <BottomBar />
    </box>
  );
};
