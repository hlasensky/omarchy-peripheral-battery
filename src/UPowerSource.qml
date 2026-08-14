import QtQuick
import Quickshell.Services.UPower

// PATH A: native Quickshell UPower binding. This file loads ONLY if the module
// resolves — BatteryService probes it via Qt.createComponent and falls back to the
// `upower` CLI parser when the import fails. Keep the UPower import isolated here.
//
// Emits the same shape BatteryService/Panel expect:
//   {id, type, pct, state, model, charging}
Item {
    id: src

    // mirrored from BatteryService (set as bindings on createObject)
    property bool hideLaptopBattery: true
    property var  deviceTypes: DeviceIcons.known   // canonical type set

    property var devices: []

    function typeName(t) {
        switch (t) {
        case UPowerDeviceType.Mouse:       return "mouse";
        case UPowerDeviceType.Keyboard:    return "keyboard";
        case UPowerDeviceType.Headset:     return "headset";
        case UPowerDeviceType.Headphones:  return "headphones";
        case UPowerDeviceType.GamingInput: return "gamepad";
        case UPowerDeviceType.Pen:         return "pen";
        default:                           return "other";
        }
    }

    function stateName(s) {
        switch (s) {
        case UPowerDeviceState.Charging:     return "charging";
        case UPowerDeviceState.Discharging:  return "discharging";
        case UPowerDeviceState.FullyCharged: return "fully-charged";
        case UPowerDeviceState.Empty:        return "empty";
        default:                             return "unknown";
        }
    }

    function rebuild() {
        var out = [];
        var list = UPower.devices ? UPower.devices.values : [];
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (!d || !d.ready) continue;
            if (d.type === UPowerDeviceType.LinePower) continue;   // AC adapters
            if (d.isLaptopBattery && hideLaptopBattery) continue;  // laptop battery
            if (!(d.percentage > 0)) continue;                     // no real reading (0% = AC/aggregate)

            var t = typeName(d.type);
            if (!deviceTypes.includes(t)) continue;

            var s = stateName(d.state);
            out.push({
                id:       d.nativePath || String(i),
                type:     t,
                pct:      Math.round(d.percentage * 100),
                state:    s,
                model:    d.model || "",
                charging: s === "charging" || s === "fully-charged"
            });
        }
        devices = out;
    }

    // UPower is event-driven — rebuild whenever the device set changes.
    Connections {
        target: UPower.devices
        function onValuesChanged() { src.rebuild(); }
    }

    // filter changes from BatteryService should re-filter immediately
    onHideLaptopBatteryChanged: rebuild()
    onDeviceTypesChanged: rebuild()

    Component.onCompleted: rebuild()
}
