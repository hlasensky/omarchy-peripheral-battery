import QtQuick
import Quickshell
import qs.Ui         // BarWidget base
import qs.Commons    // Color, Style tokens

// Host injects: bar, moduleName, settings. Read config via setting(); write via
// bar.shell.updateEntryInline(moduleName, settings).
BarWidget {
    id: root
    moduleName: "hlasensky.peripheral_battery"  // must match manifest id

    readonly property int  lowThreshold: setting("lowThreshold", 20)
    readonly property bool showLabels:   setting("showLabels", true)
    readonly property bool hideLaptop:   setting("hideLaptopBattery", true)
    readonly property bool notifyOnLow:  setting("notifyOnLow", true)
    readonly property var  deviceTypes:  setting("deviceTypes", ["mouse","keyboard","headset","gamepad"])

    BatteryService {
        id: service
        lowThreshold: root.lowThreshold
        notifyOnLow: root.notifyOnLow
        hideLaptopBattery: root.hideLaptop
        deviceTypes: root.deviceTypes
    }

    // empty state: no peripherals -> collapse so the bar keeps no dead gap.
    visible: service.devices.length > 0

    Row {
        spacing: 8
        Repeater {
            model: service.devices
            delegate: Row {
                spacing: 3
                readonly property bool low: modelData.pct <= root.lowThreshold

                Text {
                    text: DeviceIcons.glyph(modelData.type)
                    color: low ? Color.urgent : Color.foreground
                }
                Text {
                    visible: root.showLabels
                    text: modelData.pct + "%" + (parent.low ? "!" : "")
                    color: low ? Color.urgent : Color.foreground
                }
            }
        }
    }

    // Click toggles a local popover anchored under the widget. BarWidget has no
    // popup API, so we own a PopupWindow here (no separate panel plugin needed).
    onPressed: function(b) {
        popup.visible = !popup.visible
    }

    PopupWindow {
        id: popup
        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Left   // attach to widget's bottom-left
        anchor.gravity: Edges.Bottom | Edges.Right // grow down/right from there
        implicitWidth: 320
        implicitHeight: panelContent.implicitHeight
        color: "transparent"
        visible: false

        Panel {
            id: panelContent
            anchors.fill: parent
            devices: service.devices
            lowThreshold: root.lowThreshold
        }
    }
}
