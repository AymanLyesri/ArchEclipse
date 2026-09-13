import QtQuick
import QtQuick.Layouts
import qs.theme
import qs.widgets.shared

// CalendarWidget — month grid with live today, selectable date, month/year
// navigation and a Today shortcut. Monday-first week by default (GTK parity).
Item {
    id: root
    property bool weekStartsMonday: true

    // Live "today" (refreshes every 30s so the highlight never goes stale)
    // plus the visible month and the user-selected date.
    property date todayDate: new Date()
    property date viewDate: new Date(todayDate.getFullYear(), todayDate.getMonth(), 1)
    property date selectedDate: new Date(todayDate.getFullYear(), todayDate.getMonth(), todayDate.getDate())
    property var cells: []

    // Dynamic nav button size: scales with widget width, clamped to stay usable.
    readonly property real navButtonSize: Math.max(22, Math.min(34, root.width / 12))

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.todayDate = new Date()
    }

    // Localized 2-letter weekday names in week order.
    readonly property var weekdayNames: {
        root.weekStartsMonday; // reactive dep
        const out = [];
        for (let i = 0; i < 7; i++) {
            let qtDay;
            if (root.weekStartsMonday)
                qtDay = i + 1;          // Mon(1) .. Sun(7)
            else
                qtDay = i === 0 ? 7 : i; // Sun(7), Mon(1) .. Sat(6)
            let s = "";
            try {
                s = Qt.locale().dayName(qtDay, Locale.ShortFormat);
            } catch (e) {}
            out.push((s || "?").slice(0, 2));
        }
        return out;
    }

    readonly property bool showingCurrentMonth: viewDate.getFullYear() === todayDate.getFullYear() && viewDate.getMonth() === todayDate.getMonth()
    readonly property bool selectedIsToday: root.isSameDay(selectedDate, todayDate)
    readonly property string monthTitle: Qt.locale().monthName(viewDate.getMonth(), Locale.LongFormat) + " " + viewDate.getFullYear()
    readonly property string selectedLabel: {
        try {
            return selectedDate.toLocaleDateString(Qt.locale(), "ddd d MMM yyyy");
        } catch (e) {
            return "";
        }
    }

    function isSameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    function isToday(y, m, d) {
        const t = root.todayDate;
        return y === t.getFullYear() && m === t.getMonth() && d === t.getDate();
    }
    function isSelected(y, m, d) {
        const s = root.selectedDate;
        return y === s.getFullYear() && m === s.getMonth() && d === s.getDate();
    }
    function moveMonth(delta) {
        root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + delta, 1);
    }
    function moveYear(delta) {
        root.viewDate = new Date(root.viewDate.getFullYear() + delta, root.viewDate.getMonth(), 1);
    }
    function goToday() {
        const t = new Date();
        root.todayDate = t;
        root.selectedDate = new Date(t.getFullYear(), t.getMonth(), t.getDate());
        root.viewDate = new Date(t.getFullYear(), t.getMonth(), 1);
    }
    function selectCell(cell) {
        root.selectedDate = new Date(cell.y, cell.m, cell.d);
        if (!cell.inMonth)
            root.viewDate = new Date(cell.y, cell.m, 1);
    }

    // Rebuild the 6x7 grid: leading prev-month cells, current month,
    // trailing next-month cells.
    function updateCells() {
        const y = root.viewDate.getFullYear();
        const m = root.viewDate.getMonth();
        const firstDay = new Date(y, m, 1).getDay(); // 0=Sun
        const lead = root.weekStartsMonday ? (firstDay + 6) % 7 : firstDay;
        const daysInMonth = new Date(y, m + 1, 0).getDate();
        const prevDays = new Date(y, m, 0).getDate();
        const out = [];
        for (let i = lead - 1; i >= 0; i--) {
            const pm = m === 0 ? 11 : m - 1;
            const py = m === 0 ? y - 1 : y;
            const d = prevDays - i;
            out.push({ d: d, m: pm, y: py, inMonth: false });
        }
        for (let d = 1; d <= daysInMonth; d++)
            out.push({ d: d, m: m, y: y, inMonth: true });
        const rem = 42 - out.length;
        const nm = m === 11 ? 0 : m + 1;
        const ny = m === 11 ? y + 1 : y;
        for (let d = 1; d <= rem; d++)
            out.push({ d: d, m: nm, y: ny, inMonth: false });
        root.cells = out;
    }

    onViewDateChanged: root.updateCells()
    onWeekStartsMondayChanged: root.updateCells()
    Component.onCompleted: root.updateCells()

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // Header: year step, month step, centered title (click = today),
        // month step, year step.
        RowLayout {
            width: parent.width
            spacing: 4

            AppButton {
                Layout.preferredWidth: root.navButtonSize
                Layout.preferredHeight: root.navButtonSize
                cornerRadius: 6
                idleBg: Theme.surface
                hoverFg: Theme.accent
                text: "«"
                pixelSize: Theme.fontSize
                tooltipText: "Previous year"
                onClicked: root.moveYear(-1)
            }
            AppButton {
                Layout.preferredWidth: root.navButtonSize
                Layout.preferredHeight: root.navButtonSize
                cornerRadius: 6
                idleBg: Theme.surface
                hoverFg: Theme.accent
                icon: ""
                pixelSize: Theme.fontSize
                tooltipText: "Previous month"
                onClicked: root.moveMonth(-1)
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.navButtonSize
                clip: true
                Text {
                    width: parent.width
                    height: parent.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    text: root.monthTitle
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                }
                MouseArea {
                    id: titleMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToday()
                }
                AppTooltip {
                    visible: titleMa.containsMouse
                    text: "Go to today"
                }
            }
            AppButton {
                Layout.preferredWidth: root.navButtonSize
                Layout.preferredHeight: root.navButtonSize
                cornerRadius: 6
                idleBg: Theme.surface
                hoverFg: Theme.accent
                icon: ""
                pixelSize: Theme.fontSize
                tooltipText: "Next month"
                onClicked: root.moveMonth(1)
            }
            AppButton {
                Layout.preferredWidth: root.navButtonSize
                Layout.preferredHeight: root.navButtonSize
                cornerRadius: 6
                idleBg: Theme.surface
                hoverFg: Theme.accent
                text: "»"
                pixelSize: Theme.fontSize
                tooltipText: "Next year"
                onClicked: root.moveYear(1)
            }
        }

        // Sub-header: selected date + Today shortcut.
        RowLayout {
            width: parent.width
            spacing: 8
            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.selectedLabel
                color: Theme.fgDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                elide: Text.ElideRight
            }
            AppButton {
                width: 64
                height: 24
                cornerRadius: 6
                idleBg: Theme.surface
                hoverFg: Theme.accent
                text: "Today"
                pixelSize: Theme.fontSize - 1
                tooltipText: "Jump to today"
                enabled: !root.showingCurrentMonth || !root.selectedIsToday
                onClicked: root.goToday()
            }
        }

        // Weekday header
        Row {
            width: parent.width
            Repeater {
                model: root.weekdayNames
                delegate: Text {
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.fgDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                    font.bold: true
                }
            }
        }

        // Day grid (6 rows x 7)
        Grid {
            id: dayGrid
            columns: 7
            width: parent.width
            columnSpacing: 1
            rowSpacing: 1
            Repeater {
                model: root.cells
                delegate: Rectangle {
                    readonly property bool today: root.isToday(modelData.y, modelData.m, modelData.d)
                    readonly property bool selected: root.isSelected(modelData.y, modelData.m, modelData.d)
                    width: Math.max(0, (dayGrid.width - 6) / 7)
                    height: 30
                    radius: 8
                    color: {
                        if (selected)
                            return Theme.accent;
                        if (cellMa.containsMouse)
                            return Theme.surfaceActive;
                        return modelData.inMonth ? Theme.surface : "transparent";
                    }
                    border.width: (!selected && today) ? 1 : 0
                    border.color: Theme.accent
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: modelData.d
                        color: {
                            if (parent.selected)
                                return "white";
                            if (!modelData.inMonth)
                                return Theme.fgDim;
                            if (parent.today)
                                return Theme.accent;
                            return Theme.fg;
                        }
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        font.bold: parent.today || parent.selected
                    }
                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectCell(modelData)
                    }
                    AppTooltip {
                        visible: cellMa.containsMouse
                        text: {
                            try {
                                return new Date(modelData.y, modelData.m, modelData.d).toLocaleDateString(Qt.locale(), "dddd d MMMM yyyy");
                            } catch (e) {
                                return "";
                            }
                        }
                    }
                }
            }
        }
    }
}
