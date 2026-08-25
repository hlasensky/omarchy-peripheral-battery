import QtQuick
import QtQuick.Layouts
import ".."          // DeviceIcons
import qs.Commons    // Color, Style tokens

// Single device card for the gauge popup style: dot-ring gauge with the
// percentage centered inside, plus a model-name label underneath.
ColumnLayout {
    id: root

    property var device: ({})
    property int lowThreshold: 20
    property int criticalThreshold: 10
    property real cardWidth: 108

    Layout.preferredWidth: cardWidth
    Layout.alignment: Qt.AlignTop
    spacing: Style.spacing.xs

    readonly property int tier: DeviceIcons.tier(root.device.pct, root.device.state,
        root.lowThreshold, root.criticalThreshold)
    readonly property color tint: DeviceIcons.tierColor(tier, Color.popups.text)

    BatteryGauge {
        Layout.alignment: Qt.AlignHCenter
        pct: root.device.pct
        state: root.device.state
        size: 44
        contentColor: root.tint
    }

    Text {
        Layout.preferredWidth: root.cardWidth
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        text: root.device.model || root.device.type
        color: Color.popups.text
        font.pixelSize: Style.font.bodySmall
        font.weight: Font.Light
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
}
