import { exec, execAsync } from "ags/process";
import { notify } from "../utils/notification";
import { Api, ApiClass } from "../interfaces/api.interface";
import Gtk from "gi://Gtk?version=4.0";
import Gio from "gi://Gio?version=2.0";
import Pango from "gi://Pango";
import GdkPixbuf from "gi://GdkPixbuf";
import { booruPath } from "../constants/path.constants";
import { globalSettings, setGlobalSetting } from "../variables";
import { Accessor, createState, Setter } from "ags";
import Picture from "../widgets/Picture";
import Video from "../widgets/Video";
import { Progress } from "../widgets/Progress";
import { booruApis } from "../constants/api.constants";
import GLib from "gi://GLib";

/**
 * Unified BooruImage class
 *
 * This class serves as the single source of truth for:
 * - Image data and metadata
 * - Booru metadata (tags, rating, source, etc.)
 * - Rendering logic for different contexts
 * - Widget behaviors and actions
 *
 * Replaces the old Waifu interface and WaifuClass
 */
export class BooruImage {
  // ═══════════════════════════════════════════════════════════════
  // Core data & state
  // ═══════════════════════════════════════════════════════════════

  id: number;
  width: number;
  height: number;
  api: Api;
  tags: string[];
  extension?: string;
  url?: string;
  preview?: string;

  // Runtime state (not serialized)
  private _isDownloaded?: boolean;
  private _isBookmarked?: boolean;

  private _loadingState: Accessor<"loading" | "error" | "success" | "idle">;
  private _setLoadingState: Setter<"loading" | "error" | "success" | "idle">;

  // ═══════════════════════════════════════════════════════════════
  // Constructor
  // ═══════════════════════════════════════════════════════════════

  constructor(data: Partial<BooruImage> = {}) {
    this.id = data.id ?? 0;
    this.width = data.width ?? 0;
    this.height = data.height ?? 0;
    this.api = data.api ?? new ApiClass();
    this.tags = data.tags ?? [];
    this.extension = data.extension;
    this.url = data.url;
    this.preview = data.preview;
    [this._loadingState, this._setLoadingState] = createState<
      "loading" | "error" | "success" | "idle"
    >("idle");
  }

  // ═══════════════════════════════════════════════════════════════
  // Data & utility methods
  // ═══════════════════════════════════════════════════════════════

  /**
   * Get the full path to the original image file
   */
  getImagePath(): string {
    return `${booruPath}/${this.api.value}/images/${this.id}.${this.extension}`;
  }

  /**
   * Get the full path to the preview image file
   */
  getPreviewPath(): string {
    return `${booruPath}/${this.api.value}/previews/${this.id}.${this.extension}`;
  }

  /**
   * Get the original image URL
   */
  getOriginalUrl(): string | undefined {
    return this.url;
  }

  /**
   * Get the preview image URL
   */
  getPreviewUrl(): string | undefined {
    return this.preview;
  }

  /**
   * Calculate aspect ratio
   */
  getAspectRatio(): number {
    return this.width && this.height ? this.width / this.height : 1;
  }

  /**
   * Check if the image is a video format
   */
  isVideo(): boolean {
    const videoExtensions = ["mp4", "webm", "mkv", "gif", "zip"];
    return this.extension ? videoExtensions.includes(this.extension) : false;
  }

  /**
   * Check if image file exists locally
   */
  isDownloaded(): boolean {
    if (this._isDownloaded !== undefined) return this._isDownloaded;

    const result = exec(
      `bash -c "[ -e '${this.getImagePath()}' ] && echo 'exists' || echo 'not-exists'"`,
    );
    this._isDownloaded = result.trim() === "exists";
    return this._isDownloaded;
  }

  /**
   * Check if image is bookmarked
   */
  isBookmarked(): boolean {
    if (this._isBookmarked !== undefined) return this._isBookmarked;

    const currentBookmarks = globalSettings.peek().booru.bookmarks;
    this._isBookmarked = currentBookmarks.some(
      (img) => img.id === this.id && img.api.value === this.api.value,
    );
    return this._isBookmarked;
  }

  /**
   * Get image ratio for proper display sizing
   */
  getImageRatio(path?: string): number {
    try {
      const pixbuf = GdkPixbuf.Pixbuf.new_from_file(
        path ?? this.getImagePath(),
      );
      return pixbuf.get_height() / pixbuf.get_width();
    } catch {
      return 1;
    }
  }

  /**
   * Download/fetch the image to local cache
   */
  async fetchImage(): Promise<void> {
    this._setLoadingState("loading");

    try {
      await execAsync(
        `bash -c "mkdir -p ${booruPath}/${this.api.value}/images"`,
      );

      await execAsync(
        `bash -c "[ -e '${this.getImagePath()}' ] || curl -o ${this.getImagePath()} ${
          this.url
        }"`,
      );

      this._isDownloaded = true;
      this._setLoadingState("success");
    } catch (err) {
      this._setLoadingState("error");
      notify({ summary: "Error", body: String(err) });
      throw err;
    }
  }

  /**
   * Copy image to clipboard
   */
  async copyToClipboard(): Promise<void> {
    try {
      await execAsync(
        `bash -c "wl-copy --type image/png < ${this.getImagePath()}"`,
      );
      notify({ summary: "Success", body: "Image copied to clipboard" });
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
    }
  }

  /**
   * Open image in external viewer
   */
  async openInViewer(): Promise<void> {
    try {
      await execAsync(
        `swayimg -w 690,690 --class 'preview-image' ${this.getImagePath()}`,
      );
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
    }
  }

  /**
   * Open image's source page in browser
   */
  async openInBrowser(): Promise<void> {
    try {
      const browser = await execAsync(
        `bash -c "xdg-open '${this.api.idSearchUrl}${this.id}' && xdg-settings get default-web-browser | sed 's/\\.desktop$//'"`,
      );
      notify({ summary: "Success", body: `Opened in ${browser}` });
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
    }
  }

  /**
   * Pin image to terminal background
   */
  async pinToTerminal(): Promise<void> {
    const terminalWaifuPath = `$HOME/.config/fastfetch/assets/logo.webp`;

    try {
      const output = await execAsync(
        `bash -c "[ -f ${terminalWaifuPath} ] && { rm ${terminalWaifuPath}; echo 1; } || { cwebp -q 75 ${this.getImagePath()} -o ${terminalWaifuPath}; echo 0; } && pkill -SIGUSR1 zsh"`,
      );

      notify({
        summary: "Waifu",
        body:
          Number(output) === 0
            ? "Pinned To Terminal"
            : "UN-Pinned from Terminal",
      });
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
    }
  }

  /**
   * Add/remove bookmark
   */
  toggleBookmark(): void {
    const currentBookmarks = globalSettings.peek().booru.bookmarks;
    const exists = this.isBookmarked();

    if (exists) {
      const updatedBookmarks = currentBookmarks.filter(
        (img) => !(img.id === this.id && img.api.value === this.api.value),
      );
      setGlobalSetting("booru.bookmarks", updatedBookmarks);
      notify({ summary: "Success", body: "Bookmark removed" });
      this._isBookmarked = false;
    } else {
      const updatedBookmarks = [...currentBookmarks, this.toJSON()];
      setGlobalSetting("booru.bookmarks", updatedBookmarks);
      notify({ summary: "Success", body: "Image bookmarked" });
      this._isBookmarked = true;
    }
  }

  /**
   * Add image to wallpapers folder
   */
  async addToWallpapers(): Promise<void> {
    try {
      await execAsync(
        `bash -c "cp ${this.getImagePath()} ~/.config/wallpapers/custom/${
          this.id
        }.${this.extension}"`,
      );
      notify({ summary: "Success", body: "Image added to wallpapers" });
    } catch (err) {
      notify({ summary: "Error", body: String(err) });
    }
  }

  /**
   * Set this image as the current waifu
   */
  setAsCurrentWaifu(): void {
    setGlobalSetting("waifuWidget.current", this.toJSON());
  }

  /**
   * Format tags for display
   */
  getFormattedTags(limit?: number): string[] {
    const tags = limit ? this.tags.slice(0, limit) : this.tags;
    return tags;
  }

  /**
   * Get dimension string (e.g., "1920x1080")
   */
  getDimensionsString(): string {
    return `${this.width}x${this.height}`;
  }

  /**
   * Serialize to plain object (for storage)
   */
  toJSON(): any {
    return {
      id: this.id,
      width: this.width,
      height: this.height,
      api: this.api,
      tags: this.tags,
      extension: this.extension,
      url: this.url,
      preview: this.preview,
    };
  }

  /**
   * Create instance from plain object
   */
  static fromJSON(data: any): BooruImage {
    return new BooruImage(data);
  }

  /**
   * Fetch image by ID from booru API
   *
   * @param id - The image ID to fetch
   * @param api - The booru API to use
   * @returns Promise resolving to BooruImage instance with downloaded image
   */
  async fetchById(id: number, api: Api): Promise<BooruImage> {
    try {
      this._setLoadingState("loading");
      const { readJson } = await import("../utils/json");

      const res = await execAsync(
        `python ./scripts/search-booru.py 
    --api ${api.value} 
    --id ${id}`,
      );

      print("API Response:", res);

      const imageData = readJson(res)[0];
      const image = new BooruImage({
        ...imageData,
        api: api,
      });

      // Automatically fetch the image file
      await image.fetchImage();
      this._setLoadingState("success");

      return image;
    } catch (err) {
      this._setLoadingState("error");
      notify({ summary: "Error", body: String(err) });
      throw err;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Rendering methods
  // ═══════════════════════════════════════════════════════════════

  /**
   * Render as image dialog (full-featured preview)
   *
   * Used in: BooruViewer grid items
   * Shows: Large preview, tags, all action buttons
   */
  renderAsImageDialog(options?: {
    width?: number;
    height?: number;
    maxTags?: number;
  }): any {
    const opts = {
      width: 300,
      height: 300,
      maxTags: 10,
      ...options,
    };

    // State management
    const [isDownloaded, setIsDownloaded] = createState<boolean>(
      this.isDownloaded(),
    );
    const [isBookmarked, setIsBookmarked] = createState<boolean>(
      this.isBookmarked(),
    );

    const imageRatio = this.getAspectRatio();
    const displayWidth = imageRatio >= 1 ? opts.width * imageRatio : opts.width;
    const displayHeight =
      imageRatio >= 1 ? opts.height : opts.height / imageRatio;

    // Tags component
    const Tags = () => (
      <Gtk.FlowBox class="tags" rowSpacing={5} columnSpacing={5}>
        {this.getFormattedTags(opts.maxTags).map((tag) => (
          <button
            class="tag"
            tooltipText={tag}
            onClicked={() => {
              execAsync(`bash -c "echo -n '${tag}' | wl-copy"`).catch((err) =>
                notify({ summary: "Error", body: String(err) }),
              );
            }}
          >
            <label
              ellipsize={Pango.EllipsizeMode.END}
              maxWidthChars={10}
              label={tag}
            />
          </button>
        ))}
      </Gtk.FlowBox>
    );

    // Actions component
    const Actions = () => (
      <box class="actions" spacing={10} orientation={Gtk.Orientation.VERTICAL}>
        <box class="section">
          <button
            label=""
            tooltip-text="Open in browser"
            onClicked={() => this.openInBrowser()}
            hexpand
          />
          <togglebutton
            class="button"
            label={isBookmarked((bookmarked) => (bookmarked ? "󰧌" : ""))}
            tooltip-text="Bookmark image"
            active={isBookmarked}
            onClicked={(self) => {
              this.toggleBookmark();
              setIsBookmarked(self.active);
            }}
            hexpand
          />
        </box>
        <box class="section">
          <button
            label=""
            tooltip-text="Download image"
            sensitive={isDownloaded((is) => !is)}
            onClicked={() =>
              this.fetchImage()
                .then(() => setIsDownloaded(true))
                .catch(() => {})
            }
            hexpand
          />
          <button
            label=""
            tooltipMarkup={isDownloaded((is) =>
              is ? "Copy image" : "<b>Download</b> first to copy",
            )}
            sensitive={isDownloaded}
            onClicked={() => this.copyToClipboard()}
            hexpand
          />
          <button
            label=""
            tooltipMarkup={isDownloaded((is) =>
              is ? "Set as current waifu" : "<b>Download</b> first to set",
            )}
            sensitive={isDownloaded}
            onClicked={() => this.setAsCurrentWaifu()}
            hexpand
          />
          <button
            label=""
            tooltipMarkup={isDownloaded((is) =>
              is ? "Open in viewer" : "<b>Download</b> first to open",
            )}
            sensitive={isDownloaded}
            onClicked={() => this.openInViewer()}
            hexpand
          />
          <button
            label=""
            tooltipMarkup={isDownloaded((is) =>
              is ? "Pin to terminal" : "<b>Download</b> first to pin",
            )}
            sensitive={isDownloaded}
            onClicked={() => this.pinToTerminal()}
            hexpand
          />
          <button
            label="󰸉"
            tooltipMarkup={isDownloaded((is) =>
              is ? "Add to wallpapers" : "<b>Download</b> first to add",
            )}
            sensitive={isDownloaded}
            onClicked={() => this.addToWallpapers()}
            hexpand
          />
        </box>
      </box>
    );

    // Main dialog layout
    return (
      <overlay
        widthRequest={displayWidth}
        heightRequest={displayHeight}
        class="booru-image"
        $={async () => {
          setIsDownloaded(this.isDownloaded());
        }}
      >
        <Picture
          file={isDownloaded((is) =>
            is ? this.getImagePath() : this.getPreviewPath(),
          )}
          height={displayHeight}
          width={displayWidth}
          class="image"
        />
        <box
          $type="overlay"
          orientation={Gtk.Orientation.VERTICAL}
          widthRequest={displayWidth}
          heightRequest={displayHeight}
        >
          <Tags />
          <box vexpand />
          <Actions />
        </box>
      </overlay>
    );
  }

  /**
   * Render as waifu widget (compact display in right panel)
   *
   * Used in: Right panel waifu widget
   * Shows: Large image, minimal controls
   */
  renderAsWaifuWidget(options?: {
    width?: number;
    showProgress?: boolean;
    progressStatus?: "loading" | "error" | "success" | "idle";
    onProgressStatusChange?: (
      status: "loading" | "error" | "success" | "idle",
    ) => void;
  }): any {
    const [searchApi, setSearchApi] = createState<Api>(booruApis[0]);

    const opts = {
      width: 300,
      showProgress: false,
      progressStatus: "idle" as const,
      ...options,
    };

    // Calculate height based on aspect ratio
    const imageHeight =
      this.width && this.height
        ? (this.height / this.width) * opts.width
        : opts.width;

    const Entry = (
      <entry
        class="input"
        placeholderText="enter post ID"
        text={globalSettings.peek().waifuWidget.input_history || ""}
        onActivate={(self) => {
          this._setLoadingState("loading");
          this.fetchById(Number(self.text), this.api)
            .then((image) => {
              this._setLoadingState("success");
              this.url = image.url;

              setGlobalSetting("waifuWidget", {
                ...globalSettings.peek().waifuWidget,
                current: image.toJSON(),
                input_history: self.text,
              });
            })

            .catch(() => {
              this._setLoadingState("error");
            });
        }}
      />
    );

    // Actions component
    const Actions = () => (
      <box
        class="actions"
        valign={Gtk.Align.END}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={5}
      >
        <Progress status={this._loadingState} />
        <box class="section">
          <togglebutton
            class="button"
            label={this.isBookmarked() ? "󰧌" : ""}
            tooltip-text="Bookmark image"
            active={this.isBookmarked()}
            onClicked={(self) => {
              this.toggleBookmark();
            }}
            hexpand
          />
          <button
            label=""
            hexpand
            class="pin"
            sensitive={!this.isVideo()}
            tooltip-text="Pin image to terminal"
            onClicked={() => this.pinToTerminal()}
          />
        </box>
        <box class="section">
          <button
            label=""
            class="open"
            hexpand
            onClicked={() => this.openInViewer()}
          />
          <button
            label=""
            hexpand
            class="browser"
            onClicked={() => this.openInBrowser()}
          />
          <button
            label=""
            hexpand
            class="copy"
            onClicked={() => this.copyToClipboard()}
          />
        </box>
        <box class="section" spacing={5}>
          <button
            hexpand
            label=""
            class="entry-search"
            onClicked={() => (Entry as Gtk.Entry).activate()}
          />
          {Entry}
          <button
            hexpand
            label=""
            class="upload"
            onClicked={async (self) => {
              const dialog = new Gtk.FileDialog({
                title: "Open Image",
                modal: true,
              });

              const filter = new Gtk.FileFilter();
              filter.set_name("Images");
              filter.add_mime_type("image/png");
              filter.add_mime_type("image/jpeg");
              filter.add_mime_type("image/webp");
              filter.add_mime_type("image/gif");
              dialog.set_default_filter(filter);

              try {
                const root = self.get_root();
                if (!(root instanceof Gtk.Window)) return;

                const file: Gio.File = await new Promise((resolve, reject) => {
                  dialog.open(root, null, (dlg, res) => {
                    try {
                      resolve(dlg!.open_finish(res));
                    } catch (e) {
                      reject(e);
                    }
                  });
                });

                if (!file) return;

                const filename = file.get_path();
                if (!filename) return;

                const [height, width] = exec(
                  `identify -format "%h %w" "${filename}"`,
                ).split(" ");

                await execAsync(`mkdir -p "${booruPath}/custom/images"`).catch(
                  (err) => notify({ summary: "Error", body: String(err) }),
                );
                await execAsync(
                  `cp "${filename}" "${booruPath}/custom/images/-1.${filename
                    .split(".")
                    .pop()!}"`,
                ).catch((err) =>
                  notify({ summary: "Error", body: String(err) }),
                );

                const customImage = new BooruImage({
                  id: -1,
                  height: Number(height) || 0,
                  width: Number(width) || 0,
                  api: { name: "Custom", value: "custom" } as Api,
                  extension: filename.split(".").pop()!,
                  tags: ["custom"],
                });

                setGlobalSetting("waifuWidget.current", customImage.toJSON());
                notify({ summary: "Waifu", body: "Custom image set" });
              } catch (err) {
                if (
                  err instanceof GLib.Error &&
                  err.matches(
                    Gtk.dialog_error_quark(),
                    Gtk.DialogError.CANCELLED,
                  )
                )
                  return;
                notify({ summary: "Error", body: String(err) });
              }
            }}
          />
        </box>
        <box class="section" spacing={5}>
          {booruApis.map((api) => (
            <togglebutton
              hexpand
              class="api"
              label={api.name}
              active={searchApi((searchApi) => searchApi.value === api.value)}
              onToggled={({ active }) => {
                if (active) setSearchApi(api);
              }}
            />
          ))}
        </box>
      </box>
    );

    // Image or video display
    const ImageDisplay = () => {
      if (this.isVideo()) {
        return (
          <Video class="image" width={opts.width} file={this.getImagePath()} />
        );
      } else {
        return (
          <Picture
            class="image"
            height={imageHeight}
            file={this.getImagePath()}
            contentFit={Gtk.ContentFit.COVER}
          />
        );
      }
    };

    // Main widget layout
    return (
      <overlay class="booru-image">
        <ImageDisplay />

        <Actions $type="overlay" />
      </overlay>
    );
  }
}

// Export type alias for backward compatibility
export type Waifu = BooruImage;
