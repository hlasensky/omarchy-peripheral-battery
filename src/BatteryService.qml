import QtQuick
import Quickshell
import Quickshell.Io


// Headless data source. Public `devices` list is what Widget.qml / Panel.qml bind to.
Item {
    id: svc

    // --- Public API -------------------------------------------------------
    property var  devices: []          // [{id, type, pct, state, model, charging}]
    property int  lowThreshold: 20     // wired from Widget settings
    property int  criticalThreshold: 10
    property bool notifyOnLow: true
    property int  notifyRepeatMinutes: 0   // 0 = notify once per dip (no repeat)
    property bool hideLaptopBattery: true
    property var  deviceTypes: DeviceIcons.known   // filter set; overridden by Widget
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
        interval: 30000                // 30s safety net.
        repeat: true
        running: true
        // UPower.devices.valuesChanged only fires when a device is added or
        // removed, not when an existing device's percentage/state changes —
        // so PATH A needs periodic re-publishing too, not just PATH B's CLI scan.
        onTriggered: {
            if (svc.useUPower) { if (svc._upower) svc._upower.rebuild(); }
            else refresh();
        }
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

        // `upower -i` has NO `type:` key — the type is a bare section-header line
        // (e.g. "  headset") sitting above the indented percentage/state block.
        // Header vocabulary is centralized in DeviceIcons.parseHeaders.
        var headers = DeviceIcons.parseHeaders.join("|");
        var typeMatch = block.match(new RegExp("^[ \\t]+(" + headers + ")\\b[ \\t]*$", "mi"));
        var type = DeviceIcons.normalizeType(typeMatch ? typeMatch[1] : "");

        var pctStr    = field(/percentage:\s*([0-9]+)/);
        var state     = field(/\bstate:\s*(\S+)/);   // peripherals often omit this
        var model     = field(/model:\s*(.+)/);
        var powerSup  = field(/power supply:\s*(\S+)/);

        if (powerSup === "yes" && hideLaptopBattery) return null;
        if (!deviceTypes.includes(type)) return null;

        var pct = parseInt(pctStr, 10);
        if (isNaN(pct)) return null;
        return {id: path, type: type, pct: pct, state: state || "unknown", model: model,
                charging: state === "charging" || state === "fully-charged"};
    }

    function publish() {
        devices = _collected;
        checkLow(_collected);
    }

    // --- Low-battery notify: escalate by tier, re-arm on recharge ---------
    // Per device: { tier, ts } while at warning (1) or critical (2). Re-notify
    // when the tier increases (1 -> 2), or after notifyRepeatMinutes elapses
    // at the same tier (0 = disabled, the original once-per-dip behavior).
    property var _notified: ({})
    function checkLow(list) {
        if (!notifyOnLow) return;

        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            var t = DeviceIcons.tier(d.pct, d.state, lowThreshold, criticalThreshold);
            var entry = _notified[d.id];

            if (t > 0) {
                var now = Date.now();
                var escalated = entry && t > entry.tier;
                var dueForRepeat = entry && notifyRepeatMinutes > 0
                    && (now - entry.ts) >= notifyRepeatMinutes * 60000;
                if (!entry || escalated || dueForRepeat) {
                    notify(d, t);
                    _notified[d.id] = {tier: t, ts: now};
                }
            } else if (entry) {
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
    function notify(d, tier) {
        var urgency = tier >= 2 ? "critical" : "normal";
        var title = tier >= 2 ? "Critical battery" : "Low battery";
        notifier.command = ["notify-send", "-u", urgency,
            title, d.model + " " + d.pct + "%"];
        notifier.running = true;
    }
}
