import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.theme
import qs.widgets.shared

// Script Timer widget ported from widgets/rightPanel/components/ScriptTimer.tsx
Item {
    id: root

    property var scriptTasks: []
    property bool showAddForm: false
    property var editingTask: null
    property var predefinedCommands: [
        {
            label: "🔔 Notification",
            command: "notify-send 'Timer Alert' 'Scheduled task executed'"
        },
        {
            label: "🔒 Lock Screen",
            command: "qs -p $HOME/.config/quickshell/archeclipse ipc call lock activate"
        },
        {
            label: "💤 Suspend",
            command: "systemctl suspend"
        },
        {
            label: "🔄 Reboot",
            command: "reboot"
        },
        {
            label: "⚡ Shutdown",
            command: "shutdown -h now"
        }
    ]

    Component.onCompleted: {
        loadTasks();
        timer.start();
    }

    Timer {
        id: timer
        interval: 10000
        running: true
        repeat: true
        onTriggered: checkTasks()
    }

    JsonListStore {
        id: taskStore
        filePath: Quickshell.env("HOME") + "/.cache/quickshell/script-timer/tasks.json"
    }

    function loadTasks() {
        const v = taskStore.load();
        scriptTasks = v !== null ? v.map(updateNextRun) : [];
    }

    function saveTasks() {
        taskStore.save(scriptTasks);
    }

    function updateNextRun(task) {
        const [hours, minutes] = task.time.split(":").map(Number);
        const now = new Date();
        const nextRun = new Date();
        nextRun.setHours(hours, minutes, 0, 0);

        if (nextRun <= now) {
            nextRun.setDate(nextRun.getDate() + 1);
        }
        return Object.assign({}, task, {
            nextRun: nextRun.getTime()
        });
    }

    function checkTasks() {
        const now = Date.now();
        scriptTasks.forEach(task => {
            if (task.active && task.nextRun && task.nextRun <= now) {
                executeTask(task);
            }
        });
    }

    function executeTask(task) {
        // Execute the command; on failure notify ("Script Timer Error"):
        // only remove/reschedule a task after the command actually succeeded.
        const process = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
        process.command = ["bash", "-c", task.command];
        const success = exitCode => {
            if (exitCode !== 0) {
                console.error("[ScriptTimer] Task failed:", task.name, "exit", exitCode);
                Quickshell.execDetached(["notify-send", "Script Timer Error", `Failed to execute "${task.name}"`]);
                return;
            }
            Quickshell.execDetached(["notify-send", "Script Timer", `Task "${task.name}" executed`]);

            if (task.type === false) {
                // One-time task - remove after execution
                scriptTasks = scriptTasks.filter(t => t.id !== task.id);
            } else {
                // Daily task - update next run
                const updatedTask = updateNextRun(task);
                scriptTasks = scriptTasks.map(t => t.id === task.id ? updatedTask : t);
            }
            saveTasks();
        };
        process.finished.connect(success);
        process.start();
    }

    function addTask(task) {
        const newTask = Object.assign({}, task, {
            id: task.id || Date.now().toString(),
            active: true
        });
        updateNextRun(newTask);
        scriptTasks = [...scriptTasks, newTask];
        saveTasks();
    }

    function updateTask(task) {
        updateNextRun(task);
        scriptTasks = scriptTasks.map(t => t.id === task.id ? task : t);
        saveTasks();
    }

    function deleteTask(id) {
        scriptTasks = scriptTasks.filter(t => t.id !== id);
        saveTasks();
    }

    function toggleTask(id) {
        scriptTasks = scriptTasks.map(t => t.id === id ? Object.assign({}, t, {
                active: !t.active
            }) : t);
        saveTasks();
    }

    function toggleForm(editTask = null) {
        editingTask = editTask;
        showAddForm = !showAddForm;
        if (!showAddForm) {
            editingTask = null;
        }
    }

    RightPanelCard {
        anchors.fill: parent
        anchors.margins: 8
        title: "Script Timer"
        showAddForm: root.showAddForm
        formComponent: scriptForm
        listSpacing: 5
        onAddClicked: root.toggleForm()
        onCloseClicked: {
            if (root.showAddForm)
                root.toggleForm();
        }

        // Task List
        Repeater {
            model: scriptTasks
            delegate: TaskItem {
                width: parent.width
                task: modelData
                onDeleteClicked: deleteTask(modelData.id)
                onEditClicked: toggleForm(modelData)
                onToggleClicked: toggleTask(modelData.id)
            }
        }
    }

    // Form Component
    Component {
        id: scriptForm
        FormShell {
            clip: true

            // Name
            Column {
                spacing: 4
                width: parent.width
                Label {
                    text: "Task Name"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                AppTextField {
                    id: nameField
                    placeholderText: "Enter task name"
                    text: editingTask ? editingTask.name : ""
                    width: parent.width
                }
            }

            // Time
            Column {
                spacing: 4
                width: parent.width
                Label {
                    text: "Time (HH:MM 24-hour)"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                AppTextField {
                    id: timeField
                    placeholderText: "12:00"
                    text: editingTask ? editingTask.time : "12:00"
                    inputMask: "99:99"
                    width: parent.width
                }
            }

            // Command
            Column {
                spacing: 4
                width: parent.width
                Label {
                    text: "Command"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                AppTextField {
                    id: commandField
                    placeholderText: "Enter command or select preset"
                    text: editingTask ? editingTask.command : ""
                    Layout.fillWidth: true
                    width: parent.width
                }
                // Suggestions
                Column {
                    id: suggestions
                    visible: commandField.text.length > 0
                    spacing: 2
                    width: parent.width
                    Repeater {
                        model: root.predefinedCommands.filter(cmd => cmd.label.toLowerCase().includes(commandField.text.toLowerCase()))
                        delegate: AppButton {
                            text: modelData.label
                            width: parent.width
                            pixelSize: Theme.fontSize
                            cornerRadius: 4
                            idleBg: Theme.bg
                            outlined: true
                            Layout.fillWidth: true
                            onClicked: commandField.text = modelData.command
                        }
                    }
                }
            }

            // Task Type
            Column {
                spacing: 8
                width: parent.width
                Label {
                    text: "Task Type"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fg
                }
                RowLayout {
                    width: parent.width
                    spacing: 8
                    AppCheckBox {
                        id: dailyCheck
                        Layout.fillWidth: true
                        text: "Daily"
                        checked: editingTask ? editingTask.type : true
                        onToggled: {
                            if (checked) {
                                weeklyCheck.checked = false;
                            }
                        }
                    }
                    AppCheckBox {
                        id: weeklyCheck
                        Layout.fillWidth: true
                        text: "One-time"
                        checked: editingTask ? !editingTask.type : false
                        onToggled: {
                            if (checked) {
                                dailyCheck.checked = false;
                            }
                        }
                    }
                }
            }

            // Actions
            RowLayout {
                width: parent.width
                spacing: 8
                AppButton {
                    text: editingTask ? "✓ Update" : "+ Add Task"
                    pixelSize: Theme.fontSize
                    cornerRadius: 4
                    idleBg: Theme.surfaceActive
                    idleFg: Theme.accent
                    outlined: true
                    outlineColor: Theme.accent
                    Layout.fillWidth: true
                    onClicked: {
                        const name = nameField.text.trim();
                        const time = timeField.text.trim();
                        const command = commandField.text.trim();
                        const type = dailyCheck.checked;

                        if (!name || !command || !time.match(/^\d{2}:\d{2}$/)) {
                            Quickshell.execDetached(["notify-send", "Script Timer", "Please fill all fields correctly"]);
                            return;
                        }

                        const task = {
                            id: editingTask ? editingTask.id : Date.now().toString(),
                            name: name,
                            command: command,
                            time: time,
                            type: type,
                            active: true
                        };

                        if (editingTask) {
                            updateTask(task);
                        } else {
                            addTask(task);
                        }
                        toggleForm();
                    }
                }
                AppButton {
                    text: "\u{f00d} Cancel"
                    pixelSize: Theme.fontSize
                    cornerRadius: 4
                    idleBg: Theme.dangerBg
                    idleFg: Theme.danger
                    outlined: true
                    outlineColor: Theme.danger
                    onClicked: toggleForm()
                }
            }
        }
    }
}
