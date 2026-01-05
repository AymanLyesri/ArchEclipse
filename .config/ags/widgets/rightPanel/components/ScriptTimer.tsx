import Gtk from "gi://Gtk?version=4.0";
import { Accessor, createState, For, With } from "ags";
import { execAsync } from "ags/process";
import { globalTransition } from "../../../variables";
import { notify } from "../../../utils/notification";
import { readJSONFile, writeJSONFile } from "../../../utils/json";
import { Eventbox } from "../../Custom/Eventbox";

// Interfaces
interface ScriptTask {
  id: string;
  name: string;
  command: string;
  time: string; // HH:MM format
  type: boolean; // true for daily, false for one-time
  active: boolean;
  nextRun?: number; // timestamp
}

// Predefined commands
const predefinedCommands = [
  {
    label: "🔔 Notification",
    command: "notify-send 'Timer Alert' 'Scheduled task executed'",
  },
  { label: "🔒 Lock Screen", command: "hyprlock" },
  { label: "💤 Suspend", command: "systemctl suspend" },
  { label: "🔄 Reboot", command: "reboot" },
  { label: "⚡ Shutdown", command: "shutdown -h now" },
];

// Variables
const [scriptTasks, setScriptTasks] = createState<ScriptTask[]>([]);
const [showAddForm, setShowAddForm] = createState(false);
const [editingTask, setEditingTask] = createState<ScriptTask | null>(null);

// Storage functions
const saveTasksToFile = async (tasks: ScriptTask[]) => {
  try {
    await execAsync(`mkdir -p ./assets/script-timer`);
    writeJSONFile("./assets/script-timer/tasks.json", tasks);
  } catch (error) {
    console.error("Failed to save tasks:", error);
  }
};

const loadTasksFromFile = async (): Promise<ScriptTask[]> => {
  try {
    const result = readJSONFile("./assets/script-timer/tasks.json");
    return Array.isArray(result) ? result : [];
  } catch (error) {
    console.error("Failed to load tasks:", error);
    return [];
  }
};

// Task execution
const executeTask = async (task: ScriptTask) => {
  try {
    await execAsync(`bash -c "${task.command}"`);
    notify({ summary: "Script Timer", body: `Task "${task.name}" executed` });

    if (task.type === false) {
      // Remove one-time tasks after execution
      const updatedTasks = scriptTasks.get().filter((t) => t.id !== task.id);
      setScriptTasks(updatedTasks);
      saveTasksToFile(updatedTasks);
    } else {
      // Schedule next daily execution
      updateNextRun(task);
    }
  } catch (error) {
    notify({
      summary: "Script Timer Error",
      body: `Failed to execute "${task.name}"`,
    });
  }
};

// Calculate next run time
const updateNextRun = (task: ScriptTask) => {
  const [hours, minutes] = task.time.split(":").map(Number);
  const now = new Date();
  const nextRun = new Date();
  nextRun.setHours(hours, minutes, 0, 0);

  // If the scheduled time has already passed today, schedule for tomorrow
  if (nextRun <= now) {
    nextRun.setDate(nextRun.getDate() + 1);
  }

  task.nextRun = nextRun.getTime();
  return task;
};

// Timer check interval
const checkTasks = () => {
  const now = Date.now();
  const tasks = scriptTasks.get();

  tasks.forEach((task) => {
    if (task.active && task.nextRun && task.nextRun <= now) {
      executeTask(task);
    }
  });
};

// Start timer check
setInterval(checkTasks, 10000); // Check every 10 seconds

// Initialize tasks on load
loadTasksFromFile().then((tasks) => {
  const updatedTasks = tasks.map(updateNextRun);
  setScriptTasks(updatedTasks);
});

// Task form component
const TaskForm = ({
  task,
  isEdit = false,
}: {
  task?: ScriptTask;
  isEdit?: boolean;
}) => {
  const [nameEntry, setNameEntry] = createState(task?.name || "");
  const [timeEntry, setTimeEntry] = createState(task?.time || "12:00");
  const [taskType, setTaskType] = createState<boolean>(task?.type || true);
  const [commandEntry, setCommandEntry] = createState(task?.command || "");
  const [showSuggestions, setShowSuggestions] = createState(false);

  const updateSuggestions = (input: string) => {
    const hasMatch = predefinedCommands.some((cmd) =>
      cmd.label.toLowerCase().includes(input.toLowerCase())
    );
    setShowSuggestions(input.trim().length > 0 && hasMatch);
  };

  const selectCommand = (command: string) => {
    setCommandEntry(command);
    setShowSuggestions(false);
  };

  const saveTask = () => {
    const name = nameEntry.get().trim();
    const command = commandEntry.get().trim();
    const time = timeEntry.get();

    if (!name || !command || !time.match(/^\d{2}:\d{2}$/)) {
      notify({
        summary: "Script Timer",
        body: "Please fill all fields correctly",
      });
      return;
    }

    const newTask: ScriptTask = {
      id: task?.id || Date.now().toString(),
      name,
      command,
      time,
      type: taskType.get(),
      active: true,
    };

    updateNextRun(newTask);
    const tasks = scriptTasks.get();
    const updatedTasks = isEdit
      ? tasks.map((t) => (t.id === task!.id ? newTask : t))
      : [...tasks, newTask];

    setScriptTasks(updatedTasks);
    saveTasksToFile(updatedTasks);
    setShowAddForm(false);
    setEditingTask(null);
  };

  const cancelForm = () => {
    setShowAddForm(false);
    setEditingTask(null);
  };

  return (
    <box
      class="form-container"
      orientation={Gtk.Orientation.VERTICAL}
      spacing={8}
    >
      <entry
        text={nameEntry}
        onChanged={(self) => setNameEntry(self.text)}
        placeholderText="Enter task name"
      />

      <entry
        text={timeEntry}
        onChanged={(self) => setTimeEntry(self.text)}
        placeholderText="HH:MM (24-hour format)"
        maxLength={5}
      />

      <box orientation={Gtk.Orientation.VERTICAL}>
        <entry
          text={commandEntry}
          onChanged={(self) => {
            setCommandEntry(self.text);
            updateSuggestions(self.text);
          }}
          placeholderText="Enter command or select preset"
        />
        <revealer
          revealChild={showSuggestions}
          transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
          transitionDuration={globalTransition}
        >
          <box
            class="suggestions"
            orientation={Gtk.Orientation.VERTICAL}
            spacing={2}
          >
            {predefinedCommands
              .filter((cmd) =>
                cmd.label
                  .toLowerCase()
                  .includes(commandEntry.get().toLowerCase())
              )
              .map((cmd) => (
                <button
                  class="suggestion"
                  label={cmd.label}
                  onClicked={() => selectCommand(cmd.command)}
                />
              ))}
          </box>
        </revealer>
      </box>

      <box class="task-type-selector" spacing={8}>
        <togglebutton
          label="Daily"
          active={taskType((type) => type === true)}
          onToggled={(self) => {
            if (self.active) {
              setTaskType(true);
            }
          }}
        />
        <togglebutton
          label="One-time"
          active={taskType((type) => type === false)}
          onToggled={(self) => {
            if (self.active) {
              setTaskType(false);
            }
          }}
        />
      </box>

      <box class="form-actions" spacing={8}>
        <button
          class="success"
          label={isEdit ? "✓ Update" : "+ Add Task"}
          onClicked={saveTask}
          hexpand
        />
        <button class="danger" label="✕ Cancel" onClicked={cancelForm} />
      </box>
    </box>
  );
};

// Task item component
const TaskItem = ({ task }: { task: ScriptTask }) => {
  const [isHovered, setIsHovered] = createState(false);

  const formatNextRun = () => {
    if (!task.nextRun) return "Not scheduled";
    const date = new Date(task.nextRun);
    const now = new Date();
    const isToday = date.toDateString() === now.toDateString();

    if (isToday) {
      return `Today, ${date.toLocaleTimeString("en-US", {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      })}`;
    }

    return date.toLocaleString("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
      month: "short",
      day: "numeric",
    });
  };

  const deleteTask = () => {
    const updatedTasks = scriptTasks.get().filter((t) => t.id !== task.id);
    setScriptTasks(updatedTasks);
    saveTasksToFile(updatedTasks);
  };

  const toggleTask = () => {
    const updatedTasks = scriptTasks
      .get()
      .map((t) => (t.id === task.id ? { ...t, active: !t.active } : t));
    setScriptTasks(updatedTasks);
    saveTasksToFile(updatedTasks);
  };

  const editTask = () => {
    setEditingTask(task);
    setShowAddForm(true);
  };

  return (
    <Eventbox
      class="task-eventbox"
      onHover={() => setIsHovered(true)}
      onHoverLost={() => setIsHovered(false)}
    >
      <box
        class={`task ${task.active ? "active" : "inactive"}`}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={6}
      >
        <box class="task-header">
          <box class="task-info">
            <label
              class="task-name"
              label={task.name}
              hexpand
              halign={Gtk.Align.START}
            />

            <box spacing={5}>
              <label class="task-schedule" label={formatNextRun()} />
              <label class="task-type icon" label={task.type ? "" : "1"} />
            </box>
          </box>

          <revealer
            revealChild={isHovered}
            transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
            transitionDuration={globalTransition}
          >
            <box class="task-actions">
              <togglebutton
                class={task.active ? "success" : "danger"}
                active={task.active}
                label={task.active ? "●" : "○"}
                onToggled={toggleTask}
              />
              <button label="✏" onClicked={editTask} />
              <button label="✕" onClicked={deleteTask} />
            </box>
          </revealer>
        </box>

        <label
          class="task-command"
          label={
            task.command.length > 40
              ? task.command.substring(0, 40) + "..."
              : task.command
          }
        />
      </box>
    </Eventbox>
  );
};

// Main component
const ScriptTimer = ({
  className,
}: {
  className?: string | Accessor<string>;
}) => {
  const toggleForm = () => {
    setEditingTask(null);
    setShowAddForm(!showAddForm.get());
  };

  return (
    <box
      class={`script-timer module ${className ?? ""}`}
      orientation={Gtk.Orientation.VERTICAL}
      spacing={5}
    >
      <box class="header">
        <label
          class="title"
          label="Script Timer"
          hexpand
          halign={Gtk.Align.START}
        />
        <button
          class="add-btn"
          label={showAddForm((show) => (show ? "✕" : "+"))}
          onClicked={toggleForm}
        />
      </box>

      <revealer
        revealChild={showAddForm}
        transitionType={Gtk.RevealerTransitionType.SWING_DOWN}
        transitionDuration={globalTransition}
      >
        <With value={editingTask}>
          {(task) => (task ? TaskForm({ task, isEdit: true }) : TaskForm({}))}
        </With>
      </revealer>

      <scrolledwindow class="task-list" vexpand>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={5}>
          <For each={scriptTasks}>{(task) => TaskItem({ task })}</For>
        </box>
      </scrolledwindow>
    </box>
  );
};

export default ScriptTimer;
