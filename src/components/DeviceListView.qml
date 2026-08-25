import QtQuick
import qs.Commons    // Style tokens

// List popup style: one DeviceListRow per device, stacked full-width.
Column {
    id: root

    property var devices: []
    property int lowThreshold: 20
    property int criticalThreshold: 10
    readonly property real rowWidth: 220

    width: rowWidth
    spacing: Style.spacing.lg

    Repeater {
        model: root.devices
        delegate: DeviceListRow {
            width: root.rowWidth
            device: modelData
            lowThreshold: root.lowThreshold
            criticalThreshold: root.criticalThreshold
        }
    }
}
