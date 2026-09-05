import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.theme
import qs.services
import qs.bar

// Donations widget — full port of Donations.tsx (+ embeds General.tsx via GeneralTab)
// Third-party: open URL in browser (xdg-open)
// Crypto: copy address to clipboard (wl-copy) + show QR code (qrencode)
Item {
    id: root
    property int widgetWidth: parent.width
    property string className: ""

    property var donationOptions: [
        { name: "Ko-fi", icon: "\u{F0C4}", type: "third-party", class: "kofi", url: "https://ko-fi.com/aymanlyesri", color: "#29ABE0" },
        { name: "PayPal", icon: "\u{F1ED}", type: "third-party", class: "paypal", url: "https://paypal.me/LyesriAyman", color: "#00457C" },
        { name: "Bitcoin", icon: "\u{F15A}", type: "crypto", address: "1JisW9xeatCFadtgsenjbpCcFePZGPyXow", color: "#F7931A" },
        { name: "Ethereum", icon: "\u{F27E}", type: "crypto", address: "0x52d06d47bb9dc75eaf027f18cb197d5817989a96", color: "#627EEA" },
        { name: "BSC (BEP20)", icon: "\u{F27E}", type: "crypto", description: "BNB Smart Chain", address: "0x52d06d47bb9dc75eaf027f18cb197d5817989a96", color: "#F3BA2F" }
    ]

    // Scrolled window wrapper (AGS <scrolledwindow hexpand vexpand>)
    ScrollView {
        anchors.fill: parent
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded

        Column {
            width: parent.width
            spacing: 16
            topPadding: 4

            // General info section (avatar, version, links, stars) — AGS embeds General()
            GeneralTab {
                width: parent.width
                widgetWidth: parent.width
            }

            // Separator
            Rectangle { width: parent.width; height: 1; color: Theme.border }

            // Header
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                Label {
                    text: "Support the Project"
                    font.pixelSize: Theme.fontSize + 4
                    font.bold: true
                    color: Theme.fg
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Label {
                    text: "Your donations help keep this project alive"
                    font.pixelSize: Theme.fontSize
                    color: Theme.fgDim
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

        // Donation options - render two-by-two like AGS
        Column {
            spacing: 12
            width: parent.width

            // pairs computed as a proper binding so the Repeater updates
            property var pairs: {
                const arr = root.donationOptions
                const out = []
                for (let i = 0; i < arr.length; i += 2) {
                    out.push(arr.slice(i, i + 2))
                }
                return out
            }

            Repeater {
                model: parent.pairs
                delegate: Row {
                    width: parent.width
                    spacing: 10
                    Row {
                        spacing: 5
                        width: parent.width / 2 - 5
                        Repeater {
                            model: modelData
                            delegate: Column {
                                spacing: 5
                                width: parent.width

                                // Main action button
                                Button {
                                    width: parent.width
                                    property string addr: modelData.address ?? ""
                                    property string url: modelData.url ?? ""
                                    onClicked: {
                                        if (modelData.type === "crypto" && addr) {
                                            copyToClipboard(addr, modelData.name)
                                        } else if (url) {
                                            openUrl(url)
                                        }
                                    }
                                    ToolTip.visible: hovered
                                    ToolTip.text: modelData.type === "crypto" && addr
                                        ? "Copy " + modelData.name + " address\n" + addr
                                        : "Donate via " + modelData.name + "\n" + url
                                    background: Rectangle {
                                        color: modelData.color
                                        radius: 8
                                        border.width: 1
                                        border.color: Theme.border
                                    }
                                    contentItem: Row {
                                        spacing: 8
                                        anchors.centerIn: parent
                                        Label { text: modelData.icon; font.pixelSize: Theme.fontSize + 4; color: "white" }
                                        Label { text: modelData.name; font.pixelSize: Theme.fontSize; font.bold: true; color: "white" }
                                    }
                                }

                                // QR Code button
                                Button {
                                    width: parent.width
                                    property string qrData: modelData.address ?? modelData.url ?? ""
                                    onClicked: {
                                        if (qrData) showQRCode(qrData, modelData.name)
                                    }
                                    ToolTip.visible: hovered
                                    ToolTip.text: "Show QR Code"
                                    background: Rectangle {
                                        color: Theme.moduleBg
                                        radius: 8
                                        border.width: 1
                                        border.color: Theme.border
                                    }
                                    contentItem: Label {
                                        anchors.centerIn: parent
                                        text: "\u{F029}"
                                        font.pixelSize: Theme.fontSize + 2
                                        color: Theme.accent
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Footer
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Label {
                text: "Thank you for your support! \u{1F496}"
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                color: Theme.accent
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // --- Helpers ---
    function copyToClipboard(text, name) {
        const proc = copyProcComp.createObject(root)
        proc.command = ["bash", "-c", "echo -n " + JSON.stringify(text) + " | wl-copy"]
        proc.running = true
    }

    property Component copyProcComp: Component {
        Process {
            onExited: (code) => {
                if (code === 0) {
                    Notifications.notify({ summary: "Copied to Clipboard", body: name + " address copied successfully!" })
                } else {
                    Notifications.notify({ summary: "Error", body: "Failed to copy to clipboard" })
                }
            }
        }
    }

    function openUrl(url) {
        const proc = openProcComp.createObject(root)
        proc.command = ["xdg-open", url]
        proc.name = url.split("/").pop() || "link"
        proc.running = true
    }

    property Component openProcComp: Component {
        Process {
            property string name: ""
            command: ["xdg-open", ""]
            onExited: (code) => {
                if (code === 0) Notifications.notify({ summary: "Opening page", body: "Opening donation page in browser..." })
                else Notifications.notify({ summary: "Error", body: "Failed to open URL" })
            }
        }
    }

    function showQRCode(data, name) {
        const qrPath = "/tmp/donation_qr_" + name.toLowerCase().replace(/\s+/g, "_") + ".png"
        const proc = qrProcComp.createObject(root)
        proc.command = ["qrencode", "-o", qrPath, data]
        proc.running = true
        proc.qrPath = qrPath
        proc.name = name
    }

    property Component qrProcComp: Component {
        Process {
            property string qrPath: ""
            property string name: ""
            onExited: (code) => {
                if (code === 0) {
                    // Open QR image with first available viewer
                    const viewer = Qt.createQmlObject('import Quickshell.Io; Process { command: ["swayimg", qrPath] }', root)
                    viewer.running = true
                    viewer.onExited = (c) => {
                        if (c !== 0) {
                            const v2 = Qt.createQmlObject('import Quickshell.Io; Process { command: ["eog", qrPath] }', root)
                            v2.running = true
                            v2.onExited = (c2) => {
                                if (c2 !== 0) {
                                    // AGS Donations.tsx:113 tries gwenview
                                    // before xdg-open — keep the full chain.
                                    const v25 = Qt.createQmlObject('import Quickshell.Io; Process { command: ["gwenview", qrPath] }', root)
                                    v25.running = true
                                    v25.onExited = (c25) => {
                                        if (c25 !== 0) {
                                            const v3 = Qt.createQmlObject('import Quickshell.Io; Process { command: ["xdg-open", qrPath] }', root)
                                            v3.running = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Notifications.notify({ summary: "QR Code Generated", body: "Scan the QR code to get " + name + " address!" })
                } else {
                    Notifications.notify({ summary: "Error", body: "QR code generation failed. Install 'qrencode' package." })
                }
            }
        }
    }
}
}