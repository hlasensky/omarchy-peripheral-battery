import QtQuick
import QtQuick.Layouts
import qs.Ui         // OpticalGlyph
import qs.Commons    // Color, Style tokens

// Click-to-open list of all peripherals. Keep it small — popover, not an app.
Item {
    id: panel

    property var devices: []       // bound from Widget: service.devices
    property int lowThreshold: 20  // flows in from the widget so tint matches the bar

    implicitWidth: 320
    implicitHeight: card.implicitHeight

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Style.cornerRadius
        color: Color.popups.background
        border.color: Color.popups.border
        border.width: 1
        implicitHeight: body.implicitHeight + Style.spacing.popupPadding * 2

        Column {
            id: body
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: Style.spacing.popupPadding
            }
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
                    width: body.width
                    height: Style.spacing.popupRowHeight
                    spacing: Style.spacing.sm

                    readonly property bool low: modelData.pct <= panel.lowThreshold
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
}
