import QtQuick
import QtQuick.Layouts
import qs.Commons    // Style tokens

// Gauge popup style: dot-ring battery cards (GaugeCard) arranged in a grid
// that grows/shrinks with the device count instead of reserving a fixed
// 3-wide slot regardless of how many peripherals are actually present.
// Floored at one column so a single device doesn't collapse to a
// starved-looking box.
GridLayout {
    id: root

    property var devices: []
    property int lowThreshold: 20
    property int criticalThreshold: 10

    readonly property int maxColumns: 3
    readonly property real cardWidth: 108

    columns: Math.max(1, Math.min(devices.length, maxColumns))
    columnSpacing: Style.spacing.md
    rowSpacing: Style.spacing.lg

    Repeater {
        model: root.devices
        // No per-card border — PopupCard already frames the whole popup, and
        // a second border this close in the same color just doubled up as a
        // distracting nested-frame artifact. Grouping is by proximity/spacing
        // alone.
        delegate: GaugeCard {
            device: modelData
            lowThreshold: root.lowThreshold
            criticalThreshold: root.criticalThreshold
            cardWidth: root.cardWidth
        }
    }
}
