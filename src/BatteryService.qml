import QtQuick
import Quickshell
import Quickshell.Io


// Headless data source. Public `devices` list is what Widget.qml / Panel.qml bind to.
Item {
    id: svc

    // --- Public API -------------------------------------------------------
    property var  devices: []          // [{id, type, pct, state, model, charging}]
    property int  lowThreshold: 20     // wired from Widget settings
    property bool notifyOnLow: true
    property bool hideLaptopBattery: true
    property var  deviceTypes: ["mouse", "keyboard", "headset",
    "headphones", "gaming input", "gamepad", "pen", "other"]
    property bool useUPower: false


    // --- PATH B: parse the `upower` CLI ----------------------------------
    // upower -e         -> device object paths (one per line)
    // upower -i <path>  -> "key: value" block (percentage, state, model, power supply, type)
    property var _pending: []           // paths still to detail this cycle
    property var _collected: []         // parsed devices this cycle

    Process {
        id: enumerate
        command: ["upower", "-e"]
        stdout: SplitParser {
            onRead: function (line) {
                if (line.includes("DisplayDevice") || line.includes("/line_power_")) return;

                _pending.push(line.trim());
            }
        }
        onExited: function (code, status) {
            if (_pending.length == 0) {
                publish();
                return;
            }

            nextDetail();
        }
    }

    Process {
        id: detail
        // command set dynamically to ["upower", "-i", <path>] before running
        property string _path: ""   // path currently being detailed
        // StdioCollector buffers the whole `-i` block; text is ready at exit.
        stdout: StdioCollector { id: detailOut }
        onExited: function (code, status) {
            var device = parseDevice(detailOut.text, detail._path);
            if (device) _collected.push(device);
            nextDetail();
        }
    }

    Timer {
        id: poll
        interval: 30000                // 30s safety net; UPower is event-driven.
        repeat: true
        running: !svc.useUPower        // path A is event-driven; no polling needed
        onTriggered: refresh()
    }

    // PATH A wrapper, instantiated only if Quickshell.Services.UPower resolves.
    property var _upower: null

    Component.onCompleted: {
        var c = Qt.createComponent("UPowerSource.qml");
        if (c.status === Component.Ready) {
            console.log("PATH A: UPower module OK");
            useUPower = true;
            _upower = c.createObject(svc, {
                hideLaptopBattery: Qt.binding(function () { return svc.hideLaptopBattery; }),
                deviceTypes:       Qt.binding(function () { return svc.deviceTypes; })
            });
            // reactive: republish whenever UPower's device set/values change
            _upower.devicesChanged.connect(function () {
                svc.devices = _upower.devices;
                svc.checkLow(_upower.devices);
            });
            svc.devices = _upower.devices;
            svc.checkLow(_upower.devices);
        } else {
            console.log("PATH B: UPower unavailable ->", c.errorString());
            refresh();
        }
    }

    function refresh() {
        if (useUPower) return;         // path A owns the data; ignore poll
        _pending = [];
        _collected = [];
        enumerate.running = true;
    }

    // Parse one `upower -i` block into a device object (or null to drop it).
    function parseDevice(block, path) {
        //   type:         -> normalize to mouse|keyboard|headset|gamepad|pen|other
        //   percentage:   -> "82%" -> 82 (int)
        //   state:        -> discharging|charging|fully-charged
        //   model:        -> string
        //   power supply: -> "yes" means laptop/UPS -> drop when hideLaptopBattery
        // Filters:
        //   - drop if power-supply and hideLaptopBattery
        //   - drop if normalized type not in deviceTypes
        // Return {id: path, type, pct, state, model, charging} or null.
        function field(re) {
            var m = block.match(re);
            return m ? m[1].trim() : "";
        }

        var rawType   = field(/\btype:\s*(.+)/);
        var pctStr    = field(/percentage:\s*([0-9]+)/);
        var state     = field(/state:\s*(\S+)/);
        var model     = field(/model:\s*(.+)/);
        var powerSup  = field(/power supply:\s*(\S+)/);

        if (powerSup === "yes" && hideLaptopBattery) return null;

        var type = rawType.toLowerCase();
        if (!deviceTypes.includes(type)) return null;

        var pct = parseInt(pctStr, 10);
        if (isNaN(pct)) return null;
        return {id: path, type: type, pct: pct, state: state, model: model, charging: state === "charging" || state === "fully-charged"
};
    }

    function publish() {
        devices = _collected;
        checkLow(_collected);
    }

    // --- Low-battery notify: fire once per dip, re-arm on recharge --------
    property var _notified: ({})       // id -> true while below threshold
    function checkLow(list) {
        if (!notifyOnLow) return;
        //   below = d.pct <= lowThreshold && d.state === "discharging"
        //   if below && !_notified[d.id]:  notify(d); _notified[d.id] = true
        //   if !below && _notified[d.id]:  delete _notified[d.id]   // re-arm

        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            var below = d.pct <= lowThreshold && d.state === "discharging";
            if (below && !_notified[d.id]) {
                notify(d);
                _notified[d.id] = true;
            }
            if (!below && _notified[d.id]) {
                delete _notified[d.id];
            }
        }
    }

    function nextDetail() {
        if (_pending.length === 0) { publish(); return; }
        var path = _pending.shift();
        detail._path = path;
        detail.command = ["upower", "-i", path];
        detail.running = true;            // StdioCollector resets per run
    }


    Process { id: notifier }           // reuse for notify-send
    function notify(d) {
        notifier.command = ["notify-send", "-u", "critical",
            "Low battery", d.model + " " + d.pct + "%"];
        notifier.running = true;
    }
}
