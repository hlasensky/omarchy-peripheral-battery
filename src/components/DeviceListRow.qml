import QtQuick
import ".."          // DeviceIcons
import qs.Ui         // OpticalGlyph
import qs.Commons    // Color, Style tokens

// Single device row for the list popup style: type glyph + model name on
// top, a thin linear progress bar with the percentage alongside underneath.
Column {
    id: root

    property var device: ({})
    property int lowThreshold: 20
    property int criticalThreshold: 10

    spacing: Style.spacing.sm
    readonly property int hPad: Style.spacing.sm

    readonly property int tier: DeviceIcons.tier(root.device.pct, root.device.state,
        root.lowThreshold, root.criticalThreshold)
    readonly property color tint: DeviceIcons.tierColor(tier, Color.popups.text)
    readonly property color levelColor: DeviceIcons.levelColor(root.device.pct)

    property real fraction: root.device.state === "fully-charged"
        ? 1 : Math.max(0, Math.min(1, root.device.pct / 100))
    Behavior on fraction { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    // name row — icon anchored left, name fills the rest and elides instead
    // of guessing the icon's rendered width off its font size. OpticalGlyph
    // is a bare Item with no implicit size of its own, so it's given an
    // explicit width/height here — otherwise anchoring off it (or reading
    // its implicitHeight) silently resolves to 0 and the name row collapses
    // onto the icon.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.hPad
        anchors.rightMargin: root.hPad
        height: typeIcon.height

        OpticalGlyph {
            id: typeIcon
            width: fontSize
            height: fontSize
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: DeviceIcons.glyph(root.device.type)
            fontSize: Style.font.iconLarge
            color: Color.popups.text
        }

        Text {
            id: nameLabel
            anchors.left: typeIcon.right
            anchors.leftMargin: Style.spacing.md
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.device.model || root.device.type
            color: Color.popups.text
            font.pixelSize: Style.font.bodySmall
            font.weight: Font.Light
            elide: Text.ElideRight
        }
    }

    // charge row
    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.hPad
        anchors.rightMargin: root.hPad
        spacing: Style.spacing.sm

        Rectangle {
            id: track
            width: parent.width - pctGroup.width - Style.spacing.sm
            height: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter
            radius: height / 2
            color: Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.3)

            Rectangle {
                width: track.width * root.fraction
                height: parent.height
                radius: parent.radius
                color: root.levelColor
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        Row {
            id: pctGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xxs

            Text {
                id: pctLabel
                anchors.verticalCenter: parent.verticalCenter
                text: root.device.pct + "%"
                color: root.tint
                font.pixelSize: Style.font.bodySmall
                font.weight: Font.Light
            }

            OpticalGlyph {
                id: bolt
                width: fontSize
                height: fontSize
                anchors.verticalCenter: parent.verticalCenter
                visible: root.device.state === "charging"
                text: DeviceIcons.bolt
                fontSize: Style.font.bodySmall
                color: root.tint

                SequentialAnimation on opacity {
                    running: root.device.state === "charging"
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) bolt.opacity = 1.0
                }
            }
        }
    }
}
