import Gtk from "gi://Gtk?version=4.0";
import GLib from "gi://GLib?version=2.0";
import { Message } from "../../../interfaces/chatbot.interface";
import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import { readJSONFile, writeJSONFile } from "../../../utils/json";
import {
  chatBotApi,
  chatBotImageGeneration,
  setChatBotApi,
  setChatBotImageGeneration,
  globalTransition,
  leftPanelWidth,
} from "../../../variables";
import { chatBotApis } from "../../../constants/api.constants";
import { Api } from "../../../interfaces/api.interface";
import { createState, With } from "ags";
import { Eventbox } from "../../Custom/Eventbox";
import CustomRevealer from "../../CustomRevealer";

// Constants
const MESSAGE_FILE_PATH = "./assets/chatbot";

// State
const [messages, setMessages] = createState<Message[]>([]);
const [chatHistory, setChatHistory] = createState<Message[]>([]);

// Utils
const getMessageFilePath = () =>
  `${MESSAGE_FILE_PATH}/${chatBotApi.get().value}/history.json`;

const formatTextWithCodeBlocks = (text: string) => {
  const parts = text.split(/```(\w*)?\n?([\s\S]*?)```/gs);
  const elements = [];

  for (let i = 0; i < parts.length; i++) {
    const part = parts[i]?.trim();
    if (!part) continue;

    if (i % 3 === 2) {
      // Code content
      elements.push(
        <box class="code-block" spacing={5}>
          <label
            class="text"
            hexpand
            wrap
            halign={Gtk.Align.START}
            label={part}
          />
          <button
            halign={Gtk.Align.END}
            valign={Gtk.Align.START}
            class="copy"
            label=""
            onClicked={() => execAsync(`wl-copy "${part}"`).catch(print)}
          />
        </box>
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
  try {
    const beginTime = Date.now();

    const imagePath = `./assets/chatbot/${chatBotApi.get().value}/images/${
      message.id
    }.jpg`;

    // Escape single quotes in message content
    const escapedContent = message.content.replace(/'/g, "'\\''");

    const prompt =
      `tgpt --quiet ` +
      `${chatBotImageGeneration.get() ? "--img" : ""} ` +
      `${chatBotImageGeneration.get() ? `--out ${imagePath}` : ""} ` +
      `--provider ${chatBotApi.get().value} ` +
      `--preprompt 'short and straight forward response, 
        ${JSON.stringify(chatHistory.get())
          .replace(/'/g, `'"'"'`)
          .replace(/`/g, "\\`")}'` +
      ` '${escapedContent}'`;

    const response = await execAsync(prompt);
    const endTime = Date.now();

    notify({ summary: chatBotApi.get().name, body: response });

    const newMessage: Message = {
      id: (messages.get().length + 1).toString(),
      sender: chatBotApi.get().value,
      receiver: "user",
      content: response,
      timestamp: Date.now(),
      responseTime: endTime - beginTime,
      image: chatBotImageGeneration.get() ? imagePath : undefined,
    };

    setMessages([...messages.get(), newMessage]);
  } catch (error) {
    notify({
      summary: "Error",
      body: error instanceof Error ? error.message : String(error),
    });
  }
};

const ApiList = () => (
  <box class="api-list" spacing={5}>
    {chatBotApis.map((provider) => (
      <togglebutton
        hexpand
        active={chatBotApi((p) => p.name === provider.name)}
        class="provider"
        label={provider.name}
        onToggled={({ active }) => {
          if (active) setChatBotApi(provider);
        }}
      />
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
      label={chatBotApi((api) => `[${api.name}]`)}
    />
    <label
      class="description"
      hexpand
      wrap
      label={chatBotApi((api) => api.description || "")}
    />
  </box>
);

const MessageItem = ({ message }: { message: Message }) => {
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

  const Actions = () => (
    <box
      class="actions"
      spacing={5}
      valign={message.sender === "user" ? Gtk.Align.START : Gtk.Align.END}
      orientation={Gtk.Orientation.VERTICAL}
    >
      {[
        <button
          class="copy"
          label=""
          onClicked={() =>
            execAsync(`wl-copy "${message.content}"`).catch(print)
          }
        />,
      ]}
    </box>
  );

  const messageContent = (
    <box orientation={Gtk.Orientation.VERTICAL} hexpand>
      {formatTextWithCodeBlocks(message.content)}
      <box
        visible={message.image !== undefined}
        class="image"
        css={`
          background-image: url("${message.image}");
        `}
        heightRequest={leftPanelWidth}
        hexpand
      ></box>
    </box>
  );

  return (
    <Eventbox
      onHover={() => setRevealerVisible(true)}
      onHoverLost={() => setRevealerVisible(false)}
    >
      <box
        class={`message ${message.sender}`}
        orientation={Gtk.Orientation.VERTICAL}
        halign={
          message.image === undefined
            ? message.sender === "user"
              ? Gtk.Align.END
              : Gtk.Align.START
            : undefined
        }
      >
        <box class="main">
          {message.sender !== "user"
            ? [<Actions />, messageContent]
            : [messageContent, <Actions />]}
        </box>
        {Revealer}
      </box>
    </Eventbox>
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
            {msgs.map((msg) => (
              <MessageItem message={msg} />
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
        `rm ${MESSAGE_FILE_PATH}/${chatBotApi.get().value}/images/*`
      ).catch((err) => notify({ summary: "err", body: err }));
    }}
  />
);

const ImageGenerationSwitch = () => (
  <togglebutton
    visible={chatBotApi((api) => api.imageGenerationSupport ?? false)}
    active={chatBotImageGeneration}
    class="image-generation"
    label=" Image Generation"
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
      receiver: chatBotApi.get().value,
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
      placeholderText="Type a message"
      $={(self) => {
        self.connect("activate", () => handleSubmit(self));
      }}
    />
  );
};

const BottomBar = () => (
  <Eventbox>
    <box class="bottom-bar" spacing={10} orientation={Gtk.Orientation.VERTICAL}>
      <box spacing={5}>
        <MessageEntry />
        <ClearButton />
      </box>
      <box>
        <ImageGenerationSwitch />
      </box>
    </box>
  </Eventbox>
);

const EnsurePaths = async () => {
  const paths = [
    `${MESSAGE_FILE_PATH}`,
    `${MESSAGE_FILE_PATH}/${chatBotApi.get().value}`,
    `${MESSAGE_FILE_PATH}/${chatBotApi.get().value}/images`,
  ];

  paths.forEach((path) => {
    execAsync(`mkdir -p ${path}`);
  });
};

export default () => {
  chatBotApi.subscribe(() => {
    EnsurePaths();
    fetchMessages();
  });
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
      <ApiList />
      <Info />
      <Messages />
      <BottomBar />
    </box>
  );
};
