import { exec, execAsync } from "ags/process";
import { notify } from "../utils/notification";
import { Api, ApiClass } from "../interfaces/api.interface";
import Pango from "gi://Pango";
import GdkPixbuf from "gi://GdkPixbuf";
import { booruPath } from "../constants/path.constants";
import { globalSettings, setGlobalSetting } from "../variables";
import { Accessor, createRoot, createState, onCleanup, Setter } from "ags";
import Picture from "../widgets/Picture";
import Video from "../widgets/Video";
import { Progress } from "../widgets/Progress";
import { booruApis } from "../constants/api.constants";
import GLib from "gi://GLib";
import { connectPopoverEvents } from "../utils/window";

import Hyprland from "gi://AstalHyprland";
import { Gdk, Gtk } from "ags/gtk4";
import Gio from "gi://Gio";
const hyprland = Hyprland.get_default();

const booruScriptPath = `${GLib.get_home_dir()}/.config/ags/scripts/booru.py`;

type BookmarkActionResponse = {
  bookmarked?: boolean;
  bookmarks?: Array<Partial<BooruImage>>;
};

const parseBookmarkActionResponse = (raw: string): BookmarkActionResponse => {
  if (!raw?.trim()) {
    throw new Error("Received empty response from booru bookmark action");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw) as unknown;
  } catch {
    throw new Error(`Invalid bookmark response: ${raw.trim()}`);
  }

  if (typeof parsed !== "object" || parsed === null) {
    throw new Error("Invalid bookmark response format");
  }

  const envelope = parsed as {
    error?: boolean;
    message?: string;
  };
  if (envelope.error === true) {
    throw new Error(envelope.message?.trim() || "Bookmark action failed");
  }

  return parsed as BookmarkActionResponse;
};

/**
 * Pause any playing Gtk.Video in the subtree without destroying the pipeline.
 * Safe to call on popover close when the widget tree will be reused on reopen.
 */
function pauseVideoInWidget(widget: Gtk.Widget): void {
  if (widget instanceof Gtk.Video) {
    widget.get_media_stream()?.set_playing(false);
    return;
  }
  let child = widget.get_first_child();
  while (child) {
    pauseVideoInWidget(child);
    child = child.get_next_sibling();
  }
}

/**
 * Fully tear down any Gtk.Video GStreamer pipeline in the subtree.
 * Only call this when the widget tree is being permanently destroyed
 * (e.g. button "destroy"), not on a simple popover close.
 *
 * Full teardown sequence required to prevent crashes when a new Gtk.Video
 * is later created on the same GL display (confirmed by crash logs):
 *   1. set_playing(false)   – pause the pipeline
 *   2. MediaFile.clear()    – calls stream_unprepared(), releases GstGLContext
 *   3. set_media_stream(null) – detaches dead GL texture from the widget
 */
function teardownVideoInWidget(widget: Gtk.Widget): void {
  if (widget instanceof Gtk.Video) {
    const stream = widget.get_media_stream();
    if (stream) {
      stream.set_playing(false);
      if (stream instanceof Gtk.MediaFile) {
        stream.clear();
      }
    }
    widget.set_media_stream(null);
    return;
  }
  let child = widget.get_first_child();
  while (child) {
    teardownVideoInWidget(child);
    child = child.get_next_sibling();
  }
}

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

  private _loadingState!: Accessor<"loading" | "error" | "success" | "idle">;
  private _setLoadingState!: Setter<"loading" | "error" | "success" | "idle">;
  private static _bookmarkKeys = new Set<string>();
  private static _bookmarkCacheHydrated = false;

  // ═══════════════════════════════════════════════════════════════
  // Constructor
  // ═══════════════════════════════════════════════════════════════

  constructor(data: Partial<BooruImage> = {}) {
    const parsedId = Number(data.id);
    const parsedWidth = Number(data.width);
    const parsedHeight = Number(data.height);

    this.id = Number.isFinite(parsedId) ? parsedId : 0;
    this.width = Number.isFinite(parsedWidth) ? parsedWidth : 0;
    this.height = Number.isFinite(parsedHeight) ? parsedHeight : 0;
    this.api = data.api ? new ApiClass(data.api) : new ApiClass();
    this.tags = data.tags ?? [];
    this.extension = data.extension;
    this.url = data.url;
    this.preview = data.preview;
    // createState must be called inside a reactive root — wrap in createRoot
    // to give it a proper owner so AGS never crashes with "out of tracking context".
    createRoot(() => {
      [this._loadingState, this._setLoadingState] = createState<
        "loading" | "error" | "success" | "idle"
      >("idle");
    });
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
   * Check if the media is a video/animated format
   */
  isVideo(): boolean {
    const videoExtensions = ["mp4", "webm", "mkv", "gif"];
    return this.extension
      ? videoExtensions.includes(this.extension.toLowerCase())
      : false;
  }

  /**
   * Check if the media is a zip/ugoira archive (Pixiv animated format).
   * These cannot be rendered by Gtk.Video — always show a placeholder.
   */
  isZip(): boolean {
    return this.extension?.toLowerCase() === "zip";
  }

  /**
   * Probes the first bytes of a file to check if it is really a video/animation.
   *
   * Booru preview files for video content are often JPEG stills with video
   * extensions (.webm, .mp4, .gif, .zip). Passing a JPEG to Gtk.Video causes
   * a GStreamer GL pipeline crash (EGL/nvidia segfault). This probe detects
   * the mismatch before the widget is created.
   *
   * Returns false (treat as image) when:
   *   - file does not exist
   *   - file starts with FF D8 (JPEG magic)
   *   - file starts with 89 50 4E 47 (PNG magic)
   *   - xxd is not available
   * Returns true (treat as video) only when a known video magic is detected.
   */
  static probeFileIsRealVideo(path: string): boolean {
    try {
      const hex = exec(`xxd -p -l 12 "${path}"`).trim().toLowerCase();
      if (!hex || hex.length < 8) return false;
      // JPEG: FF D8 FF
      if (hex.startsWith("ffd8ff")) return false;
      // PNG: 89 50 4E 47
      if (hex.startsWith("89504e47")) return false;
      // WebM / MKV: starts with 1A 45 DF A3 (EBML)
      if (hex.startsWith("1a45dfa3")) return true;
      // MP4 / MOV: bytes 4-7 are "ftyp" (66 74 79 70)
      if (hex.slice(8, 16) === "66747970") return true;
      // GIF: 47 49 46 38 (GIF8)
      if (hex.startsWith("47494638")) return true;
      // RIFF/AVI: 52 49 46 46
      if (hex.startsWith("52494646")) return true;
      // Not a recognized video — treat as image to be safe
      return false;
    } catch {
      return false;
    }
  }

  /**
   * Check if media file exists locally
   */
  isDownloaded(): boolean {
    // Only cache a positive result — caching "false" would leave the flag
    // permanently stale after the file is downloaded during this session.
    if (this._isDownloaded === true) return true;

    const result = exec(
      `bash -c "[ -e '${this.getImagePath()}' ] && echo 'exists' || echo 'not-exists'"`,
    );
    if (result.trim() === "exists") {
      this._isDownloaded = true;
    }
    return this._isDownloaded ?? false;
  }

  /**
   * Check if media is bookmarked
   */
  isBookmarked(): boolean {
    const key = this.getBookmarkKey();
    if (BooruImage._bookmarkCacheHydrated) {
      this._isBookmarked = BooruImage._bookmarkKeys.has(key);
      return this._isBookmarked;
    }

    if (this._isBookmarked !== undefined) return this._isBookmarked;

    const currentBookmarks = globalSettings.peek().booru.bookmarks;
    // .some() always returns boolean, so the assignment is always boolean.
    const bookmarked = currentBookmarks.some(
      (img: any) => img.id === this.id && img.api?.value === this.api.value,
    );
    this._isBookmarked = bookmarked;

    if (bookmarked) {
      BooruImage._bookmarkKeys.add(key);
    }

    return bookmarked;
  }

  private getBookmarkKey(): string {
    return `${this.id}:${this.api.value}`;
  }

  static syncBookmarkCache(bookmarks: Array<Partial<BooruImage>>): void {
    const next = new Set<string>();

    for (const bookmark of bookmarks) {
      const bookmarkId = bookmark?.id;
      const apiValue = bookmark?.api?.value;
      if (typeof bookmarkId === "number" && typeof apiValue === "string") {
        next.add(`${bookmarkId}:${apiValue}`);
      }
    }

    BooruImage._bookmarkKeys = next;
    BooruImage._bookmarkCacheHydrated = true;
  }

  /**
   * Get media ratio for proper display sizing
   */
  getImageRatio(path?: string): number {
    // Prefer the already-known metadata dimensions — loading a full GdkPixbuf
    // just to read size is expensive and can OOM with many images in a grid.
    if (!path && this.width && this.height) {
      return this.height / this.width;
    }
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
   * Download/fetch the media to local cache
   */
  async fetchImage(): Promise<void> {
    this._setLoadingState("loading");

    try {
      const imagePath = this.getImagePath();
      const imageUrl = this.getOriginalUrl();

      if (!imageUrl) {
        throw new Error("Media URL is not available");
      }

      await execAsync(["mkdir", "-p", `${booruPath}/${this.api.value}/images`]);

      if (Gio.File.new_for_path(imagePath).query_exists(null)) {
        this._isDownloaded = true;
        this._setLoadingState("success");
        return;
      }

      const curlArgs = ["curl", "-f", "-o", imagePath];

      if (this.api.value === "gelbooru") {
        curlArgs.splice(
          1,
          0,
          "-L",
          "-H",
          "Referer: https://gelbooru.com/",
          "-A",
          "Mozilla/5.0",
        );
      }

      curlArgs.push(imageUrl);

      await execAsync(curlArgs);

      this._isDownloaded = true;
      this._setLoadingState("success");
    } catch (err) {
      this._setLoadingState("error");
      const errorMessage = err instanceof Error ? err.message : String(err);
      notify({ summary: "Error fetching media", body: errorMessage });
      throw err;
    }
  }

  /**
   * Copy media to clipboard (images only)
   */
  async copyToClipboard(): Promise<void> {
    try {
      if (this.isVideo()) {
        throw new Error("Cannot copy video to clipboard");
      }
      await execAsync([
        "bash",
        "-c",
        `wl-copy --type image/png < '${this.getImagePath()}'`,
      ]);
      notify({ summary: "Success", body: "Image copied to clipboard" });
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      notify({ summary: "Error copying to clipboard", body: errorMessage });
    }
  }

  /**
   * Open media in external viewer
   */
  async openInViewer(isVideo?: boolean): Promise<void> {
    try {
      if (isVideo) {
        const videoPath = this.getImagePath();
        hyprland.dispatch(
          "exec",
          `bash -c "mpv --force-window=immediate --no-terminal --title='${this.id}' '${videoPath}'"`,
        );
      } else {
        hyprland.dispatch(
          "exec",
          `bash -c "swayimg -w 690,690 --class 'preview-image' ${this.getImagePath()}"`,
        );
      }
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      notify({ summary: "Error opening in viewer", body: errorMessage });
    }
  }

  /**
   * Open media's source page in browser
   */
  async openInBrowser(): Promise<void> {
    try {
      const browser = await execAsync(
        `bash -c "xdg-open '${this.api.idSearchUrl}${this.id}' && xdg-settings get default-web-browser | sed 's/\\.desktop$//'"`,
      );
      notify({ summary: "Success", body: `Opened in ${browser}` });
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      notify({ summary: "Error opening in browser", body: errorMessage });
    }
  }

  /**
   * Build cache path for terminal pinning.
   * Always store as WebP to reduce size while keeping transparent corners.
   */
  private getTerminalPinnedPath(): string | null {
    const sourceImagePath = this.getImagePath();
    const sourceFile = Gio.File.new_for_path(sourceImagePath);
    const sourceBasename = sourceFile.get_basename();

    if (!sourceBasename) return null;

    const cacheDir = `${GLib.get_home_dir()}/.config/fastfetch/cache`;
    const stem = sourceBasename.replace(/\.[^.]+$/, "");
    return `${cacheDir}/${stem}.webp`;
  }

  /**
   * Check if this media is currently pinned for fastfetch
   */
  isPinnedToTerminal(): boolean {
    const pinnedPath = this.getTerminalPinnedPath();
    return !!pinnedPath && Gio.File.new_for_path(pinnedPath).query_exists(null);
  }

  /**
   * Pin image to terminal background (images only)
   */
  async pinToTerminal(): Promise<void> {
    if (this.isVideo()) {
      notify({
        summary: "Error pinning to terminal",
        body: "Cannot pin videos to terminal",
      });
      return;
    }

    const CORNER_RADIUS_PERCENT = 5;
    const cacheDir = `${GLib.get_home_dir()}/.config/fastfetch/cache`;
    const sourceImagePath = this.getImagePath();
    const sourceFile = Gio.File.new_for_path(sourceImagePath);
    const terminalWaifuPath = this.getTerminalPinnedPath();

    if (!terminalWaifuPath) {
      notify({
        summary: "Error pinning to terminal",
        body: "Invalid image path",
      });
      return;
    }

    try {
      await execAsync(["mkdir", "-p", cacheDir]);

      if (!sourceFile.query_exists(null)) {
        throw new Error("Image file does not exist locally");
      }

      const pinnedFileExists =
        Gio.File.new_for_path(terminalWaifuPath).query_exists(null);

      if (pinnedFileExists) {
        await execAsync(["rm", "-f", terminalWaifuPath]);

        notify({ summary: "Waifu", body: "UN-Pinned from Terminal" });
      } else {
        const radius = `%[fx:min(w,h)*${CORNER_RADIUS_PERCENT / 100}]`;

        await execAsync([
          "magick",
          sourceImagePath,
          "-alpha",
          "set",
          "(",
          "+clone",
          "-alpha",
          "transparent",
          "-background",
          "none",
          "-fill",
          "white",
          "-draw",
          `roundrectangle 0,0,%[fx:w-1],%[fx:h-1],${radius},${radius}`,
          ")",
          "-compose",
          "Dst_In",
          "-composite",
          "-strip",
          "-quality",
          "82",
          "-define",
          "webp:method=6",
          "-define",
          "webp:alpha-quality=90",
          "-background",
          "none",
          terminalWaifuPath,
        ]);

        notify({ summary: "Waifu", body: "Pinned To Terminal" });
      }

      await execAsync(["bash", "-c", "pkill -SIGUSR1 zsh || true"]);
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      notify({ summary: "Error pinning to terminal", body: errorMessage });
    }
  }

  /**
   * Add/remove bookmark
   */
  async toggleBookmark(): Promise<boolean> {
    try {
      const payload = JSON.stringify({ bookmark: this.toJSON() });
      const response = await execAsync([
        "python",
        booruScriptPath,
        "--action",
        "toggle-bookmark",
        "--payload-json",
        payload,
      ]);

      const parsed = parseBookmarkActionResponse(response);
      const isBookmarked = parsed.bookmarked === true;

      if (Array.isArray(parsed.bookmarks)) {
        BooruImage.syncBookmarkCache(parsed.bookmarks);
        setGlobalSetting("booru.bookmarks", parsed.bookmarks);
      } else {
        BooruImage._bookmarkCacheHydrated = true;
        if (isBookmarked) {
          BooruImage._bookmarkKeys.add(this.getBookmarkKey());
          const currentBookmarks = globalSettings.peek().booru.bookmarks;
          const exists = currentBookmarks.some(
            (img) => img.id === this.id && img.api.value === this.api.value,
          );
          if (!exists) {
            setGlobalSetting("booru.bookmarks", [
              ...currentBookmarks,
              this.toJSON(),
            ]);
          }
        } else {
          BooruImage._bookmarkKeys.delete(this.getBookmarkKey());
          setGlobalSetting(
            "booru.bookmarks",
            globalSettings
              .peek()
              .booru.bookmarks.filter(
                (img) =>
                  !(img.id === this.id && img.api.value === this.api.value),
              ),
          );
        }
      }

      this._isBookmarked = isBookmarked;
      notify({
        summary: "Success",
        body: isBookmarked ? "Image bookmarked" : "Bookmark removed",
      });

      return isBookmarked;
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      notify({ summary: "Error updating bookmark", body: errorMessage });
      throw err;
    }
  }

  /**
   * Add media to wallpapers folder
   */
  async addToWallpapers(): Promise<void> {
    try {
      await execAsync([
        "cp",
        this.getImagePath(),
        `${GLib.get_home_dir()}/.config/wallpapers/custom/${this.id}.${this.extension}`,
      ]);
      notify({ summary: "Success", body: "Media added to wallpapers" });
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err);
      notify({ summary: "Error adding to wallpapers", body: errorMessage });
    }
  }

  /**
   * Set this media as the current waifu
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
      api: {
        name: this.api.name,
        value: this.api.value,
        icon: this.api.icon,
        description: this.api.description,
        idSearchUrl: this.api.idSearchUrl,
        imageGenerationSupport: this.api.imageGenerationSupport,
      },
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
   * Fetch media by ID from booru API
   *
   * @param id - The media ID to fetch
   * @param api - The booru API to use
   * @returns Promise resolving to BooruImage instance with downloaded media
   */
  async fetchById(id: number, api: Api): Promise<BooruImage> {
    try {
      this._setLoadingState("loading");
      const { readJson } = await import("../utils/json");
      const settings = globalSettings.peek();

      const res = await execAsync(
        `python ${GLib.get_home_dir()}/.config/ags/scripts/booru.py ` +
          `--api ${api.value} ` +
          `--id ${id} ` +
          `--api-user ${settings.apiKeys[settings.booru.api.value as keyof typeof settings.apiKeys].user.value} ` +
          `--api-key ${settings.apiKeys[settings.booru.api.value as keyof typeof settings.apiKeys].key.value} `,
      );

      const imageData = readJson(res)[0];
      const image = new BooruImage({
        ...imageData,
        api: api,
      });

      // Automatically fetch the media file
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
    columnWidth?: number;
  }): any {
    const opts = {
      width: 300,
      height: 300,
      maxTags: 10,
      columnWidth: 100,
      ...options,
    };

    let info: string[] = [];
    this.isPinnedToTerminal() && info.push("");
    (this.tags.includes("animated") || this.isVideo()) && info.push("");

    // Create the button
    const button = (
      <menubutton
        class="image-button"
        hexpand
        widthRequest={opts.columnWidth}
        heightRequest={opts.columnWidth * (this.height / this.width)}
        direction={Gtk.ArrowType.RIGHT}
        tooltipMarkup={`Click to Open\nLeft Click to Open in Browser\n<b>ID:</b> ${this.id}\n<b>Dimensions:</b> ${this.width}x${this.height}`}
      >
        <Picture
          file={this.getPreviewPath()}
          contentFit={Gtk.ContentFit.COVER}
          class="image"
          info={info}
        />
      </menubutton>
    ) as Gtk.MenuButton;

    // Create popover with deferred content creation
    const popover = new Gtk.Popover();
    popover.add_css_class("popover-open");

    // Only create the dialog content when popover is first shown.
    // The dispose function from createRoot is saved so we can clean up all
    // reactive subscriptions when the popover closes, preventing memory leaks.
    let contentCreated = false;
    let disposeRoot: (() => void) | null = null;
    // videoWidget is declared here (outside createRoot) so the keyboard
    // controller, which also lives outside createRoot, can close over it.
    let videoWidget: Gtk.Video | null = null;
    const container = new Gtk.Box();

    popover.connect("show", () => {
      if (contentCreated) return;

      const dialogContent = createRoot((dispose: () => void) => {
        disposeRoot = dispose;
        const [currentlyDownloaded, setCurrentlyDownloaded] = createState(
          this.isDownloaded(),
        );
        const [currentlyBookmarked, setCurrentlyBookmarked] = createState(
          this.isBookmarked(),
        );
        const [currentlyPinned, setCurrentlyPinned] = createState(
          this.isPinnedToTerminal(),
        );

        const imageRatio = this.getAspectRatio();
        const displayWidth =
          imageRatio >= 1 ? opts.width * imageRatio : opts.width;
        const displayHeight =
          imageRatio >= 1 ? opts.height : opts.height / imageRatio;

        // Tags component
        const Tags = (
          <Gtk.FlowBox class="tags" rowSpacing={5} columnSpacing={5}>
            {this.getFormattedTags(opts.maxTags).map((tag) => (
              <button
                class="tag"
                tooltipText={tag}
                onClicked={() => {
                  execAsync(`bash -c "echo -n '${tag}' | wl-copy"`).catch(
                    (err) => notify({ summary: "Error", body: String(err) }),
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

        // ─────────────────────────────────

        // Media display component (handles both images and videos)
        const MediaDisplay = () => {
          // Zip/ugoira archives cannot be rendered — show a placeholder.
          if (this.isZip()) {
            return (
              <box
                class="media zip-placeholder"
                widthRequest={displayWidth}
                heightRequest={displayHeight}
                orientation={Gtk.Orientation.VERTICAL}
                halign={Gtk.Align.FILL}
                valign={Gtk.Align.FILL}
              >
                <box vexpand />
                <label label="󰗄" class="zip-icon" halign={Gtk.Align.CENTER} />
                <label
                  class="zip-label"
                  label="This type of video file cannot be played."
                  halign={Gtk.Align.CENTER}
                  justify={Gtk.Justification.CENTER}
                  wrap={true}
                />
                <label
                  class="zip-hint"
                  label="Open in browser to view media."
                  halign={Gtk.Align.CENTER}
                  justify={Gtk.Justification.CENTER}
                  wrap={true}
                />
                <box vexpand />
              </box>
            );
          }

          if (this.isVideo()) {
            // Booru video previews are always JPEG stubs — the real video only
            // exists once the user downloads it. We cannot switch widget types
            // reactively (GTK widget type is fixed at construction), so we
            // render BOTH widgets up front and toggle visibility:
            //   • Gtk.Picture (preview JPEG) shown while not yet downloaded
            //   • Gtk.Video   (full file)    shown once downloaded
            const previewPath = this.getPreviewPath();
            const imagePath = this.getImagePath();

            // The video frame — used as the overlay base.
            // State (isPlaying, videoTimestamp, videoDuration, isSeeking, videoWidget)
            // is hoisted above MediaDisplay so VideoControls can share it.
            const VideoFrame = (
              <box
                heightRequest={displayHeight}
                widthRequest={displayWidth}
                class="media video-container"
              >
                <Gtk.Picture
                  visible={currentlyDownloaded((d) => !d)}
                  file={Gio.File.new_for_path(previewPath)}
                  heightRequest={displayHeight}
                  widthRequest={displayWidth}
                  hexpand={true}
                  vexpand={true}
                  class="image"
                  contentFit={Gtk.ContentFit.COVER}
                />
                <Gtk.Video
                  class="media"
                  widthRequest={displayWidth}
                  heightRequest={displayHeight}
                  hexpand={true}
                  vexpand={true}
                  visible={currentlyDownloaded}
                  file={Gio.File.new_for_path(imagePath)}
                  autoplay={true}
                  loop={true}
                  $={(self: Gtk.Video) => {
                    videoWidget = self;

                    const attachStream = (stream: Gtk.MediaStream | null) => {
                      if (!stream) return;

                      // Force looping and playback directly in the stream
                      stream.set_loop(true);
                      stream.set_playing(true);

                      // Insurance for ultra-short videos: we guarantee a start immediately after GStreamer "prepares" the file
                      stream.connect("notify::prepared", () => {
                        if ((stream as any).get_prepared()) {
                          stream.set_loop(true);
                          stream.set_playing(true);
                        }
                      });
                    };

                    attachStream(self.get_media_stream());
                    const hStream = self.connect("notify::media-stream", () =>
                      attachStream(self.get_media_stream()),
                    );

                    // Click on the video frame to toggle play/pause (YouTube-style).
                    // Must use CAPTURE phase — Gtk.Video's internal GL sink widget
                    // consumes pointer events in the BUBBLE phase before they reach
                    // a controller added to the outer Gtk.Video widget. CAPTURE
                    // intercepts the event on the way DOWN (before any child sees it).
                    const clickGesture = new Gtk.GestureClick();
                    clickGesture.set_button(1); // left click only
                    clickGesture.set_propagation_phase(
                      Gtk.PropagationPhase.CAPTURE,
                    );
                    clickGesture.connect("pressed", () => {
                      const stream = self.get_media_stream();
                      if (stream) stream.set_playing(!stream.get_playing());
                    });
                    self.add_controller(clickGesture);

                    self.connect("unrealize", () => {
                      const stream = self.get_media_stream();
                      if (stream) {
                        stream.set_playing(false);
                        if (stream instanceof Gtk.MediaFile) stream.clear();
                      }
                      self.set_media_stream(null);
                      videoWidget = null;
                    });

                    onCleanup(() => self.disconnect(hStream));
                  }}
                />
              </box>
            );

            // MediaDisplay returns only the video frame (no controls).
            // VideoControls is the hoisted widget placed outside the overlay.
            return VideoFrame;
          }

          return (
            <Gtk.Picture
              file={currentlyDownloaded((downloaded) => {
                const path = downloaded
                  ? this.getImagePath()
                  : this.getPreviewPath();
                const file = Gio.File.new_for_path(path);
                return file.query_exists(null)
                  ? file
                  : Gio.File.new_for_path(this.getPreviewPath());
              })}
              heightRequest={displayHeight}
              widthRequest={displayWidth}
              class="image"
              contentFit={Gtk.ContentFit.COVER}
            />
          );
        };

        // Actions component
        const Actions = (
          <box
            class="actions"
            spacing={10}
            orientation={Gtk.Orientation.VERTICAL}
          >
            <box class="section">
              <button
                label=""
                tooltip-text="Open in browser"
                onClicked={() => this.openInBrowser()}
                hexpand
              />
              <togglebutton
                class="button"
                label={currentlyBookmarked((bookmarked) =>
                  bookmarked ? "󰧌" : "",
                )}
                tooltip-text="Bookmark media"
                active={currentlyBookmarked}
                onClicked={(self) => {
                  this.toggleBookmark()
                    .then((bookmarked) => setCurrentlyBookmarked(bookmarked))
                    .catch(() => {});
                }}
                hexpand
              />
            </box>
            <box class="section">
              <button
                label=""
                tooltip-text="Download media"
                sensitive={currentlyDownloaded((downloaded) => !downloaded)}
                onClicked={(self) =>
                  this.fetchImage()
                    .then(async () => {
                      self.sensitive = false;
                      // Wait a bit to ensure file is fully written.
                      // GJS does not have setTimeout — use GLib.timeout_add instead.
                      await new Promise<void>((resolve) =>
                        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
                          resolve();
                          return GLib.SOURCE_REMOVE;
                        }),
                      );
                      // Verify file exists before updating state
                      const imagePath = this.getImagePath();
                      const file = Gio.File.new_for_path(imagePath);
                      if (file.query_exists(null)) {
                        setCurrentlyDownloaded(true);
                      }
                    })
                    .catch(() => {})
                }
                hexpand
              />
              <button
                label=""
                tooltipMarkup={currentlyDownloaded((downloaded) =>
                  downloaded
                    ? this.isVideo()
                      ? "Cannot copy video"
                      : "Copy image"
                    : "<b>Download</b> first to copy",
                )}
                sensitive={currentlyDownloaded((d) => d && !this.isVideo())}
                onClicked={() => this.copyToClipboard()}
                hexpand
              />
              <button
                label=""
                tooltipMarkup={currentlyDownloaded((downloaded) =>
                  downloaded
                    ? this.isVideo()
                      ? "Cannot Waifu video (for now)"
                      : "Set as current waifu"
                    : "<b>Download</b> first to set",
                )}
                sensitive={currentlyDownloaded((d) => d && !this.isVideo())}
                onClicked={() => this.setAsCurrentWaifu()}
                hexpand
              />
              <button
                label=""
                tooltipMarkup={currentlyDownloaded((downloaded) =>
                  downloaded
                    ? "Open in viewer"
                    : "<b>Download</b> first to open",
                )}
                sensitive={currentlyDownloaded}
                onClicked={() => this.openInViewer(this.isVideo())}
                hexpand
              />
              <togglebutton
                label={currentlyPinned((pinned) => (pinned ? "󰐃" : ""))}
                tooltipMarkup={currentlyPinned((pinned) =>
                  this.isVideo()
                    ? "Cannot pin videos"
                    : currentlyDownloaded.peek()
                      ? pinned
                        ? "Unpin from terminal"
                        : "Pin to terminal"
                      : "<b>Download</b> first to pin",
                )}
                sensitive={currentlyDownloaded((d) => d && !this.isVideo())}
                active={currentlyPinned}
                onClicked={() =>
                  this.pinToTerminal()
                    .then(() => setCurrentlyPinned(this.isPinnedToTerminal()))
                    .catch(() => {})
                }
                hexpand
              />
              <button
                label="󰸉"
                tooltipMarkup={currentlyDownloaded((downloaded) =>
                  downloaded
                    ? "Add to wallpapers"
                    : "<b>Download</b> first to add",
                )}
                sensitive={currentlyDownloaded}
                onClicked={() => this.addToWallpapers()}
                hexpand
              />
            </box>
          </box>
        );

        // For video: Tags and action buttons are always visible (not just on hover).
        // Tags sit above the video, and all controls/buttons stack naturally below.
        // No overlay layer covers the video, so clicks reach the video widget.
        if (this.isVideo()) {
          return (
            <box
              orientation={Gtk.Orientation.VERTICAL}
              class="booru-image"
              widthRequest={displayWidth}
            >
              {/* Tags always visible above the video */}
              {Tags}
              {/* Video frame with no overlay children blocking clicks */}
              <box
                widthRequest={displayWidth}
                heightRequest={displayHeight}
                class="video-frame-container"
              >
                <MediaDisplay />
              </box>
              {/* Action buttons below the video */}
              {Actions}
            </box>
          ) as Gtk.Widget;
        }

        return (
          <overlay
            widthRequest={displayWidth}
            heightRequest={displayHeight}
            class="booru-image"
          >
            <MediaDisplay />
            <box
              $type="overlay"
              orientation={Gtk.Orientation.VERTICAL}
              widthRequest={displayWidth}
              heightRequest={displayHeight}
            >
              {Tags}
              <box vexpand />
              {Actions}
            </box>
          </overlay>
        ) as Gtk.Widget;
      });

      container.append(dialogContent);
      contentCreated = true;

      // Keyboard controls for video — attached to the popover so they fire
      // whenever the popover has focus, regardless of which child is focused.
      // Only installed once (guarded by the contentCreated flag above).
      // videoWidget is a mutable let in the createRoot scope; the closure
      // always reads the current value so it works after the widget realizes.
      if (this.isVideo()) {
        const keyController = new Gtk.EventControllerKey();
        keyController.connect(
          "key-pressed",
          (_ctrl: Gtk.EventControllerKey, keyval: number): boolean => {
            const stream = videoWidget?.get_media_stream();
            if (!stream) return false;

            switch (keyval) {
              // Space / k — play ⁄ pause
              case Gdk.KEY_space:
              case Gdk.KEY_k:
                stream.set_playing(!stream.get_playing());
                return true;

              // ← / j — rewind 5 s
              case Gdk.KEY_Left:
              case Gdk.KEY_j:
                if (stream.is_seekable())
                  stream.seek(Math.max(0, stream.get_timestamp() - 5_000_000));
                return true;

              // → / l — skip 5 s
              case Gdk.KEY_Right:
              case Gdk.KEY_l:
                if (stream.is_seekable())
                  stream.seek(
                    Math.min(
                      stream.get_duration(),
                      stream.get_timestamp() + 5_000_000,
                    ),
                  );
                return true;

              // ↑ — volume +10 %
              case Gdk.KEY_Up:
                stream.set_volume(Math.min(1, stream.get_volume() + 0.1));
                return true;

              // ↓ — volume −10 %
              case Gdk.KEY_Down:
                stream.set_volume(Math.max(0, stream.get_volume() - 0.1));
                return true;

              // m — mute toggle
              case Gdk.KEY_m:
                stream.set_muted(!stream.get_muted());
                return true;

              default:
                return false;
            }
          },
        );
        popover.add_controller(keyController);
      }
    });

    // Stop any playing video when the popover closes, but keep the reactive
    // tree alive. Disposing and re-creating the root on every open/close cycle
    // caused container.append() to add a new child each time (the old child
    // was never removed), resulting in one extra popover per open/close cycle.
    //
    // The reactive tree is built once (contentCreated stays true after the
    // first show) and reused for every subsequent open. The root is only
    // disposed when the button widget itself is destroyed.
    popover.connect("closed", () => {
      // Only pause — do NOT clear() or set_media_stream(null) here.
      // Full teardown on close permanently destroys the media stream, so
      // when the popover reopens the Gtk.Video has no stream and stays blank.
      pauseVideoInWidget(container);
    });

    button.connect("destroy", () => {
      // Full teardown only when the button is permanently removed from the grid.
      teardownVideoInWidget(container);
      disposeRoot?.();
      disposeRoot = null;
    });

    popover.set_child(container);
    button.set_popover(popover);

    // Set up right-click gesture to open in browser
    const gesture = new Gtk.GestureClick();
    gesture.set_button(3);
    gesture.set_propagation_phase(Gtk.PropagationPhase.BUBBLE);
    gesture.connect("released", () => {
      this.openInBrowser();
    });
    button.add_controller(gesture);

    // Connect popover events for window property tracking
    connectPopoverEvents(button);

    return button;
  }

  /**
   * Render as waifu widget (compact display in right panel)
   *
   * Used in: Right panel waifu widget
   * Shows: Large media (image or video), minimal controls
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
    const [currentlyPinned, setCurrentlyPinned] = createState(
      this.isPinnedToTerminal(),
    );
    const [currentlyBookmarked, setCurrentlyBookmarked] = createState(
      this.isBookmarked(),
    );

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
            label={currentlyBookmarked((bookmarked) =>
              bookmarked ? "󰧌" : "",
            )}
            tooltip-text="Bookmark media"
            active={currentlyBookmarked}
            onClicked={(self) => {
              this.toggleBookmark()
                .then((bookmarked) => setCurrentlyBookmarked(bookmarked))
                .catch(() => {});
            }}
            hexpand
          />
          <togglebutton
            label={currentlyPinned((pinned) => (pinned ? "󰐃" : ""))}
            hexpand
            class="pin"
            sensitive={!this.isVideo()}
            active={currentlyPinned}
            tooltip-text={currentlyPinned((pinned) =>
              this.isVideo()
                ? "Cannot pin videos"
                : pinned
                  ? "Unpin media from terminal"
                  : "Pin media to terminal",
            )}
            onClicked={() =>
              this.pinToTerminal()
                .then(() => setCurrentlyPinned(this.isPinnedToTerminal()))
                .catch(() => {})
            }
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
            sensitive={!this.isVideo()}
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

    // Media display component (handles both images and videos)
    const MediaDisplay = () => {
      // Zip/ugoira archives cannot be rendered — show a placeholder.
      if (this.isZip()) {
        return (
          <box
            class="image zip-placeholder"
            widthRequest={opts.width}
            heightRequest={imageHeight}
            orientation={Gtk.Orientation.VERTICAL}
            halign={Gtk.Align.FILL}
            valign={Gtk.Align.FILL}
          >
            <box vexpand />
            <label label="󰗄" class="zip-icon" halign={Gtk.Align.CENTER} />
            <label
              class="zip-label"
              label="This type of video file cannot be played."
              halign={Gtk.Align.CENTER}
              justify={Gtk.Justification.CENTER}
              wrap={true}
            />
            <label
              class="zip-hint"
              label="Open in browser to view media."
              halign={Gtk.Align.CENTER}
              justify={Gtk.Justification.CENTER}
              wrap={true}
            />
            <box vexpand />
          </box>
        );
      }

      if (this.isVideo()) {
        // Probe the preview file, not the image file — the image may not exist
        // yet if the waifu was set before downloading. The preview and the
        // full-size file are always the same content type, so this is stable.
        const previewIsRealVideo = BooruImage.probeFileIsRealVideo(
          this.getPreviewPath(),
        );
        if (!previewIsRealVideo) {
          return (
            <Picture
              class="image"
              height={imageHeight}
              width={opts.width}
              file={this.getImagePath()}
              contentFit={Gtk.ContentFit.COVER}
            />
          );
        }
        return (
          <Video
            class="image"
            width={opts.width}
            height={imageHeight}
            file={this.getImagePath()}
          />
        );
      }

      return (
        <Picture
          class="image"
          height={imageHeight}
          width={opts.width}
          file={this.getImagePath()}
          contentFit={Gtk.ContentFit.COVER}
        />
      );
    };

    // Main widget layout
    return (
      <overlay class="booru-image">
        <MediaDisplay />

        <Actions $type="overlay" />
      </overlay>
    );
  }
}

// Export type alias for backward compatibility
export type Waifu = BooruImage;
