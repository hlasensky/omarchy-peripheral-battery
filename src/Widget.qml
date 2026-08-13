import QtQuick
import qs.Ui         // BarWidget, PopupCard
import qs.Commons    // Color, Style tokens

// Host injects: bar, moduleName, settings. Read config via setting(); write via
// bar.shell.updateEntryInline(moduleName, settings).
BarWidget {
    id: root
    moduleName: "hlasensky.peripheral_battery"  // must match manifest id

    readonly property int  lowThreshold: setting("lowThreshold", 20)
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

    // Representative device for the bar = the one lowest on charge (what needs
    // attention). Everything else lives in the popup.
    readonly property var rep: {
        var r = null;
        var list = service.devices;
        for (var i = 0; i < list.length; i++)
            if (!r || list[i].pct < r.pct) r = list[i];
        return r;
    }
    readonly property bool repLow: rep && rep.pct <= lowThreshold
        && rep.state !== "charging" && rep.state !== "fully-charged"

    // no peripherals -> collapse so the bar keeps no dead gap.
    visible: service.devices.length > 0
    // Size to the icon button; it owns the standard bar slot + padding.
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    // Standard bar icon button: correct slot size, optical glyph centering,
    // hover + click — same base every first-party icon widget uses.
    BarIconButton {
        id: button
        anchors.centerIn: parent
        bar: root.bar
        text: DeviceIcons.summary          // battery + wireless device
        useActiveColor: false
        foreground: root.repLow ? Color.urgent
                                : (root.bar ? root.bar.barForeground : Color.foreground)
        tooltipText: "Peripheral battery"
        onPressed: function (b) { card.open = !card.open }
    }

    // PopupCard owns the outside-click dismissal (HyprlandFocusGrab) and the
    // card chrome; we just supply the content and its size.
    PopupCard {
        id: card
        anchorItem: button
        bar: root.bar
        contentWidth: 320
        contentHeight: panel.implicitHeight + card.verticalContentInset

        DevicePanel {
            id: panel
            anchors.fill: parent
            devices: service.devices
            lowThreshold: root.lowThreshold
        }
    }
}
