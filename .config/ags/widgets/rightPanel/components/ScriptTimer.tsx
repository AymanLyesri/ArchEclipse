import Gtk from "gi://Gtk?version=4.0";
import { createBinding, createState, createComputed } from "ags";
import { execAsync } from "ags/process";
import { globalTransition } from "../../../variables";
import { notify } from "../../../utils/notification";
import { readJSONFile, writeJSONFile } from "../../../utils/json";

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
    return result;
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
      const updatedTasks = scriptTasks.filter((t) => t.id !== task.id);
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
  const tasks = scriptTasks;

  // tasks.forEach((task) => {
  //   if (task.active && task.nextRun && task.nextRun <= now) {
  //     executeTask(task);
  //   }
  // });
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
    const name = nameEntry.trim();
    const command = commandEntry.trim();
    const time = timeEntry;

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
      type: taskType,
      active: true,
    };

    updateNextRun(newTask);
    const tasks = scriptTasks;
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
    <box class="form-container" vertical spacing={8}>
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

      <box vertical>
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
          transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
          transitionDuration={globalTransition}
          child={
            <box class="suggestions" vertical spacing={2}>
              {predefinedCommands
                .filter((cmd) =>
                  cmd.label.toLowerCase().includes(commandEntry().toLowerCase())
                )
                .map((cmd) => (
                  <button
                    class="suggestion"
                    label={cmd.label}
                    onClicked={() => selectCommand(cmd.command)}
                  />
                ))}
            </box>
          }
        />
      </box>

      <box class="task-type-selector" spacing={8}>
        <togglebutton
          label="Daily"
          active={createComputed(() => taskType() === true)}
          onToggled={() => setTaskType(true)}
        />
        <togglebutton
          label="One-time"
          active={createComputed(() => taskType() === false)}
          onToggled={() => setTaskType(false)}
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
    const updatedTasks = scriptTasks.filter((t) => t.id !== task.id);
    setScriptTasks(updatedTasks);
    saveTasksToFile(updatedTasks);
  };

  const toggleTask = () => {
    const updatedTasks = scriptTasks.map((t) =>
      t.id === task.id ? { ...t, active: !t.active } : t
    );
    setScriptTasks(updatedTasks);
    saveTasksToFile(updatedTasks);
  };

  const editTask = () => {
    setEditingTask(task);
    setShowAddForm(true);
  };

  return (
    <Eventbox
      class={"task-Eventbox"}
      onHover={() => setIsHovered(true)}
      onHoverLost={() => setIsHovered(false)}
      child={
        <box
          class={`task ${task.active ? "active" : "inactive"}`}
          vertical
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
              child={
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
              }
            />
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
      }
    />
  );
};

// Main component
const ScriptTimer = () => {
  const toggleForm = () => {
    setEditingTask(null);
    setShowAddForm(!showAddForm());
  };

  return (
    <box class="script-timer module" vertical spacing={5}>
      <box class="header">
        <label
          class="title"
          label="Script Timer"
          hexpand
          halign={Gtk.Align.START}
        />
        <button
          class="add-btn"
          label={createComputed(() => (showAddForm ? "✕" : "+"))}
          onClicked={toggleForm}
        />
      </box>

      <revealer
        revealChild={showAddForm}
        transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
        transitionDuration={globalTransition}
        child={createComputed(() => {
          const task = editingTask;
          return task ? TaskForm({ task, isEdit: true }) : TaskForm({});
        })}
      />

      <scrollable
        class="task-list"
        vexpand
        hscroll={Gtk.PolicyType.NEVER}
        child={
          <box vertical spacing={5}>
            {createComputed(() => {
              const tasks = scriptTasks;
              return tasks.length === 0
                ? [<label class="empty-state" label="No scheduled tasks" />]
                : tasks.map((task) => TaskItem({ task }));
            })}
          </box>
        }
      />
    </box>
  );
};

export default ScriptTimer;
