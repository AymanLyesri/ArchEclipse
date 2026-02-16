import Gtk from "gi://Gtk?version=4.0";
import GLib from "gi://GLib?version=2.0";
import { Message } from "../../../interfaces/chatbot.interface";
import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import { readJSONFile, writeJSONFile } from "../../../utils/json";
import {
  globalSettings,
  globalTransition,
  setGlobalSetting,
} from "../../../variables";
import { chatBotApis } from "../../../constants/api.constants";
import { createState, With } from "ags";
import { Eventbox } from "../../Custom/Eventbox";
import { Progress } from "../../Progress";
import Picture from "../../Picture";
import Pango from "gi://Pango?version=1.0";
import { leftPanelWidgetSelectors } from "../../../constants/widget.constants";

// Constants
const MESSAGE_FILE_PATH = "./cache/chatbot";

// State
const [messages, setMessages] = createState<Message[]>([]);

// Entry reference for autofocus
let chatBotEntry: Gtk.Entry | null = null;

// Progress State
const [progressStatus, setProgressStatus] = createState<
  "loading" | "error" | "success" | "idle"
>("idle");

// image generation
const [chatBotImageGeneration, setChatBotImageGeneration] =
  createState<boolean>(false);

// Utils
const getMessageFilePath = () =>
  `${MESSAGE_FILE_PATH}/${
    globalSettings.peek().chatBot.api.value
  }/history.json`;

const formatTextWithCodeBlocks = (text: string) => {
  const parts = text.split(/```(\w*)?\n?([\s\S]*?)```/gs);
  const elements = [];

  const parseMarkdownLine = (line: string) => {
    const lineElements = [];

    // Headers (# to ######)
    const headerMatch = line.match(/^(#{1,6})\s+(.+)$/);
    if (headerMatch) {
      const level = headerMatch[1].length;
      lineElements.push(
        <label
          class={`header header-${level}`}
          hexpand
          wrap
          xalign={0}
          label={headerMatch[2]}
        />,
      );
      return lineElements;
    }

    // Unordered lists (- or * bullet points)
    const listMatch = line.match(/^(\s*)([-*])\s+(.+)$/);
    if (listMatch) {
      lineElements.push(
        <label
          class="list-item"
          hexpand
          wrap
          xalign={0}
          label={`• ${listMatch[3]}`}
        />,
      );
      return lineElements;
    }

    // Ordered lists (1. 2. 3. etc.)
    const orderedListMatch = line.match(/^(\s*)(\d+\.)\s+(.+)$/);
    if (orderedListMatch) {
      lineElements.push(
        <label
          class="list-item-ordered"
          hexpand
          wrap
          xalign={0}
          label={`${orderedListMatch[2]} ${orderedListMatch[3]}`}
        />,
      );
      return lineElements;
    }

    // Blockquotes (> text)
    const quoteMatch = line.match(/^>\s+(.+)$/);
    if (quoteMatch) {
      lineElements.push(
        <label
          class="blockquote"
          hexpand
          wrap
          xalign={0}
          label={quoteMatch[1]}
        />,
      );
      return lineElements;
    }

    // // Horizontal rule (---, ***, ___)
    // if (line.match(/^[-*_]{3,}$/)) {
    //   lineElements.push(<separator class="horizontal-rule" />);
    //   return lineElements;
    // }

    // Regular text with inline formatting (bold, italic, inline code)
    if (line.trim()) {
      let formattedLine = line;

      // Inline code (`code`)
      formattedLine = formattedLine.replace(/`([^`]+)`/g, "<tt>$1</tt>");

      // Bold (**text** or __text__)
      formattedLine = formattedLine.replace(/\*\*([^*]+)\*\*/g, "<b>$1</b>");
      formattedLine = formattedLine.replace(/__([^_]+)__/g, "<b>$1</b>");

      // Italic (*text* or _text_) - but not ** or __
      formattedLine = formattedLine.replace(
        /(?<!\*)\*(?!\*)([^*]+)\*(?!\*)/g,
        "<i>$1</i>",
      );
      formattedLine = formattedLine.replace(
        /(?<!_)_(?!_)([^_]+)_(?!_)/g,
        "<i>$1</i>",
      );

      // Links [text](url) - just show the text
      formattedLine = formattedLine.replace(
        /\[([^\]]+)\]\([^)]+\)/g,
        "<u>$1</u>",
      );

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

  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    if (!part?.trim()) continue;

    if (i % 3 === 2) {
      // Code content
      elements.push(
        <Eventbox
          onClick={() => execAsync(`wl-copy "${part}"`).catch(print)}
          class="code-block">
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
      // Regular text - parse markdown line by line
      const lines = part.split("\n");
      for (const line of lines) {
        const parsedElements = parseMarkdownLine(line);
        elements.push(...parsedElements);
      }
    }
  }

  return (
    <box
      visible={text !== ""}
      class="body"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={10}>
      {elements}
    </box>
  );
};

const fetchMessages = () => {
  const fetchedMessages = readJSONFile(getMessageFilePath());

  if (!Array.isArray(fetchedMessages)) {
    setMessages([]);
    return;
  }

  setMessages(fetchedMessages);
};

const sendMessage = async (message: Message) => {
  const imagePath = `./cache/chatbot/${
    globalSettings.peek().chatBot.api.value
  }/images/${message.id}.jpg`;

  // Escape single quotes in message content
  const escapedContent = message.content.replace(/'/g, "'\\''");
  const apiKey = globalSettings
    .peek()
    .apiKeys.openrouter.key.value.replace(/\n/g, "")
    .trim();
  const model = globalSettings.peek().chatBot.api.value;

  // Validate inputs before making the request
  if (!apiKey) {
    notify({
      summary: "ChatBot Error",
      body: "OpenRouter API key is not configured. Please set it in settings.",
    });
    setProgressStatus("error");
    return;
  }

  const prompt =
    `python /home/ayman/.config/ags/scripts/chatbot.py ` +
    `'${model}' ` +
    `'${escapedContent}' ` +
    `'${apiKey}'`;

  try {
    setProgressStatus("loading");

    const beginTime = Date.now();

    const response = await execAsync(prompt);

    const endTime = Date.now();

    notify({ summary: globalSettings.peek().chatBot.api.name, body: response });

    const newMessage: Message = {
      id: (messages.peek().length + 1).toString(),
      role: "assistant",
      content: response,
      timestamp: Date.now(),
      responseTime: endTime - beginTime,
      image: chatBotImageGeneration.peek() ? imagePath : undefined,
    };

    setMessages([...messages.peek(), newMessage]);
    setProgressStatus("success");
  } catch (error) {
    setProgressStatus("error");

    // Parse error message for better display
    const errorStr = String(error);
    let errorMessage = errorStr;

    // Extract meaningful error from Python stderr
    if (errorStr.includes("ERROR:")) {
      const match = errorStr.match(/ERROR: (.+)/);
      if (match) {
        errorMessage = match[1];
      }
    }

    // Add context to common errors
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

    // Log full error for debugging
    print(`ChatBot error: ${errorStr}`);
  }
};

const ApiList = () => (
  <box class="tab-list" spacing={5}>
    {chatBotApis.map((provider) => (
      <togglebutton
        hexpand
        active={globalSettings(
          ({ chatBot }) => chatBot.api.name === provider.name,
        )}
        class="provider"
        onToggled={({ active }) => {
          if (active) {
            setGlobalSetting("chatBot.api", provider);
            fetchMessages();
          }
        }}>
        <label label={provider.icon} ellipsize={Pango.EllipsizeMode.END} />
      </togglebutton>
    ))}
  </box>
);

// Components
const Info = () => (
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
      class="setup-guide">
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
        }}></button>
    </box>
  </box>
);

const MessageItem = ({
  message,
  islast = false,
}: {
  message: Message;
  islast?: boolean;
}) => {
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
      tooltipText={"Click to copy"}>
      {formatTextWithCodeBlocks(message.content)}
      {message.image && (
        <Picture
          contentFit={Gtk.ContentFit.SCALE_DOWN}
          height={globalSettings(({ leftPanel }) => leftPanel.width)}
          file={message.image}></Picture>
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
      }>
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
          execAsync(`wl-copy "${message.content}"`).catch(print);
        }}>
        {messageContent}
      </Eventbox>
      {info}
    </box>
  );
};

const Messages = () => {
  return (
    <scrolledwindow
      vexpand
      $={(self) => {
        messages.subscribe(() => {
          GLib.timeout_add(GLib.PRIORITY_DEFAULT, 100, () => {
            const adj = self.get_vadjustment();
            adj.set_value(adj.get_upper());
            return false;
          });
        });
      }}>
      {/* {messages((msgs) => msgs.map((msg) => <MessageItem message={msg} />))} */}
      <With value={messages}>
        {(msgs) => (
          <box
            class="messages"
            orientation={Gtk.Orientation.VERTICAL}
            spacing={10}>
            {msgs.map((msg, index) => (
              <MessageItem message={msg} islast={index === msgs.length - 1} />
            ))}
          </box>
        )}
      </With>
    </scrolledwindow>
  );
};

const ClearButton = () => (
  <button
    halign={Gtk.Align.CENTER}
    valign={Gtk.Align.CENTER}
    label=""
    class="clear"
    onClicked={() => {
      execAsync(
        `rm -rf ${MESSAGE_FILE_PATH}/${
          globalSettings.peek().chatBot.api.value
        }`,
      )
        .then(() => {
          setMessages([]);
        })
        .catch((err) => notify({ summary: "err", body: err }));
    }}
  />
);

const ImageGenerationSwitch = () => (
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

const MessageEntry = () => {
  const handleSubmit = (self: Gtk.Entry) => {
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

const BottomBar = () => (
  <box class="bottom-bar" spacing={10}>
    <MessageEntry />
    <ClearButton />
    <ImageGenerationSwitch />
  </box>
);

export default () => {
  return (
    <box
      class="chat-bot"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      spacing={5}
      $={(self) => {
        const motion = new Gtk.EventControllerMotion();
        motion.connect("enter", () => {
          if (chatBotEntry) {
            chatBotEntry.grab_focus();
          }
        });
        self.add_controller(motion);

        fetchMessages();
      }}>
      <Info />
      <Messages />
      <box orientation={Gtk.Orientation.VERTICAL}>
        <Progress
          status={progressStatus}
          transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
          custom_class="booru-progress"
        />
        <BottomBar />
      </box>
      <ApiList />
    </box>
  );
};
