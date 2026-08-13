import QtQuick
import QtQuick.Layouts
import qs.Commons    // Color, Style tokens

// Content of the peripheral popup — one row per device. Card chrome
// (background, border, padding, outside-click dismiss) is provided by the
// PopupCard host in Widget.qml, so this is content-only.
Item {
    id: panel

    property var devices: []
    property int lowThreshold: 20

    readonly property int vpad: Style.spacing.xs

    implicitWidth: 320
    implicitHeight: col.implicitHeight + vpad * 2

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        y: panel.vpad
        spacing: Style.spacing.rowGap

        // empty state
        Text {
            visible: panel.devices.length === 0
            width: parent.width
            text: "No peripherals reporting battery"
            color: Color.muted
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
        }

        Repeater {
            model: panel.devices
            delegate: RowLayout {
                width: col.width
                height: Style.spacing.popupRowHeight
                spacing: Style.spacing.sm

                readonly property bool low: modelData.pct <= panel.lowThreshold
                    && modelData.state !== "charging" && modelData.state !== "fully-charged"
                readonly property color tint: low ? Color.urgent : Color.popups.text

                // device icon
                Text {
                    text: DeviceIcons.glyph(modelData.type)
                    color: parent.tint
                    font.pixelSize: Style.font.body
                }

                // model name (takes the slack)
                Text {
                    Layout.fillWidth: true
                    text: modelData.model || modelData.type
                    color: Color.popups.text
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                }

                // charging bolt
                Text {
                    visible: modelData.charging
                    text: DeviceIcons.bolt
                    color: Color.accent
                    font.pixelSize: Style.font.caption
                }

                // percent
                Text {
                    text: modelData.pct + "%"
                    color: parent.tint
                    font.pixelSize: Style.font.body
                }

                // mini progress bar
                Rectangle {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Color.muted

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, modelData.pct / 100))
                        height: parent.height
                        radius: parent.radius
                        color: parent.parent.low ? Color.urgent : Color.accent
                    }
                }
            }
        }
    }
}
