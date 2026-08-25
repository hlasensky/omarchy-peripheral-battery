import QtQuick
import "components"  // DeviceGaugeGrid, DeviceListView
import qs.Ui         // OpticalGlyph
import qs.Commons    // Color, Style tokens

// Content of the peripheral popup — one row per device. Card chrome
// (background, border, padding, outside-click dismiss) is provided by the
// PopupCard host in Widget.qml, so this is content-only.
//
// The actual per-device layout is delegated to DeviceGaugeGrid / DeviceListView
// so each popup style is self-contained in its own file and swappable via
// `displayStyle` without touching this orchestrator.
Item {
    id: panel

    property var devices: []
    property int lowThreshold: 20
    property int criticalThreshold: 10
    // "Gauge" — dot-ring cards in a grid (default). "List" — one row per
    // device with a thin linear bar, closer to a plain settings-panel list.
    property string displayStyle: "Gauge"

    readonly property bool isList: displayStyle.toLowerCase() === "list"
    readonly property bool hasDevices: devices.length > 0

    readonly property int vpad: Style.spacing.sm
    readonly property int hpad: Style.spacing.md

    // Style switch stays tucked behind the gear until clicked, then closes
    // itself once a choice is made — it's a rare settings action, not
    // something that should compete with the device list for space.
    property bool settingsOpen: false

    // Emitted when the user picks a style from the in-card switch below.
    // No settings UI ships in Omarchy yet to reach `displayStyle` any other
    // way, and hand-editing shell.json doesn't survive the shell's own
    // config writeback — so the switch has to live here and persist itself
    // through the same updateEntryInline() path first-party panels use.
    signal styleSelected(string style)

    implicitWidth: hasDevices
        ? (isList ? deviceList.implicitWidth : deviceGrid.implicitWidth) + hpad * 2
        : 220
    implicitHeight: col.implicitHeight + vpad * 2

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: panel.hpad
        anchors.rightMargin: panel.hpad
        y: panel.vpad
        spacing: Style.spacing.rowGap

        // settings row — gear toggles the style switch below; picking a
        // style closes it again
        Row {
            anchors.right: parent.right
            spacing: Style.spacing.xxs

            Row {
                visible: panel.settingsOpen
                spacing: Style.spacing.xxs
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: ["Gauge", "List"]

                    delegate: Rectangle {
                        readonly property bool active: modelData.toLowerCase() === panel.displayStyle.toLowerCase()

                        width: label.implicitWidth + Style.spacing.sm * 2
                        height: label.implicitHeight + Style.spacing.xs * 2
                        radius: Style.cornerRadius
                        color: active ? Color.accent : "transparent"
                        border.width: active ? 0 : 1
                        border.color: Color.muted

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: Style.font.caption
                            color: parent.active ? Color.background : Color.muted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                panel.styleSelected(modelData);
                                panel.settingsOpen = false;
                            }
                        }
                    }
                }
            }

            OpticalGlyph {
                anchors.verticalCenter: parent.verticalCenter
                width: fontSize
                height: fontSize
                text: DeviceIcons.gear
                fontSize: Style.font.iconSmall
                color: panel.settingsOpen ? Color.accent : Color.muted

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: panel.settingsOpen = !panel.settingsOpen
                }
            }
        }

        Text {
            visible: !panel.hasDevices
            width: parent.width
            text: "No peripherals reporting battery"
            color: Color.muted
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
        }

        DeviceListView {
            id: deviceList
            anchors.horizontalCenter: col.horizontalCenter
            visible: panel.hasDevices && panel.isList
            devices: panel.isList ? panel.devices : []
            lowThreshold: panel.lowThreshold
            criticalThreshold: panel.criticalThreshold
        }

        DeviceGaugeGrid {
            id: deviceGrid
            anchors.horizontalCenter: col.horizontalCenter
            visible: panel.hasDevices && !panel.isList
            devices: panel.isList ? [] : panel.devices
            lowThreshold: panel.lowThreshold
            criticalThreshold: panel.criticalThreshold
        }
    }
}
