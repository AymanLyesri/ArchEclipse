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
import { Api } from "../../../interfaces/api.interface";
import { createState, With } from "ags";
import { Eventbox } from "../../Custom/Eventbox";
import { Progress } from "../../Progress";
import Picture from "../../Picture";
import Pango from "gi://Pango?version=1.0";

// Constants
const MESSAGE_FILE_PATH = "./assets/chatbot";

// State
const [messages, setMessages] = createState<Message[]>([]);
const [chatHistory, setChatHistory] = createState<Message[]>([]);

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

  for (let i = 0; i < parts.length; i++) {
    const part = parts[i]?.trim();
    if (!part) continue;

    if (i % 3 === 2) {
      // Code content
      elements.push(
        <Eventbox
          onClick={() => execAsync(`wl-copy "${part}"`).catch(print)}
          class="code-block"
        >
          <label
            class="code-block-text"
            hexpand
            wrap
            wrapMode={Pango.WrapMode.WORD_CHAR}
            halign={Gtk.Align.START}
            label={part}
          />
        </Eventbox>
      );
    } else if (i % 3 === 0 && part) {
      // Regular text
      elements.push(<label hexpand wrap xalign={0} label={part} />);
    }
  }

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

const fetchMessages = () => {
  try {
    const fetchedMessages = readJSONFile(getMessageFilePath());
    setMessages(Array.isArray(fetchedMessages) ? fetchedMessages : []);
  } catch {
    return [];
  }
};

const saveMessages = () => {
  writeJSONFile(getMessageFilePath(), messages.get());
};

const sendMessage = async (message: Message) => {
  const imagePath = `./assets/chatbot/${
    globalSettings.peek().chatBot.api.value
  }/images/${message.id}.jpg`;

  // Escape single quotes in message content
  const escapedContent = message.content.replace(/'/g, "'\\''");
  const prompt =
    `tgpt --quiet ` +
    `${chatBotImageGeneration.peek() ? "--img" : ""} ` +
    `${chatBotImageGeneration.peek() ? `--out ${imagePath}` : ""} ` +
    `--provider ${globalSettings.peek().chatBot.api.value} ` +
    `--preprompt 'short and straight forward response, 
        ${JSON.stringify(chatHistory.peek())
          .replace(/'/g, `'"'"'`)
          .replace(/`/g, "\\`")}'` +
    ` '${escapedContent}'`;
  try {
    setProgressStatus("loading");

    const beginTime = Date.now();

    const response = await execAsync(prompt);
    const endTime = Date.now();

    notify({ summary: globalSettings.peek().chatBot.api.name, body: response });

    const newMessage: Message = {
      id: (messages.get().length + 1).toString(),
      sender: globalSettings.peek().chatBot.api.value,
      receiver: "user",
      content: response,
      timestamp: Date.now(),
      responseTime: endTime - beginTime,
      image: chatBotImageGeneration.peek() ? imagePath : undefined,
    };

    setMessages([...messages.get(), newMessage]);
    setProgressStatus("success");
  } catch (error) {
    setProgressStatus("error");
    notify({
      summary: "Error",
      body: (error instanceof Error ? error.message : String(error)) + prompt,
    });
  }
};

const ApiList = () => (
  <box class="tab-list" spacing={5}>
    {chatBotApis.map((provider) => (
      <togglebutton
        hexpand
        active={globalSettings(
          ({ chatBot }) => chatBot.api.name === provider.name
        )}
        class="provider"
        onToggled={({ active }) => {
          if (active) {
            setGlobalSetting("chatBot.api", provider);
            fetchMessages();
          }
        }}
      >
        <label label={provider.name} ellipsize={Pango.EllipsizeMode.END} />
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
  </box>
);

const MessageItem = ({
  message,
  islast = false,
}: {
  message: Message;
  islast?: boolean;
}) => {
  const [revealerVisible, setRevealerVisible] = createState(false);
  const Revealer = (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
    >
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
    </revealer>
  );

  const messageContent = (
    <box
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      tooltipText={"Click to copy"}
    >
      {formatTextWithCodeBlocks(message.content)}
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
      class={`message ${message.sender} ${islast ? "last" : ""}`}
      orientation={Gtk.Orientation.VERTICAL}
      halign={
        message.image === undefined
          ? message.sender === "user"
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
          execAsync(`wl-copy "${message.content}"`).catch(print);
        }}
      >
        {/* <Actions $type="overlay" /> */}
        {messageContent}
      </Eventbox>

      {Revealer}
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
      }}
    >
      {/* {messages((msgs) => msgs.map((msg) => <MessageItem message={msg} />))} */}
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

const ClearButton = () => (
  <button
    halign={Gtk.Align.CENTER}
    valign={Gtk.Align.CENTER}
    label=""
    class="clear"
    onClicked={() => {
      setMessages([]);
      execAsync(
        `rm -rf ${MESSAGE_FILE_PATH}/${
          globalSettings.peek().chatBot.api.value
        }/images`
      ).catch((err) => notify({ summary: "err", body: err }));
    }}
  />
);

const ImageGenerationSwitch = () => (
  <togglebutton
    sensitive={globalSettings(
      ({ chatBot }) => chatBot.api.imageGenerationSupport ?? false
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
      sender: "user",
      receiver: globalSettings.peek().chatBot.api.value,
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
      $={(self) => {
        self.connect("activate", () => handleSubmit(self));
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

const EnsurePaths = async () => {
  const paths = [
    `${MESSAGE_FILE_PATH}`,
    `${MESSAGE_FILE_PATH}/${globalSettings.peek().chatBot.api.value}`,
    `${MESSAGE_FILE_PATH}/${globalSettings.peek().chatBot.api.value}/images`,
  ];

  paths.forEach((path) => {
    execAsync(`mkdir -p ${path}`);
  });
};

export default () => {
  messages.subscribe(() => {
    saveMessages();
    // set the last 50 messages to chat history
    setChatHistory(messages.get().slice(-50));
  });

  EnsurePaths();
  fetchMessages();

  return (
    <box
      class="chat-bot"
      orientation={Gtk.Orientation.VERTICAL}
      hexpand
      spacing={5}
    >
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
