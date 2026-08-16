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
    property int criticalThreshold: 10

    readonly property int vpad: Style.spacing.sm
    readonly property int hpad: Style.spacing.md
    readonly property int gridColumns: 3
    readonly property real cardWidth: 108

    // Grid grows/shrinks with device count instead of reserving a fixed
    // 3-wide slot regardless of how many peripherals are actually present.
    // Floored so a single device doesn't collapse to a starved-looking box —
    // PopupCard's own chrome padding is sized for a normal-width popup, so
    // shrinking all the way to content-tight makes that padding read as a
    // huge, disproportionate gap.
    readonly property int columns: Math.max(1, Math.min(devices.length, gridColumns))

    implicitWidth: devices.length > 0
        ? Math.max(200, columns * cardWidth + (columns - 1) * Style.spacing.md + hpad * 2)
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

        // empty state
        Text {
            visible: panel.devices.length === 0
            width: parent.width
            text: "No peripherals reporting battery"
            color: Color.muted
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
        }

        GridLayout {
            // Column only manages vertical stacking, so without this the
            // grid stayed left-aligned at full width — with fewer than
            // gridColumns cards, the leftover slack all piled up on the
            // right instead of framing the cards evenly.
            anchors.horizontalCenter: col.horizontalCenter
            visible: panel.devices.length > 0
            columns: panel.columns
            columnSpacing: Style.spacing.md
            rowSpacing: Style.spacing.lg

            Repeater {
                model: panel.devices
                // No per-card border — PopupCard already frames the whole
                // popup, and a second border this close in the same color
                // just doubled up as a distracting nested-frame artifact.
                // Grouping is by proximity/spacing alone.
                delegate: ColumnLayout {
                    Layout.preferredWidth: panel.cardWidth
                    Layout.alignment: Qt.AlignTop
                    spacing: Style.spacing.xs

                    readonly property int tier: DeviceIcons.tier(modelData.pct, modelData.state,
                        panel.lowThreshold, panel.criticalThreshold)
                    readonly property color tint: DeviceIcons.tierColor(tier, Color.popups.text)

                    // battery ring gauge — percentage centered inside, bolt
                    // swaps in only while charging (replaces device-type
                    // glyph + bolt + minibar + separate percent text)
                    BatteryGauge {
                        Layout.alignment: Qt.AlignHCenter
                        pct: modelData.pct
                        state: modelData.state
                        size: 44
                        contentColor: parent.tint
                    }

                    // model name
                    Text {
                        Layout.preferredWidth: panel.cardWidth
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.model || modelData.type
                        color: Color.popups.text
                        font.pixelSize: Style.font.bodySmall
                        font.weight: Font.Light
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
