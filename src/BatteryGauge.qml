import QtQuick
import qs.Ui       // OpticalGlyph
import qs.Commons  // Color, Style

// Dot-matrix battery gauge — a ring of small dots (Nothing OS-style) instead
// of a solid stroke, filled clockwise from 12 o'clock by charge level, with
// the percentage centered inside — or a bolt glyph when actively charging.
// Used in DevicePanel's per-device cards.
//
// Ring color is a straight lerp between Color.urgent (0%) and Color.accent
// (100%) — both theme tokens already used by this plugin's low-battery
// convention (DevicePanel's row `tint`, Widget's `repTier`), so the gauge
// tracks whatever theme is active instead of a fixed rainbow.
//
// Centered content swaps by state instead of layering both: the percentage
// is the normal at-rest readout, the bolt only appears (and breathes) while
// state === "charging" — so it reads as a direction flag, not decoration.
Item {
    id: root

    // --- Public API --------------------------------------------------
    property int    pct: 0                             // 0-100
    property string state: "unknown"                   // charging | discharging | fully-charged | empty | unknown
    property real   size: 40                            // diameter in px; everything else scales off this
    property color  ringColorOverride: "transparent"    // set alpha > 0 to force a flat ring color
    property color  contentColor: Color.foreground      // bolt + percentage color

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // --- Color ------------------------------------------------------------
    function _lerp(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                        a.g + (b.g - a.g) * t,
                        a.b + (b.b - a.b) * t,
                        a.a + (b.a - a.a) * t);
    }

    readonly property color ringColor: ringColorOverride.a > 0
        ? ringColorOverride
        : _lerp(Color.urgent, Color.accent, Math.max(0, Math.min(100, pct)) / 100)

    // --- Fill fraction, animated ----------------------------------------
    // Pin fully-charged to a visually complete ring even if UPower reports
    // e.g. 97% for a peripheral it considers "done".
    property real fraction: state === "fully-charged"
        ? 1
        : Math.max(0, Math.min(1, pct / 100))
    Behavior on fraction { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    // --- Dot ring -----------------------------------------------------
    readonly property int dotCount: 28
    readonly property real dotSize: Math.max(1, size * 0.045)
    readonly property real dotRingRadius: size / 2 - dotSize * 1.5

    Repeater {
        model: root.dotCount
        delegate: Rectangle {
            readonly property real angleRad: (-90 + (360 / root.dotCount) * index) * Math.PI / 180
            readonly property bool filled: (index / root.dotCount) < root.fraction

            width: root.dotSize
            height: root.dotSize
            radius: width / 2
            x: root.width / 2 + root.dotRingRadius * Math.cos(angleRad) - width / 2
            y: root.height / 2 + root.dotRingRadius * Math.sin(angleRad) - height / 2
            color: filled ? root.ringColor : Qt.rgba(Color.muted.r, Color.muted.g, Color.muted.b, 0.4)

            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    OpticalGlyph {
        id: bolt
        anchors.centerIn: parent
        visible: root.state === "charging"
        text: DeviceIcons.bolt
        fontSize: Math.max(6, root.size * 0.38)
        color: root.contentColor

        SequentialAnimation on opacity {
            running: root.state === "charging"
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            // Our instances are persistently alive (popup rows live as long
            // as the popup) — if charging stops mid-pulse, alwaysRunToEnd
            // could otherwise leave the bolt resting dim indefinitely, so
            // force it back to full opacity explicitly.
            onRunningChanged: if (!running) bolt.opacity = 1.0
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.state !== "charging"
        text: root.pct + "%"
        color: root.contentColor
        font.pixelSize: Math.max(7, root.size * 0.24)
        font.weight: Font.Light
        horizontalAlignment: Text.AlignHCenter
    }
}
