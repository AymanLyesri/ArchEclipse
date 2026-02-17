// =============================================================================
// IMPORTS
// =============================================================================

// GTK and GLib imports for UI components and system operations
import Gtk from "gi://Gtk?version=4.0";
import GLib from "gi://GLib?version=2.0";
import Pango from "gi://Pango?version=1.0";

// AGS framework imports for state management and utilities
import { createState, For, With } from "ags";
import { execAsync } from "ags/process";

// Custom components and utilities
import { Message } from "../../../interfaces/chatbot.interface";
import { notify } from "../../../utils/notification";
import { readJSONFile } from "../../../utils/json";
import { globalSettings, setGlobalSetting } from "../../../variables";
import { chatBotApis } from "../../../constants/api.constants";
import { leftPanelWidgetSelectors } from "../../../constants/widget.constants";
import { Eventbox } from "../../Custom/Eventbox";
import { Progress } from "../../Progress";
import Picture from "../../Picture";

// =============================================================================
// TYPE DEFINITIONS
// =============================================================================

/**
 * Represents a chat session with unique identifier and metadata
 * @property {string} id - Unique identifier for the session (e.g., "default", "session-1234567890")
 * @property {string} name - Display name for the session (e.g., "Session 1")
 * @property {number} createdAt - Unix timestamp of when the session was created
 */
interface Session {
  id: string;
  name: string;
  createdAt: number;
}

// =============================================================================
// CONSTANTS
// =============================================================================

/**
 * Base directory path for storing chatbot data including messages and images
 * All session data is stored under this directory, organized by API model
 */
const MESSAGE_FILE_PATH = `${GLib.get_home_dir()}/.config/ags/cache/chatbot`;

// =============================================================================
// STATE MANAGEMENT
// =============================================================================

/**
 * Array of messages in the current active chat session
 * Each message contains content, role (user/assistant), timestamp, and optional metadata
 */
const [messages, setMessages] = createState<Message[]>([]);

/**
 * Array of all available sessions for the current API model
 * Sessions persist across app restarts and are loaded from the filesystem
 */
const [sessions, setSessions] = createState<Session[]>([]);

/**
 * ID of the currently active session being displayed
 * Defaults to "default" session which is automatically created
 */
const [activeSessionId, setActiveSessionId] = createState<string>("default");

/**
 * Current API model/provider value (e.g., "openrouter/gpt-4")
 * Used to determine which API to call and where to store messages
 */
const [currentApiModel, setCurrentApiModel] = createState<string>("");

/**
 * Status indicator for API requests and operations
 * - "idle": No operation in progress
 * - "loading": Request in progress
 * - "success": Request completed successfully
 * - "error": Request failed
 */
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");

/**
 * Toggle state for image generation feature
 * When enabled, AI responses may include generated images
 * Only available for API models that support image generation
 */
const [chatBotImageGeneration, setChatBotImageGeneration] =
  createState<boolean>(false);

/**
 * Reference to the message input entry widget for programmatic focus control
 * Allows auto-focusing the input field when the chatbot panel is activated
 */
let chatBotEntry: Gtk.Entry | null = null;

// =============================================================================
// UTILITY FUNCTIONS - FILE SYSTEM & PATH MANAGEMENT
// =============================================================================

/**
 * Constructs the file path for storing chat history of a specific session
 * @param {string} apiModel - The API model identifier (e.g., "openrouter/gpt-4")
 * @param {string} sessionId - The unique session identifier
 * @returns {string} Full path to the history.json file for the session
 * @example getMessageFilePath("openrouter/gpt-4", "default")
 *          => "./cache/chatbot/openrouter/gpt-4/sessions/default/history.json"
 */
const getMessageFilePath = (apiModel: string, sessionId: string): string =>
  `${MESSAGE_FILE_PATH}/${apiModel}/sessions/${sessionId}/history.json`;

/**
 * Constructs the directory path where all sessions for an API model are stored
 * @param {string} apiModel - The API model identifier
 * @returns {string} Path to the sessions directory for the specified API model
 * @example getSessionsDir("openrouter/gpt-4")
 *          => "./cache/chatbot/openrouter/gpt-4/sessions"
 */
const getSessionsDir = (apiModel: string): string =>
  `${MESSAGE_FILE_PATH}/${apiModel}/sessions`;

/**
 * Creates a session directory on the filesystem if it doesn't exist
 * Uses recursive directory creation to ensure all parent directories exist
 *
 * @param {string} apiModel - The API model identifier
 * @param {string} sessionId - The unique session identifier
 * @returns {Promise<boolean>} True if directory was created or already exists, false on error
 *
 * Side effects:
 * - Creates directory structure on filesystem
 * - Shows error notification if creation fails
 * - Logs error to console
 */
const ensureSessionDirectory = async (
  apiModel: string,
  sessionId: string,
): Promise<boolean> => {
  const sessionDir = `${MESSAGE_FILE_PATH}/${apiModel}/sessions/${sessionId}`;
  try {
    await execAsync(`mkdir -p "${sessionDir}"`);
    return true;
  } catch (err) {
    const errorMsg = `Error creating session directory: ${err}`;
    print(errorMsg);
    notify({
      summary: "ChatBot Error",
      body: errorMsg,
    });
    return false;
  }
};

/**
 * Loads all available sessions for a given API model from the filesystem
 * Automatically creates a default session if none exist
 *
 * Algorithm:
 * 1. Creates sessions directory if it doesn't exist
 * 2. Scans for existing session subdirectories
 * 3. If no sessions found, creates a default session
 * 4. Sorts sessions with "default" first, then alphabetically
 * 5. Updates the sessions state with loaded data
 *
 * @param {string} apiModel - The API model identifier to load sessions for
 * @returns {Promise<string>} The ID of the first session to be activated
 *
 * Side effects:
 * - Updates sessions state via setSessions()
 * - Creates default session directory if needed
 * - Shows error notification on failure
 * - Logs errors to console
 *
 * Error handling:
 * - Falls back to creating default session on any error
 * - Always returns a valid session ID
 */
const loadSessions = async (apiModel: string): Promise<string> => {
  const sessionsDir = getSessionsDir(apiModel);

  try {
    // Ensure the sessions directory exists
    await execAsync(`mkdir -p "${sessionsDir}"`);

    // Find all session directories using Unix find command
    // -mindepth 1 -maxdepth 1: only direct children
    // -type d: directories only
    // -printf "%f\n": output just the directory name
    const output = await execAsync(
      `find "${sessionsDir}" -mindepth 1 -maxdepth 1 -type d -printf "%f\\n"`,
    );

    // Parse directory names into session IDs
    const sessionIds = output
      .trim()
      .split("\n")
      .filter((id) => id && id.length > 0);

    if (sessionIds.length === 0) {
      // No sessions found - create default session
      const created = await ensureSessionDirectory(apiModel, "default");
      if (created) {
        const defaultSession: Session = {
          id: "default",
          name: "Session 1",
          createdAt: Date.now(),
        };
        setSessions([defaultSession]);
        return "default";
      } else {
        throw new Error("Failed to create default session");
      }
    } else {
      // Load existing sessions and sort them
      // Sorting: "default" always first, then chronologically by ID
      const loadedSessions: Session[] = sessionIds
        .sort((a, b) => {
          if (a === "default") return -1;
          if (b === "default") return 1;
          return a.localeCompare(b);
        })
        .map((id, index) => ({
          id,
          name: `Session ${index + 1}`,
          createdAt: Date.now(), // NOTE: Could be improved by reading actual creation time from filesystem
        }));

      setSessions(loadedSessions);
      return loadedSessions[0].id;
    }
  } catch (err) {
    const errorMsg = `Error loading sessions: ${err}`;
    print(errorMsg);
    notify({
      summary: "ChatBot Error",
      body: errorMsg,
    });

    // Fallback to default session on any error
    const defaultSession: Session = {
      id: "default",
      name: "Session 1",
      createdAt: Date.now(),
    };
    setSessions([defaultSession]);
    return "default";
  }
};

/**
 * Loads chat messages from the filesystem for a specific API model and session
 *
 * @param {string} apiModel - The API model identifier
 * @param {string} sessionId - The unique session identifier
 *
 * Side effects:
 * - Updates messages state via setMessages()
 * - Clears messages if file doesn't exist or is invalid
 *
 * Data validation:
 * - Ensures the loaded data is an array
 * - Falls back to empty array if validation fails
 */
const fetchMessages = (apiModel: string, sessionId: string): void => {
  const filePath = getMessageFilePath(apiModel, sessionId);
  const fetchedMessages = readJSONFile(filePath);

  // Validate that we got an array of messages
  if (!Array.isArray(fetchedMessages)) {
    setMessages([]);
    return;
  }

  setMessages(fetchedMessages);
};

/**
 * Reloads messages for the currently active API model and session
 * Useful for refreshing the UI after external changes to message files
 *
 * Uses peek() to get current state values without creating subscriptions
 *
 * Side effects:
 * - Triggers fetchMessages() which updates messages state
 */
const reloadCurrentMessages = (): void => {
  const apiModel = currentApiModel.peek();
  const sessionId = activeSessionId.peek();
  fetchMessages(apiModel, sessionId);
};

// =============================================================================
// UTILITY FUNCTIONS - TEXT FORMATTING & MARKDOWN
// =============================================================================

/**
 * Formats text content with markdown and code block support
 * Converts markdown syntax to GTK markup for proper rendering in the UI
 *
 * Supported markdown features:
 * - Code blocks with syntax highlighting (```code```)
 * - Inline code (`code`)
 * - Bold text (**bold** or __bold__)
 * - Italic text (*italic* or _italic_)
 * - Links ([text](url))
 * - Headers (# to ######)
 * - Unordered lists (- item or * item)
 * - Ordered lists (1. item)
 * - Blockquotes (> quote)
 *
 * @param {string} text - The raw text content to format
 * @returns {JSX.Element} A GTK box containing formatted label elements
 *
 * Architecture:
 * 1. Splits text by code blocks (```...```)
 * 2. Processes code blocks separately with copy-on-click functionality
 * 3. Processes regular text line-by-line for markdown formatting
 * 4. Converts markdown syntax to GTK Pango markup
 *
 * Implementation notes:
 * - Code blocks are clickable to copy content to clipboard
 * - Uses Pango markup for text styling
 * - Handles nested markdown (e.g., bold within lists)
 *
 * Performance consideration:
 * - Large texts are processed synchronously
 * - Could be optimized with memoization for repeated messages
 */
const formatText = (text: string): JSX.Element => {
  // Split text into code blocks and regular text
  // Regex explanation:
  // ```(\w*)? - Opening code fence with optional language identifier
  // \n? - Optional newline after fence
  // ([\s\S]*?) - Code content (non-greedy, matches everything including newlines)
  // ``` - Closing code fence
  const parts = text.split(/```(\w*)?\n?([\s\S]*?)```/gs);
  const elements = [];

  /**
   * Applies inline markdown formatting to text
   * Converts common markdown syntax to Pango markup for GTK labels
   *
   * @param {string} text - Text to apply formatting to
   * @returns {string} Text with Pango markup
   *
   * Conversions:
   * - `code` → <tt>code</tt>
   * - **bold** / __bold__ → <b>bold</b>
   * - *italic* / _italic_ → <i>italic</i>
   * - [text](url) → <u>text</u>
   *
   * Note: Uses negative lookahead/lookbehind to avoid conflicts
   * e.g., prevents matching ** in **** as both bold delimiters
   */
  const applyInlineFormatting = (text: string): string => {
    let formatted = text;

    // Inline code: `text` → <tt>text</tt>
    formatted = formatted.replace(/`([^`]+)`/g, "<tt>$1</tt>");

    // Bold: **text** or __text__ → <b>text</b>
    formatted = formatted.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
    formatted = formatted.replace(/__([^_]+)__/g, "<b>$1</b>");

    // Italic: *text* or _text_ → <i>text</i>
    // Negative lookahead/lookbehind to avoid matching ** or __
    formatted = formatted.replace(
      /(?<!\*)\*(?!\*)([^*]+)\*(?!\*)/g,
      "<i>$1</i>",
    );
    formatted = formatted.replace(/(?<!_)_(?!_)([^_]+)_(?!_)/g, "<i>$1</i>");

    // Links: [text](url) → <u>text</u> (underlined text, URL is not shown)
    formatted = formatted.replace(/\[([^\]]+)\]\([^)]+\)/g, "<u>$1</u>");

    return formatted;
  };

  /**
   * Parses a single line of markdown and returns GTK label elements
   * Detects markdown patterns and creates appropriate styled labels
   *
   * @param {string} line - Single line of text to parse
   * @returns {JSX.Element[]} Array of GTK label elements
   *
   * Supported patterns:
   * - Headers: # to ###### (converted to custom CSS classes)
   * - Unordered lists: - or * prefix
   * - Ordered lists: 1. 2. 3. etc.
   * - Blockquotes: > prefix
   * - Plain text with inline formatting
   *
   * Note: Returns empty array for empty lines (preserves whitespace)
   */
  const parseMarkdownLine = (line: string): JSX.Element[] => {
    const lineElements = [];

    // Headers: # text → styled label with header-{level} class
    const headerMatch = line.match(/^(#{1,6})\s+(.+)$/);
    if (headerMatch) {
      const level = headerMatch[1].length;
      const formattedText = applyInlineFormatting(headerMatch[2]);
      lineElements.push(
        <label
          class={`header header-${level}`}
          hexpand
          wrap
          xalign={0}
          useMarkup
          label={formattedText}
        />,
      );
      return lineElements;
    }

    // Unordered lists: - or * followed by text
    const listMatch = line.match(/^(\s*)([-*])\s+(.+)$/);
    if (listMatch) {
      const formattedText = applyInlineFormatting(listMatch[3]);
      lineElements.push(
        <label
          class="list-item"
          hexpand
          wrap
          xalign={0}
          useMarkup
          label={`• ${formattedText}`}
        />,
      );
      return lineElements;
    }

    // Ordered lists: 1. 2. 3. etc.
    const orderedListMatch = line.match(/^(\s*)(\d+\.)\s+(.+)$/);
    if (orderedListMatch) {
      const formattedText = applyInlineFormatting(orderedListMatch[3]);
      lineElements.push(
        <label
          class="list-item-ordered"
          hexpand
          wrap
          xalign={0}
          useMarkup
          label={`${orderedListMatch[2]} ${formattedText}`}
        />,
      );
      return lineElements;
    }

    // Blockquotes: > text
    const quoteMatch = line.match(/^>\s+(.+)$/);
    if (quoteMatch) {
      const formattedText = applyInlineFormatting(quoteMatch[1]);
      lineElements.push(
        <label
          class="blockquote"
          hexpand
          wrap
          xalign={0}
          useMarkup
          label={formattedText}
        />,
      );
      return lineElements;
    }

    // Regular text with inline formatting
    if (line.trim()) {
      const formattedLine = applyInlineFormatting(line);

      lineElements.push(
        <label
          class="text"
          hexpand
          wrap
          xalign={0}
          useMarkup
          label={formattedLine}
        />,
      );
    }

    return lineElements;
  };

  // Process all parts (alternating between regular text and code blocks)
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    if (!part?.trim()) continue;

    // Every third element (index % 3 === 2) is code content
    // This is due to the regex capturing groups in the split
    if (i % 3 === 2) {
      // Code block: Create clickable element that copies code to clipboard
      elements.push(
        <Eventbox
          onClick={() =>
            execAsync(
              `bash -c 'printf "%s" "$0" | wl-copy' ${JSON.stringify(part)}`,
            ).catch(print)
          }
          class="code-block"
        >
          <label
            class="code-block-text"
            hexpand
            wrap
            wrapMode={Pango.WrapMode.WORD_CHAR}
            halign={Gtk.Align.START}
            label={part.trim()}
          />
        </Eventbox>,
      );
    } else if (i % 3 === 0 && part.trim()) {
      // Regular text: Parse markdown line by line
      const lines = part.split("\n");
      for (const line of lines) {
        const parsedElements = parseMarkdownLine(line);
        elements.push(...parsedElements);
      }
    }
  }

  // Return wrapped in a vertical box with spacing
  return (
    <box
      visible={text !== ""}
      class="body"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}
    >
      {elements}
    </box>
  );
};

// =============================================================================
// UTILITY FUNCTIONS - API COMMUNICATION
// =============================================================================

/**
 * Sends a user message to the AI API and processes the response
 * This is the core function that handles all AI communication
 *
 * Process flow:
 * 1. Retrieves current session and API configuration
 * 2. Validates API key
 * 3. Escapes message content for shell execution
 * 4. Calls Python script with appropriate parameters
 * 5. Processes response and creates assistant message
 * 6. Updates message history
 * 7. Handles errors with user-friendly messages
 *
 * @param {Message} message - The user message to send to the AI
 *
 * Side effects:
 * - Updates progressStatus state (loading → success/error)
 * - Adds new assistant message to messages state
 * - Shows notification with response or error
 * - Logs errors to console
 *
 * Error handling:
 * - Validates API key before making request
 * - Provides context-aware error messages for common HTTP errors:
 *   - 401: Invalid API key
 *   - 402: Insufficient credits
 *   - 429: Rate limit exceeded
 *   - Connection/timeout errors
 *
 * Performance:
 * - Tracks response time from request to completion
 * - Async/await for non-blocking execution
 *
 * Security considerations:
 * - Escapes single quotes in message content to prevent shell injection
 * - API key is stripped of whitespace and newlines
 *
 * Integration:
 * - Calls external Python script at hardcoded path
 * - IMPROVEMENT: Could make Python script path configurable
 * - IMPROVEMENT: Could validate script exists before execution
 */
const sendMessage = async (message: Message): Promise<void> => {
  const sessionId = activeSessionId.peek();
  const apiModel = currentApiModel.peek();
  const imagePath = `${GLib.get_home_dir()}/.config/ags/cache/chatbot/${apiModel}/sessions/${sessionId}/images/${message.id}.jpg`;

  // Escape single quotes in message content to prevent shell injection
  // Example: "It's great" → "It'\''s great"
  const escapedContent = message.content.replace(/'/g, "'\\''");

  // Get and sanitize API key
  const apiKey = globalSettings
    .peek()
    .apiKeys.openrouter.key.value.replace(/\n/g, "")
    .trim();

  // Validate API key before making request
  if (!apiKey) {
    notify({
      summary: "ChatBot Error",
      body: "OpenRouter API key is not configured. Please set it in settings.",
    });
    setProgressStatus("error");
    return;
  }

  // Construct Python script command
  // Arguments: API model, message content, API key, session ID
  const prompt =
    `python /home/ayman/.config/ags/scripts/chatbot.py ` +
    `'${apiModel}' ` +
    `'${escapedContent}' ` +
    `'${apiKey}' ` +
    `'${sessionId}'`;

  try {
    setProgressStatus("loading");

    // Track response time for performance metrics
    const beginTime = Date.now();

    // Execute Python script and wait for response
    const response = await execAsync(prompt);

    const endTime = Date.now();

    // Show response notification
    notify({ summary: globalSettings.peek().chatBot.api.name, body: response });

    // Create assistant message object
    const newMessage: Message = {
      id: (messages.peek().length + 1).toString(),
      role: "assistant",
      content: response,
      timestamp: Date.now(),
      responseTime: endTime - beginTime,
      image: chatBotImageGeneration.peek() ? imagePath : undefined,
    };

    // Add to message history
    setMessages([...messages.peek(), newMessage]);
    setProgressStatus("success");
  } catch (error) {
    setProgressStatus("error");

    // Parse and enhance error message for better user experience
    const errorStr = String(error);
    let errorMessage = errorStr;

    // Extract meaningful error from Python stderr
    if (errorStr.includes("ERROR:")) {
      const match = errorStr.match(/ERROR: (.+)/);
      if (match) {
        errorMessage = match[1];
      }
    }

    // Provide context-aware error messages for common HTTP errors
    if (errorStr.includes("HTTP 401")) {
      errorMessage =
        "Invalid API key. Check your OpenRouter API key in settings.";
    } else if (errorStr.includes("HTTP 402")) {
      errorMessage =
        "Insufficient credits. Add credits to your OpenRouter account.";
    } else if (errorStr.includes("HTTP 429")) {
      errorMessage = "Rate limit exceeded. Please wait before trying again.";
    } else if (errorStr.includes("Connection")) {
      errorMessage = "Network error. Check your internet connection.";
    } else if (errorStr.includes("timed out")) {
      errorMessage = "Request timed out. The API took too long to respond.";
    }

    notify({
      summary: "ChatBot Error",
      body: errorMessage,
    });

    // Log full error for debugging purposes
    print(`ChatBot error: ${errorStr}`);
  }
};

// =============================================================================
// UI COMPONENTS - API SELECTION
// =============================================================================

/**
 * Renders the API provider selection buttons
 * Allows switching between different AI models/providers
 *
 * Features:
 * - Toggle buttons for each available API provider
 * - Shows provider icon
 * - Only one can be active at a time (radio button behavior)
 * - Automatically loads sessions and messages when switching providers
 *
 * Side effects when provider is selected:
 * - Updates global chatBot.api setting
 * - Updates currentApiModel state
 * - Loads sessions for new API
 * - Activates first available session
 * - Loads messages for that session
 *
 * @returns {JSX.Element} Horizontal box with provider toggle buttons
 */
const ApiList = (): JSX.Element => (
  <box class="tab-list" spacing={5}>
    {chatBotApis.map((provider) => (
      <togglebutton
        hexpand
        active={globalSettings(
          ({ chatBot }) => chatBot.api.name === provider.name,
        )}
        class="provider"
        onToggled={async ({ active }) => {
          if (active) {
            setGlobalSetting("chatBot.api", provider);

            // Update current API model state
            setCurrentApiModel(provider.value);

            // Load sessions for new API and get first session ID
            const firstSessionId = await loadSessions(provider.value);

            // Set active session and load messages
            setActiveSessionId(firstSessionId);
            fetchMessages(provider.value, firstSessionId);
          }
        }}
      >
        <label label={provider.icon} ellipsize={Pango.EllipsizeMode.END} />
      </togglebutton>
    ))}
  </box>
);

// =============================================================================
// UI COMPONENTS - SESSION MANAGEMENT
// =============================================================================

/**
 * Renders session tabs with create and delete functionality
 * Allows users to manage multiple conversation sessions
 *
 * Features:
 * - Horizontal scrollable list of session tabs
 * - Active session is highlighted
 * - Right-click to delete a session
 * - Button to create new sessions
 * - Prevents deletion of the last remaining session
 *
 * Session management:
 * - New sessions get unique timestamp-based IDs
 * - Session directories are created on filesystem
 * - Deleting a session removes its directory and all data
 * - If active session is deleted, switches to first available session
 *
 * @returns {JSX.Element} Session tabs bar with create button
 */
const SessionTabs = (): JSX.Element => {
  /**
   * Creates a new chat session
   *
   * Process:
   * 1. Generates unique session ID using timestamp
   * 2. Creates session directory on filesystem
   * 3. Creates Session object with metadata
   * 4. Adds to sessions list
   * 5. Activates the new session
   * 6. Clears messages (new session starts empty)
   *
   * Side effects:
   * - Creates directory on filesystem
   * - Updates sessions state
   * - Updates activeSessionId state
   * - Clears messages state
   * - Shows error notification on failure
   */
  const createNewSession = async (): Promise<void> => {
    const newSessionId = `session-${Date.now()}`;
    const apiModel = currentApiModel.peek();

    // Create the session directory on disk
    const created = await ensureSessionDirectory(apiModel, newSessionId);

    if (!created) {
      notify({
        summary: "Error",
        body: "Failed to create session directory",
      });
      return;
    }

    // Create session object
    const newSession: Session = {
      id: newSessionId,
      name: `Session ${sessions.peek().length + 1}`,
      createdAt: Date.now(),
    };

    // Update state
    setSessions([...sessions.peek(), newSession]);
    setActiveSessionId(newSessionId);
    setMessages([]);
  };

  /**
   * Deletes a chat session and all its data
   *
   * Process:
   * 1. Validates that at least one session will remain
   * 2. Removes session directory from filesystem
   * 3. Removes session from sessions list
   * 4. If deleted session was active, switches to first remaining session
   *
   * @param {string} sessionId - The unique ID of the session to delete
   *
   * Safety:
   * - Prevents deletion of last session
   * - Automatically switches to another session if active one is deleted
   * - Shows user-friendly error messages
   *
   * Side effects:
   * - Deletes directory and all files on filesystem
   * - Updates sessions state
   * - May update activeSessionId state
   * - Shows notification on error
   */
  const deleteSession = async (sessionId: string): Promise<void> => {
    const currentSessions = sessions.peek();

    // Prevent deletion of the last session
    if (currentSessions.length <= 1) {
      notify({
        summary: "Cannot Delete",
        body: "You must have at least one session",
      });
      return;
    }

    const apiModel = currentApiModel.peek();

    try {
      // Remove session directory and all its contents
      await execAsync(
        `rm -rf "${MESSAGE_FILE_PATH}/${apiModel}/sessions/${sessionId}"`,
      );

      // Filter out the deleted session
      const updatedSessions = currentSessions.filter((s) => s.id !== sessionId);
      setSessions(updatedSessions);

      // If we deleted the active session, switch to the first remaining one
      if (activeSessionId.peek() === sessionId) {
        setActiveSessionId(updatedSessions[0].id);
      }
    } catch (err) {
      notify({
        summary: "Error",
        body: `Failed to delete session: ${err}`,
      });
    }
  };

  return (
    <box class="tab-list" spacing={5}>
      <scrolledwindow
        hexpand
        vexpand={false}
        vscrollbarPolicy={Gtk.PolicyType.NEVER}
      >
        <box spacing={5}>
          <For each={sessions}>
            {(session) => (
              <togglebutton
                class={`tab`}
                active={activeSessionId((id) => id === session.id)}
                label={session.name}
                tooltipMarkup={"Right-click to delete"}
                vexpand={false}
                onToggled={({ active }) => {
                  if (active) {
                    setActiveSessionId(session.id);
                  }
                }}
                $={(self) => {
                  const gesture = new Gtk.GestureClick({
                    button: 3, // Right click only
                  });

                  gesture.connect("pressed", () => {
                    deleteSession(session.id);
                  });

                  self.add_controller(gesture);
                }}
              />
            )}
          </For>
        </box>
      </scrolledwindow>
      <button
        class="new-session"
        label=""
        tooltipText="Create new session"
        onClicked={createNewSession}
      />
    </box>
  );
};

// =============================================================================
// UI COMPONENTS - INFO & SETUP GUIDE
// =============================================================================

/**
 * Displays chatbot information and setup guide
 * Shows API provider details and helps users configure API keys
 *
 * Features:
 * - Displays current API provider name and description
 * - Shows setup guide when API key is missing
 * - Provides direct links to OpenRouter for signup and key generation
 * - Link to settings page to paste API key
 *
 * Visibility:
 * - Setup guide only appears when OpenRouter API key is empty
 * - Guides user through 3-step setup process
 *
 * @returns {JSX.Element} Info box with provider details and optional setup guide
 */
const Info = (): JSX.Element => (
  <box class="info" orientation={Gtk.Orientation.VERTICAL} spacing={5}>
    <label
      class="name"
      hexpand
      wrap
      label={globalSettings(({ chatBot }) => `[${chatBot.api.name}]`)}
    />
    <label
      class="description"
      hexpand
      wrap
      label={globalSettings(({ chatBot }) => chatBot.api.description || "")}
    />
    <box
      visible={globalSettings(
        ({ apiKeys }) => apiKeys.openrouter.key.value.trim() == "",
      )}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
      class="setup-guide"
    >
      <button
        class={"step"}
        label={"1. Visit openrouter and Sign-up for FREE "}
        onClicked={() =>
          execAsync("xdg-open https://openrouter.ai/").catch(print)
        }
      />
      <button
        class={"step"}
        label={"2. Generate a FREE API key "}
        onClicked={() => {
          execAsync("xdg-open https://openrouter.ai/settings/keys").catch(
            print,
          );
        }}
      />
      <button
        class={"step"}
        label="3. Copy & Paste it in the settings"
        onClicked={() => {
          setGlobalSetting("leftPanel.widget", leftPanelWidgetSelectors[3]);
        }}
      ></button>
    </box>
  </box>
);

// =============================================================================
// UI COMPONENTS - MESSAGE DISPLAY
// =============================================================================

/**
 * Renders a single chat message with formatting and metadata
 * Handles both user and assistant messages with different styling
 *
 * Features:
 * - Renders formatted message content using formatText()
 * - Displays timestamp and response time
 * - Shows attached images if present
 * - Click to copy message content
 * - Code blocks have separate click handlers
 * - Different alignment for user vs assistant messages
 *
 * @param {Message} message - The message object to display
 * @param {boolean} islast - Whether this is the last message (for special styling)
 * @returns {JSX.Element} Styled message box with content and metadata
 *
 * Alignment logic:
 * - User messages: aligned right
 * - Assistant messages: aligned left
 * - Messages with images: no specific alignment (expand to full width)
 */
const MessageItem = ({
  message,
  islast = false,
}: {
  message: Message;
  islast?: boolean;
}): JSX.Element => {
  const info = (
    <box class={"info"} spacing={10}>
      <label
        wrap
        class="time"
        label={new Date(message.timestamp).toLocaleString(undefined, {
          hour: "2-digit",
          minute: "2-digit",
          hour12: false,
        })}
      />
      <label
        wrap
        class="response-time"
        label={
          message.responseTime
            ? `Response Time: ${message.responseTime} ms`
            : ""
        }
      />
    </box>
  );

  const messageContent = (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      tooltipText={"Click to copy"}
    >
      {formatText(message.content)}
      {message.image && (
        <Picture
          contentFit={Gtk.ContentFit.SCALE_DOWN}
          height={globalSettings(({ leftPanel }) => leftPanel.width)}
          file={message.image}
        ></Picture>
      )}
    </box>
  );

  return (
    <box
      class={`message ${message.role} ${islast ? "last" : ""}`}
      orientation={Gtk.Orientation.VERTICAL}
      halign={
        message.image === undefined
          ? message.role === "user"
            ? Gtk.Align.END
            : Gtk.Align.START
          : undefined
      }
    >
      <Eventbox
        class="message-eventbox"
        onClick={(self, n, x, y) => {
          // Check if click is on a code block button
          const pick = self.pick(x, y, Gtk.PickFlags.DEFAULT);
          if (
            (pick && pick.get_css_classes().includes("code-block")) ||
            (pick && pick.get_css_classes().includes("code-block-text"))
          ) {
            return; // Don't copy message content if code block was clicked
          }
          execAsync(
            `bash -c 'printf "%s" "$0" | wl-copy' ${JSON.stringify(message.content)}`,
          ).catch(print);
        }}
      >
        {messageContent}
      </Eventbox>
      {info}
    </box>
  );
};

/**
 * Renders the scrollable messages container
 * Displays all messages in the current session with auto-scroll
 *
 * Features:
 * - Vertically scrollable message list
 * - Auto-scrolls to bottom when new messages arrive
 * - Uses subscription to messages state for reactivity
 * - Adds slight delay for smooth scroll after DOM update
 *
 * Implementation:
 * - Uses GLib timeout to delay scroll (allows DOM to update)
 * - Sets scroll adjustment to maximum value (bottom)
 * - Renders messages using MessageItem component
 * - Marks last message for special styling
 *
 * @returns {JSX.Element} Scrollable window containing all messages
 */
const Messages = (): JSX.Element => {
  return (
    <scrolledwindow
      vexpand
      $={(self) => {
        // Subscribe to messages changes and auto-scroll to bottom
        // Uses timeout to ensure DOM has updated before scrolling
        messages.subscribe(() => {
          GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
            const adj = self.get_vadjustment();
            adj.set_value(adj.get_upper()); // Scroll to bottom
            return false; // Don't repeat timeout
          });
        });
      }}
    >
      {/* Render messages list with reactive state */}
      <With value={messages}>
        {(msgs) => (
          <box
            class="messages"
            orientation={Gtk.Orientation.VERTICAL}
            spacing={10}
          >
            {msgs.map((msg, index) => (
              <MessageItem message={msg} islast={index === msgs.length - 1} />
            ))}
          </box>
        )}
      </With>
    </scrolledwindow>
  );
};

// =============================================================================
// UI COMPONENTS - BOTTOM BAR CONTROLS
// =============================================================================

/**
 * Button to clear all messages in the current session
 * Deletes the session's history.json file from filesystem
 *
 * Features:
 * - Removes all messages from current session
 * - Deletes message history file from disk
 * - Shows error notification on failure
 * - Clears messages state on success
 *
 * Side effects:
 * - Deletes history.json file
 * - Updates messages state to empty array
 * - Shows notification on error
 *
 * @returns {JSX.Element} Clear button with icon
 */
const ClearButton = (): JSX.Element => (
  <button
    halign={Gtk.Align.CENTER}
    valign={Gtk.Align.CENTER}
    label=""
    class="clear"
    tooltipText="Clear current session messages"
    onClicked={() => {
      const apiModel = currentApiModel.peek();
      const sessionId = activeSessionId.peek();
      execAsync(`rm -f "${getMessageFilePath(apiModel, sessionId)}"`)
        .then(() => {
          setMessages([]);
        })
        .catch((err) => notify({ summary: "Error", body: err }));
    }}
  />
);

/**
 * Toggle button for image generation feature
 * Enables/disables AI image generation in responses
 *
 * Features:
 * - Only enabled for APIs that support image generation
 * - Disabled (grayed out) for APIs without image support
 * - Toggles chatBotImageGeneration state
 *
 * When enabled:
 * - AI responses may include generated images
 * - Images are saved in session's images directory
 *
 * @returns {JSX.Element} Toggle button for image generation
 */
const ImageGenerationSwitch = (): JSX.Element => (
  <togglebutton
    sensitive={globalSettings(
      ({ chatBot }) => chatBot.api.imageGenerationSupport ?? false,
    )}
    active={chatBotImageGeneration}
    class="image-generation"
    label=""
    onToggled={({ active }) => setChatBotImageGeneration(active)}
  />
);

/**
 * Text entry field for user to type messages
 * Handles message submission on Enter key press
 *
 * Features:
 * - Single-line text input
 * - Submit on Enter key
 * - Auto-clears after submission
 * - Stores reference for programmatic focus
 * - Validates non-empty input
 *
 * Message submission process:
 * 1. Validates text is not empty
 * 2. Creates user message object with timestamp
 * 3. Adds to messages array
 * 4. Calls sendMessage() to get AI response
 * 5. Clears input field
 *
 * @returns {JSX.Element} Text entry widget
 */
const MessageEntry = (): JSX.Element => {
  /**
   * Handles message submission when user presses Enter
   * @param {Gtk.Entry} self - The entry widget
   */
  const handleSubmit = (self: Gtk.Entry): void => {
    const text = self.get_text();
    if (!text) return;

    const newMessage: Message = {
      id: (messages.get().length + 1).toString(),
      role: "user",
      content: text,
      timestamp: Date.now(),
    };

    setMessages([...messages.get(), newMessage]);
    sendMessage(newMessage);
    self.set_text("");
  };

  return (
    <entry
      hexpand
      placeholderText="Ask anything..."
      onActivate={handleSubmit}
      $={(self) => {
        chatBotEntry = self;
      }}
    />
  );
};

/**
 * Bottom bar containing message input and control buttons
 * Groups message entry, clear button, and image generation toggle
 *
 * Layout: [Message Entry (expand)] [Clear Button] [Image Toggle]
 *
 * @returns {JSX.Element} Horizontal box with input controls
 */
const BottomBar = (): JSX.Element => (
  <box class="bottom-bar" spacing={10}>
    <MessageEntry />
    <ClearButton />
    <ImageGenerationSwitch />
  </box>
);

// =============================================================================
// MAIN COMPONENT - CHATBOT
// =============================================================================

/**
 * Main ChatBot component - default export
 * Assembles all sub-components into a complete chat interface
 *
 * Component hierarchy:
 * - Info: API details and setup guide
 * - Messages: Scrollable message history
 * - Progress: Loading/error/success indicator
 * - BottomBar: Message input and controls
 * - SessionTabs: Session management
 * - ApiList: API provider selection
 *
 * Initialization process:
 * 1. Sets up mouse enter event to auto-focus input field
 * 2. Loads current API model from global settings
 * 3. Loads all available sessions for that API
 * 4. Activates first session and loads its messages
 * 5. Subscribes to session changes to reload messages
 *
 * State subscriptions:
 * - activeSessionId: Reloads messages when session changes
 *
 * Lifecycle:
 * - Initialization runs once on component mount ($ callback)
 * - Auto-focus triggers on mouse enter
 * - Message reloading happens on session switch
 *
 * Layout (vertical):
 * ┌─────────────────────────┐
 * │ Info                    │
 * ├─────────────────────────┤
 * │ Messages (expandable)   │
 * ├─────────────────────────┤
 * │ Progress                │
 * │ BottomBar               │
 * ├─────────────────────────┤
 * │ SessionTabs             │
 * ├─────────────────────────┤
 * │ ApiList                 │
 * └─────────────────────────┘
 *
 * @returns {JSX.Element} Complete chatbot interface
 *
 * OPTIMIZATION NOTE:
 * - Duplicate setCurrentApiModel() call removed (was set twice during init)
 * - Could add memoization for formatText() to improve performance
 * - Consider debouncing auto-scroll for better performance with rapid messages
 */
export default (): JSX.Element => {
  return (
    <box
      class="chat-bot"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      spacing={5}
      $={async (self) => {
        // Setup auto-focus on mouse enter
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          if (chatBotEntry) {
            chatBotEntry.grab_focus();
          }
        });
        self.add_controller(motion);

        // Initialize chatbot state on component mount
        const initialApiModel = globalSettings.peek().chatBot.api.value;
        setCurrentApiModel(initialApiModel);

        // Load sessions and activate the first one
        const initialSessionId = await loadSessions(initialApiModel);
        setActiveSessionId(initialSessionId);

        // Load messages for the initial session
        fetchMessages(initialApiModel, initialSessionId);

        // Subscribe to session changes to automatically reload messages
        activeSessionId.subscribe(() => {
          reloadCurrentMessages();
        });
      }}
    >
      {/* API information and setup guide */}
      <Info />

      {/* Scrollable message history */}
      <Messages />

      {/* Input controls with loading indicator */}
      <box orientation={Gtk.Orientation.VERTICAL}>
        <Progress
          status={progressStatus}
          transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
          custom_class="booru-progress"
        />
        <BottomBar />
      </box>

      {/* Session management tabs */}
      <SessionTabs />

      {/* API provider selection */}
      <ApiList />
    </box>
  );
};
