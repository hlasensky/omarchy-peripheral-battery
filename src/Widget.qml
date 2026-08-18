import QtQuick
import qs.Ui         // BarWidget, PopupCard
import qs.Commons    // Color, Style tokens

// Host injects: bar, moduleName, settings. Read config via setting(); write via
// bar.shell.updateEntryInline(moduleName, settings).
BarWidget {
    id: root
    moduleName: "hl.peripheral_battery"  // must match manifest id

    readonly property int  lowThreshold: setting("lowThreshold", 20)
    // Must stay below lowThreshold or the warning tier collapses to zero width.
    readonly property int  criticalThreshold: Math.min(setting("criticalThreshold", 10), lowThreshold - 1)
    readonly property bool hideLaptop:   setting("hideLaptopBattery", true)
    readonly property bool notifyOnLow:  setting("notifyOnLow", true)
    readonly property int  notifyRepeatMinutes: setting("notifyRepeatMinutes", 0)
    readonly property var  deviceTypes:  setting("deviceTypes", ["mouse","keyboard","headset","gamepad"])

    // The manifest's service entry point is a shell-managed singleton. Every
    // monitor's bar widget reads that one instance instead of running its own
    // UPower scan, HID probe, and notification state.
    readonly property var batteryService: root.bar && root.bar.shell
        ? root.bar.shell.serviceFor(root.moduleName) : null
    readonly property var devices: batteryService ? batteryService.devices : []

    function syncServiceSettings() {
        if (!batteryService) return;
        batteryService.lowThreshold = lowThreshold;
        batteryService.criticalThreshold = criticalThreshold;
        batteryService.notifyOnLow = notifyOnLow;
        batteryService.notifyRepeatMinutes = notifyRepeatMinutes;
        batteryService.hideLaptopBattery = hideLaptop;
        batteryService.deviceTypes = deviceTypes;
    }
    onBatteryServiceChanged: syncServiceSettings()
    onLowThresholdChanged: syncServiceSettings()
    onCriticalThresholdChanged: syncServiceSettings()
    onNotifyOnLowChanged: syncServiceSettings()
    onNotifyRepeatMinutesChanged: syncServiceSettings()
    onHideLaptopChanged: syncServiceSettings()
    onDeviceTypesChanged: syncServiceSettings()
    Component.onCompleted: syncServiceSettings()

    // Representative device for the bar = the one lowest on charge (what needs
    // attention). Everything else lives in the popup.
    readonly property var rep: {
        var r = null;
        var list = root.devices;
        for (var i = 0; i < list.length; i++)
            if (!r || list[i].pct < r.pct) r = list[i];
        return r;
    }
    readonly property int repTier: rep
        ? DeviceIcons.tier(rep.pct, rep.state, lowThreshold, criticalThreshold) : 0

    // no peripherals -> collapse so the bar keeps no dead gap.
    visible: root.devices.length > 0
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
        foreground: DeviceIcons.tierColor(root.repTier,
            root.bar ? root.bar.barForeground : Color.foreground)
        tooltipText: root.rep
            ? (root.rep.model || root.rep.type) + " " + root.rep.pct + "%"
            : "Peripheral battery"
        onPressed: function (b) { card.open = !card.open }
    }

    // PopupCard owns the outside-click dismissal (HyprlandFocusGrab) and the
    // card chrome; we just supply the content and its size.
    PopupCard {
        id: card
        anchorItem: button
        bar: root.bar
        contentWidth: panel.implicitWidth
        contentHeight: panel.implicitHeight + card.verticalContentInset

        DevicePanel {
            id: panel
            anchors.fill: parent
            devices: root.devices
            lowThreshold: root.lowThreshold
            criticalThreshold: root.criticalThreshold
        }
    }
}
