import QtQuick
import QtQuick.Shapes
import qs.Commons  // Color, Style

// Ring battery gauge for the Rings popup style: a continuous round-capped arc
// over the same track tint the List meters use, filled clockwise from 12
// o'clock, with the percentage centered inside. Charging is shown by the
// caller (in the state label), not in the ring, so the reading stays clean.
Item {
    id: root

    // --- Public API --------------------------------------------------
    property int    pct: 0                     // 0-100
    property string state: "unknown"           // charging | discharging | fully-charged | empty | unknown
    property real   size: 56                   // diameter in px
    property real   thickness: Math.max(3, Math.round(size * 0.085))
    property color  ringColor: Color.foreground
    property color  trackColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
    property color  contentColor: Color.foreground
    property string fontFamily: Style.font.family

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    // Pin fully-charged to a complete ring even if UPower reports e.g. 97%
    // for a peripheral it considers "done".
    property real fraction: state === "fully-charged" ? 1 : Math.max(0, Math.min(1, pct / 100))
    Behavior on fraction { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

    readonly property real radius: (size - thickness) / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: root.radius; radiusY: root.radius
                startAngle: 0; sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: root.fraction > 0 ? root.ringColor : "transparent"
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: root.radius; radiusY: root.radius
                startAngle: -90
                sweepAngle: 360 * root.fraction
            }
        }
    }

    Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: root.pct + "%"
        color: root.contentColor
        font.family: root.fontFamily
        font.pixelSize: Math.max(8, Math.round(root.size * 0.22))
        font.bold: true
    }
}
