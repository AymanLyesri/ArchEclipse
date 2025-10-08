import { Gtk } from "astal/gtk3";
import { bind, execAsync, Variable } from "astal";
import { globalTransition } from "../../../variables";
import ToggleButton from "../../toggleButton";
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
const scriptTasks = Variable<ScriptTask[]>([]);
const showAddForm = Variable(false);
const editingTask = Variable<ScriptTask | null>(null);

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
      const updatedTasks = scriptTasks.get().filter((t) => t.id !== task.id);
      scriptTasks.set(updatedTasks);
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
  scriptTasks.set(updatedTasks);
});

// Task form component
const TaskForm = ({
  task,
  isEdit = false,
}: {
  task?: ScriptTask;
  isEdit?: boolean;
}) => {
  const nameEntry = Variable(task?.name || "");
  const timeEntry = Variable(task?.time || "12:00");
  const taskType = Variable<boolean>(task?.type || true);
  const commandEntry = Variable(task?.command || "");
  const showSuggestions = Variable(false);

  const updateSuggestions = (input: string) => {
    const hasMatch = predefinedCommands.some((cmd) =>
      cmd.label.toLowerCase().includes(input.toLowerCase())
    );
    showSuggestions.set(input.trim().length > 0 && hasMatch);
  };

  const selectCommand = (command: string) => {
    commandEntry.set(command);
    showSuggestions.set(false);
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

    scriptTasks.set(updatedTasks);
    saveTasksToFile(updatedTasks);
    showAddForm.set(false);
    editingTask.set(null);
  };

  const cancelForm = () => {
    showAddForm.set(false);
    editingTask.set(null);
  };

  return (
    <box className="form-container" vertical spacing={8}>
      <entry
        text={bind(nameEntry)}
        onChanged={(self) => nameEntry.set(self.text)}
        placeholderText="Enter task name"
      />

      <entry
        text={bind(timeEntry)}
        onChanged={(self) => timeEntry.set(self.text)}
        placeholderText="HH:MM (24-hour format)"
        maxLength={5}
      />

      <box vertical>
        <entry
          text={bind(commandEntry)}
          onChanged={(self) => {
            commandEntry.set(self.text);
            updateSuggestions(self.text);
          }}
          placeholderText="Enter command or select preset"
        />
        <revealer
          revealChild={bind(showSuggestions)}
          transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
          transitionDuration={globalTransition}
          child={
            <box className="suggestions" vertical spacing={2}>
              {predefinedCommands
                .filter((cmd) =>
                  cmd.label
                    .toLowerCase()
                    .includes(commandEntry.get().toLowerCase())
                )
                .map((cmd) => (
                  <button
                    className="suggestion"
                    label={cmd.label}
                    onClicked={() => selectCommand(cmd.command)}
                  />
                ))}
            </box>
          }
        />
      </box>

      <box className="task-type-selector" spacing={8}>
        <ToggleButton
          label="Daily"
          state={bind(taskType).as((type) => type === true)}
          onToggled={() => taskType.set(true)}
        />
        <ToggleButton
          label="One-time"
          state={bind(taskType).as((type) => type === false)}
          onToggled={() => taskType.set(false)}
        />
      </box>

      <box className="form-actions" spacing={8}>
        <button
          className="success"
          label={isEdit ? "✓ Update" : "+ Add Task"}
          onClicked={saveTask}
          hexpand
        />
        <button className="danger" label="✕ Cancel" onClicked={cancelForm} />
      </box>
    </box>
  );
};

// Task item component
const TaskItem = ({ task }: { task: ScriptTask }) => {
  const isHovered = Variable(false);

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
    scriptTasks.set(updatedTasks);
    saveTasksToFile(updatedTasks);
  };

  const toggleTask = () => {
    const updatedTasks = scriptTasks
      .get()
      .map((t) => (t.id === task.id ? { ...t, active: !t.active } : t));
    scriptTasks.set(updatedTasks);
    saveTasksToFile(updatedTasks);
  };

  const editTask = () => {
    editingTask.set(task);
    showAddForm.set(true);
  };

  return (
    <eventbox
      className={"task-eventbox"}
      onHover={() => isHovered.set(true)}
      onHoverLost={() => isHovered.set(false)}
      child={
        <box
          className={`task ${task.active ? "active" : "inactive"}`}
          vertical
          spacing={6}
        >
          <box className="task-header">
            <box className="task-info">
              <label
                className="task-name"
                label={task.name}
                hexpand
                halign={Gtk.Align.START}
              />

              <box spacing={5}>
                <label className="task-schedule" label={formatNextRun()} />
                <label
                  className="task-type icon"
                  label={task.type ? "" : "1"}
                />
              </box>
            </box>

            <revealer
              revealChild={bind(isHovered)}
              transitionType={Gtk.RevealerTransitionType.SLIDE_LEFT}
              transitionDuration={globalTransition}
              child={
                <box className="task-actions">
                  <ToggleButton
                    className={task.active ? "success" : "danger"}
                    state={task.active}
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
            className="task-command"
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
    editingTask.set(null);
    showAddForm.set(!showAddForm.get());
  };

  return (
    <box className="script-timer module" vertical spacing={5}>
      <box className="header">
        <label
          className="title"
          label="Script Timer"
          hexpand
          halign={Gtk.Align.START}
        />
        <button
          className="add-btn"
          label={bind(showAddForm).as((show) => (show ? "✕" : "+"))}
          onClicked={toggleForm}
        />
      </box>

      <revealer
        revealChild={bind(showAddForm)}
        transitionType={Gtk.RevealerTransitionType.SLIDE_DOWN}
        transitionDuration={globalTransition}
        child={bind(editingTask).as((task) =>
          task ? TaskForm({ task, isEdit: true }) : TaskForm({})
        )}
      />

      <scrollable
        className="task-list"
        vexpand
        hscroll={Gtk.PolicyType.NEVER}
        child={
          <box vertical spacing={5}>
            {bind(scriptTasks).as((tasks) =>
              tasks.length === 0
                ? [<label className="empty-state" label="No scheduled tasks" />]
                : tasks.map((task) => TaskItem({ task }))
            )}
          </box>
        }
      />
    </box>
  );
};

export default ScriptTimer;
