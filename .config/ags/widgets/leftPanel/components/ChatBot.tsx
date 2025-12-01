import Gtk from "gi://Gtk?version=4.0";
import { Message } from "../../../interfaces/chatbot.interface";
import { createState, createComputed } from "ags";
import { execAsync } from "ags/process";
import { notify } from "../../../utils/notification";
import { readJSONFile, writeJSONFile } from "../../../utils/json";
import {
  chatBotApi,
  setChatBotApi,
  chatBotImageGeneration,
  setChatBotImageGeneration,
  globalTransition,
  leftPanelWidth,
} from "../../../variables";
import { chatBotApis } from "../../../constants/api.constants";

// Constants
const MESSAGE_FILE_PATH = "./assets/chatbot";

// State
const [messages, setMessages] = createState<Message[]>([]);
const [chatHistory, setChatHistory] = createState<Message[]>([]);

// Utils
const getMessageFilePath = () =>
  `${MESSAGE_FILE_PATH}/${chatBotApi().value}/history.json`;

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
            label=""
            onClick={() => execAsync(`wl-copy "${part}"`).catch(print)}
          />
        </box>
      );
    } else if (i % 3 === 0 && part) {
      // Regular text
      elements.push(<label hexpand wrap xalign={0} label={part} />);
    }
  }

  return (
    <box visible={text !== ""} class="body" vertical spacing={10}>
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
  writeJSONFile(getMessageFilePath(), messages());
};

const sendMessage = async (message: Message) => {
  try {
    const beginTime = Date.now();

    const imagePath = `./assets/chatbot/${chatBotApi().value}/images/${
      message.id
    }.jpg`;

    // Escape single quotes in message content
    const escapedContent = message.content.replace(/'/g, "'\\''");

    const prompt =
      `tgpt --quiet ` +
      `${chatBotImageGeneration() ? "--img" : ""} ` +
      `${chatBotImageGeneration() ? `--out ${imagePath}` : ""} ` +
      `--provider ${chatBotApi().value} ` +
      `--preprompt 'short and straight forward response, 
        ${JSON.stringify(chatHistory())
          .replace(/'/g, `'"'"'`)
          .replace(/`/g, "\\`")}'` +
      ` '${escapedContent}'`;

    const response = await execAsync(prompt);
    const endTime = Date.now();

    notify({ summary: chatBotApi().name, body: response });

    const newMessage: Message = {
      id: (messages().length + 1).toString(),
      sender: chatBotApi().value,
      receiver: "user",
      content: response,
      timestamp: Date.now(),
      responseTime: endTime - beginTime,
      image: chatBotImageGeneration() ? imagePath : undefined,
    };

    setMessages([...messages(), newMessage]);
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
        active={createComputed(() => chatBotApi().name === provider.name)}
        class="provider"
        label={provider.name}
        onToggled={() => setChatBotApi(provider)}
      />
    ))}
  </box>
);

// Components
const Info = () => (
  <box class="info" vertical spacing={5}>
    {createComputed(() => {
      const { name, description } = chatBotApi();
      return [
        <label class="name" hexpand wrap label={`[${name}]`} />,
        <label class="description" hexpand wrap label={description} />,
      ];
    })}
  </box>
);

const MessageItem = ({ message }: { message: Message }) => {
  const Revealer = () => (
    <revealer
      revealChild={false}
      transitionDuration={globalTransition}
      transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
      child={
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
      }
    />
  );

  const Actions = () => (
    <box
      class="actions"
      spacing={5}
      valign={message.sender === "user" ? Gtk.Align.START : Gtk.Align.END}
      vertical
    >
      {[
        <button
          class="copy"
          label=""
          onClicked={() =>
            execAsync(`wl-copy "${message.content}"`).catch(print)
          }
        />,
      ]}
    </box>
  );

  const messageContent = (
    <box vertical hexpand>
      {formatTextWithCodeBlocks(message.content)}
      <box
        visible={message.image !== undefined}
        class={"image"}
        css={`
          background-image: url("${message.image}");
        `}
        heightRequest={leftPanelWidth()}
        hexpand
      ></box>
    </box>
  );

  const revealerInstance = Revealer();
  return (
    <Eventbox
      class={"message-Eventbox"}
      onHover={() => (revealerInstance.reveal_child = true)}
      onHoverLost={() => (revealerInstance.reveal_child = false)}
      halign={
        message.image === undefined
          ? message.sender === "user"
            ? Gtk.Align.END
            : Gtk.Align.START
          : undefined
      }
      child={
        <box class={`message ${message.sender}`} vertical>
          <box class={"main"}>
            {message.sender !== "user"
              ? [<Actions />, messageContent]
              : [messageContent, <Actions />]}
          </box>
          {revealerInstance}
        </box>
      }
    />
  );
};

const Messages = () => {
  let scrollable: any;

  createComputed(() => {
    // Trigger on messages change
    const msgs = messages();
    if (scrollable) {
      setTimeout(() => {
        scrollable
          .get_vadjustment()
          .set_value(scrollable.get_vadjustment().get_upper());
      }, 100);
    }
  });

  return (
    <scrollable
      vexpand
      $={(self) => {
        scrollable = self;
      }}
      child={
        <box class="messages" vertical spacing={10}>
          {createComputed(() =>
            messages().map((msg) => <MessageItem message={msg} />)
          )}
        </box>
      }
    />
  );
};

const ClearButton = () => (
  <button
    halign={Gtk.Align.CENTER}
    valign={Gtk.Align.CENTER}
    label=""
    class="clear"
    onClicked={() => {
      setMessages([]);
      execAsync(`rm ${MESSAGE_FILE_PATH}/${chatBotApi().value}/images/*`).catch(
        (err) => notify({ summary: "err", body: err })
      );
    }}
  />
);

const ImageGenerationSwitch = () => (
  <togglebutton
    visible={createComputed(() => chatBotApi().imageGenerationSupport)}
    active={chatBotImageGeneration()}
    class="image-generation"
    label={" Image Generation"}
    onToggled={(self, on) => setChatBotImageGeneration(on)}
  />
);

const MessageEntry = () => {
  const handleSubmit = (self: Gtk.Entry) => {
    const text = self.get_text();
    if (!text) return;

    const newMessage: Message = {
      id: (messages().length + 1).toString(),
      sender: "user",
      receiver: chatBotApi().value,
      content: text,
      timestamp: Date.now(),
    };

    setMessages([...messages(), newMessage]);
    sendMessage(newMessage);
    self.set_text("");
  };

  return (
    <entry hexpand placeholderText="Type a message" onActivate={handleSubmit} />
  );
};

const BottomBar = () => (
  <Eventbox
    class={"bottom-Eventbox"}
    child={
      <box class={"bottom-bar"} spacing={10} vertical>
        <box spacing={5}>
          <MessageEntry />
          <ClearButton />
        </box>
        <box child={<ImageGenerationSwitch />}></box>
      </box>
    }
  />
);

const EnsurePaths = async () => {
  const paths = [
    `${MESSAGE_FILE_PATH}`,
    `${MESSAGE_FILE_PATH}/${chatBotApi().value}`,
    `${MESSAGE_FILE_PATH}/${chatBotApi().value}/images`,
  ];

  paths.forEach((path) => {
    execAsync(`mkdir -p ${path}`);
  });
};

export default () => {
  // Subscribe to chatBotApi changes
  createComputed(() => {
    chatBotApi();
    EnsurePaths();
    fetchMessages();
  });

  // Subscribe to messages changes
  createComputed(() => {
    const msgs = messages();
    saveMessages();
    // set the last 50 messages to chat history
    setChatHistory(msgs.slice(-50));
  });

  EnsurePaths();
  fetchMessages();

  return (
    <box class="chat-bot" vertical hexpand spacing={5}>
      <ApiList />
      <Info />
      <Messages />
      <BottomBar />
    </box>
  );
};
