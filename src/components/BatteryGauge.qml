import QtQuick
import ".."        // DeviceIcons
import qs.Ui       // OpticalGlyph
import qs.Commons  // Color, Style

// Dot-matrix battery gauge — a ring of small dots (Nothing OS-style) instead
// of a solid stroke, filled clockwise from 12 o'clock by charge level, with
// the percentage centered inside — or a bolt glyph when actively charging.
// Used by GaugeCard for the Gauge popup style.
//
// Ring color comes from DeviceIcons.levelColor() — the same charge-amount
// lerp DeviceListRow's bar fill uses, so both popup styles read identically
// at a glance instead of drifting into their own palettes.
//
// The percentage stays visible in every state. Charging adds a small breathing
// bolt beside it, so users never lose the actual reading while on a charger.
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
    readonly property color ringColor: ringColorOverride.a > 0
        ? ringColorOverride
        : DeviceIcons.levelColor(pct)

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

    Row {
        anchors.centerIn: parent
        spacing: Math.max(1, root.size * 0.02)

        Text {
            text: root.pct + "%"
            color: root.contentColor
            font.pixelSize: Math.max(7, root.size * 0.24)
            font.weight: Font.Light
            horizontalAlignment: Text.AlignHCenter
        }

        OpticalGlyph {
            id: bolt
            anchors.verticalCenter: parent.verticalCenter
            visible: root.state === "charging"
            text: DeviceIcons.bolt
            fontSize: Math.max(6, root.size * 0.22)
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
    }
}
