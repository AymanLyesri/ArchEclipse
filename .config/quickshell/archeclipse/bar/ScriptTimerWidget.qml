import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.theme

// Script Timer widget ported from widgets/rightPanel/components/ScriptTimer.tsx
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    property var scriptTasks: []
    property bool showAddForm: false
    property var editingTask: null
    property var predefinedCommands: [
        { label: "🔔 Notification", command: "notify-send 'Timer Alert' 'Scheduled task executed'" },
        { label: "🔒 Lock Screen", command: "hyprlock" },
        { label: "💤 Suspend", command: "systemctl suspend" },
        { label: "🔄 Reboot", command: "reboot" },
        { label: "⚡ Shutdown", command: "shutdown -h now" }
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

    function loadTasks() {
        try {
            const fileView = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + Quickshell.env("HOME") + '/.config/ags/cache/script-timer/tasks.json" }', root);
            const text = fileView.text();
            if (text !== "" && text.trim().startsWith("[")) {
                const tasks = JSON.parse(text);
                scriptTasks = tasks.map(updateNextRun);
            }
            fileView.destroy();
        } catch (e) {
            console.warn("[ScriptTimer] Failed to load tasks:", e);
            scriptTasks = [];
        }
    }

    function saveTasks() {
        try {
            const fileView = Qt.createQmlObject('import Quickshell.Io; FileView { path: "' + Quickshell.env("HOME") + '/.config/ags/cache/script-timer/tasks.json" }', root);
            fileView.setText(JSON.stringify(scriptTasks, null, 2));
            fileView.destroy();
        } catch (e) {
            console.warn("[ScriptTimer] Failed to save tasks:", e);
        }
    }

    function updateNextRun(task) {
        const [hours, minutes] = task.time.split(":").map(Number);
        const now = new Date();
        const nextRun = new Date();
        nextRun.setHours(hours, minutes, 0, 0);

        if (nextRun <= now) {
            nextRun.setDate(nextRun.getDate() + 1);
        }
        return Object.assign({}, task, { nextRun: nextRun.getTime() });
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
        try {
            // Execute the command using Process
            const process = Qt.createQmlObject('import Quickshell.Io; Process { command: ["bash", "-c", "' + task.command.replace(/"/g, '\\"') + '"] }', root);
            process.start();
            console.log("[ScriptTimer] Executed task:", task.name);
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
        } catch (e) {
            console.error("[ScriptTimer] Failed to execute task:", e);
        }
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
        scriptTasks = scriptTasks.map(t => t.id === id ? Object.assign({}, t, { active: !t.active }) : t);
        saveTasks();
    }

    function toggleForm(editTask = null) {
        editingTask = editTask;
        showAddForm = !showAddForm;
        if (!showAddForm) {
            editingTask = null;
        }
    }

    function formatNextRun(nextRun) {
        if (!nextRun) return "Not scheduled";
        const date = new Date(nextRun);
        const now = new Date();
        const isToday = date.toDateString() === now.toDateString();

        if (isToday) {
            return "Today, " + date.toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false });
        }
        return date.toLocaleString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false, month: "short", day: "numeric" });
    }

    Column {
        anchors.fill: parent
        spacing: 8

        // Header
        Row {
            spacing: 8
            Label {
                text: "Script Timer"
                font.pixelSize: Theme.fontSize + 4
                font.bold: true
                color: Theme.fg
                Layout.fillWidth: true
            }
            Button {
                text: showAddForm ? "✕" : "+"
                onClicked: toggleForm()
                Layout.preferredWidth: 40
                background: Rectangle {
                    color: showAddForm ? Theme.dangerBg : Theme.accentBg
                    radius: 4
                    border.width: 1
                    border.color: showAddForm ? Theme.danger : Theme.accent
                }
                contentItem: Text {
                    anchors.centerIn: parent
                    color: showAddForm ? Theme.danger : Theme.accent
                    font.pixelSize: Theme.fontSize
                }
            }
        }

        // Add/Edit Form
        Loader {
            sourceComponent: showAddForm ? formComponent : null
            Layout.fillWidth: true
        }

        // Task List
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Column {
                id: listColumn
                width: parent.width
                spacing: 5

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
        }
    }

    // Form Component
    Component {
        id: formComponent
        Rectangle {
            color: Theme.moduleBg
            radius: Theme.radius
            border.width: 1
            border.color: Theme.border
            Layout.fillWidth: true
            Layout.minimumHeight: 300
            Layout.preferredHeight: 350
            clip: true

            Column {
                anchors.fill: parent
                spacing: 12
                anchors.margins: 16

                // Name
                Column {
                    spacing: 4
                    Label {
                        text: "Task Name"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    TextField {
                        id: nameField
                        placeholderText: "Enter task name"
                        text: editingTask ? editingTask.name : ""
                    }
                }

                // Time
                Column {
                    spacing: 4
                    Label {
                        text: "Time (HH:MM 24-hour)"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    TextField {
                        id: timeField
                        placeholderText: "12:00"
                        text: editingTask ? editingTask.time : "12:00"
                        inputMask: "99:99"
                    }
                }

                // Command
                Column {
                    spacing: 4
                    Label {
                        text: "Command"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    TextField {
                        id: commandField
                        placeholderText: "Enter command or select preset"
                        text: editingTask ? editingTask.command : ""
                        Layout.fillWidth: true
                    }
                    // Suggestions
                    Column {
                        id: suggestions
                        visible: commandField.text.length > 0
                        spacing: 2
                        Repeater {
                            model: root.predefinedCommands.filter(cmd => cmd.label.toLowerCase().includes(commandField.text.toLowerCase()))
                            delegate: Button {
                                text: modelData.label
                                Layout.fillWidth: true
                                onClicked: commandField.text = modelData.command
                                background: Rectangle {
                                    color: Theme.bg
                                    radius: 4
                                    border.width: 1
                                    border.color: Theme.border
                                }
                                contentItem: Text {
                                    anchors.centerIn: parent
                                    color: Theme.fg
                                    font.pixelSize: Theme.fontSize
                                }
                            }
                        }
                    }
                }

                // Task Type
                Column {
                    spacing: 8
                    Label {
                        text: "Task Type"
                        font.pixelSize: Theme.fontSize
                        color: Theme.fg
                    }
                    Row {
                        spacing: 8
                        CheckBox {
                            id: dailyCheck
                            text: "Daily"
                            checked: editingTask ? editingTask.type : true
                            onToggled: { if (checked) { weeklyCheck.checked = false } }
                        }
                        CheckBox {
                            id: weeklyCheck
                            text: "One-time"
                            checked: editingTask ? !editingTask.type : false
                            onToggled: { if (checked) { dailyCheck.checked = false } }
                        }
                    }
                }

                // Actions
                Row {
                    spacing: 8
                    Layout.fillWidth: true
                    Button {
                        text: editingTask ? "✓ Update" : "+ Add Task"
                        Layout.fillWidth: true
                        onClicked: {
                            const name = nameField.text.trim();
                            const time = timeField.text.trim();
                            const command = commandField.text.trim();
                            const type = dailyCheck.checked;

                            if (!name || !command || !time.match(/^\d{2}:\d{2}$/)) return;

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
                        background: Rectangle {
                            color: Theme.accentBg
                            radius: 4
                            border.width: 1
                            border.color: Theme.accent
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: Theme.accent
                            font.pixelSize: Theme.fontSize
                        }
                    }
                    Button {
                        text: "✕ Cancel"
                        onClicked: toggleForm()
                        background: Rectangle {
                            color: Theme.dangerBg
                            radius: 4
                            border.width: 1
                            border.color: Theme.danger
                        }
                        contentItem: Text {
                            anchors.centerIn: parent
                            color: Theme.danger
                            font.pixelSize: Theme.fontSize
                        }
                    }
                }
            }
        }
    }
}