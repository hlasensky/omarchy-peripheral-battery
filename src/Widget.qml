import QtQuick
import QtQuick.Controls
import "components"  // BatteryGauge
import qs.Commons    // Color, Style tokens
import qs.Ui         // Panel, KeyboardPanel, PanelHero, ...

// Bar icon + popup, built on the same native kit the first-party Agents panel
// uses (Panel / KeyboardPanel / PanelHero / section headers / meters), so the
// popup reads like the rest of the shell. Devices are grouped by type; the
// hero's switch picks between the List and Rings layouts. Clicking a device
// name renames it (stored per serial in settings.deviceNames).
Panel {
    id: root
    moduleName: "hl.peripheral_battery"  // must match manifest id
    ipcTarget: "hl.peripheral_battery"

    readonly property int  lowThreshold: setting("lowThreshold", 20)
    // Must stay below lowThreshold or the warning tier collapses to zero width.
    readonly property int  criticalThreshold: Math.min(setting("criticalThreshold", 10), lowThreshold - 1)
    readonly property bool hideLaptop:   setting("hideLaptopBattery", true)
    readonly property bool notifyOnLow:  setting("notifyOnLow", true)
    readonly property int  notifyRepeatMinutes: setting("notifyRepeatMinutes", 0)
    readonly property var  deviceTypes:  setting("deviceTypes", ["mouse","keyboard","headset","gamepad"])
    readonly property string displayStyle: setting("displayStyle", "Gauge")
    readonly property var  deviceNames:  setting("deviceNames", ({}))
    readonly property string language:   setting("language", "auto")
    onLanguageChanged: Strings.language = language
    readonly property bool isList: displayStyle.toLowerCase() === "list"

    readonly property color foreground: bar ? bar.foreground : Color.foreground
    readonly property color dim: Qt.darker(foreground, 1.55)
    readonly property color track: Style.selectedFillFor(foreground, Color.accent)
    readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

    // The manifest's service entry point is a shell-managed singleton. Every
    // monitor's bar widget reads that one instance instead of running its own
    // UPower scan, HID probe, and notification state.
    readonly property var batteryService: root.bar && root.bar.shell
        ? root.bar.shell.serviceFor(root.moduleName) : null
    readonly property var devices: batteryService ? batteryService.devices : []

    // Devices grouped by type, in DeviceIcons.known order, names sorted.
    readonly property var groups: {
        var out = [];
        var order = DeviceIcons.known;
        for (var i = 0; i < order.length; i++) {
            var list = [];
            for (var j = 0; j < devices.length; j++)
                if ((order.indexOf(devices[j].type) >= 0 ? devices[j].type : "other") === order[i])
                    list.push(devices[j]);
            if (!list.length) continue;
            list.sort(function (a, b) { return String(a.model).localeCompare(String(b.model)); });
            out.push({type: order[i], devices: list});
        }
        return out;
    }

    // Representative device for the bar = the one lowest on charge (what needs
    // attention). Everything else lives in the popup.
    readonly property var rep: {
        var r = null;
        for (var i = 0; i < devices.length; i++)
            if (!r || devices[i].pct < r.pct) r = devices[i];
        return r;
    }
    readonly property int repTier: rep
        ? DeviceIcons.tier(rep.pct, rep.state, lowThreshold, criticalThreshold) : 0
    readonly property int chargingCount: {
        var n = 0;
        for (var i = 0; i < devices.length; i++) if (devices[i].state === "charging") n++;
        return n;
    }

    // Two lines under the title: how many devices (plus the lowest reading
    // once it needs attention), then what's charging.
    function heroMeta() {
        var first = devices.length === 1 ? Strings.t("device") : Strings.t("devices", devices.length);
        if (repTier > 0) first += " · " + Strings.t("lowest", rep.pct + "%");
        var second = chargingCount > 0 ? Strings.t("charging", chargingCount)
            : (rep && rep.state === "fully-charged" ? Strings.t("allCharged") : "");
        return second ? first + "\n" + second : first;
    }

    function fraction(d) {
        return d.state === "fully-charged" ? 1 : Math.max(0, Math.min(1, d.pct / 100));
    }
    function tint(d) {
        return DeviceIcons.tierColor(DeviceIcons.tier(d.pct, d.state, lowThreshold, criticalThreshold), foreground);
    }
    function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // --- Settings writes ----------------------------------------------------
    // Persist through the shell's own settings store (updateEntryInline), the
    // same path first-party panels use, never a raw shell.json edit.
    function writeSettings(patch) {
        var updated = Object.assign({}, root.settings, patch);
        if (root.bar && root.bar.shell) root.bar.shell.updateEntryInline(root.moduleName, updated);
    }

    function setDisplayStyle(style) { writeSettings({displayStyle: style}); }

    // Stored as settings.deviceNames[key] = {name, type}; an empty name (or
    // the device's own model) drops the rename, and the entry with it when
    // nothing else is overridden.
    property string editingKey: ""
    function beginRename(d) { editingKey = d.key || ""; }
    function commitRename(d, name) {
        editingKey = "";
        if (!d.key) return;
        var names = Object.assign({}, root.deviceNames);
        var entry = names[d.key];
        entry = typeof entry === "string" ? {name: entry} : Object.assign({}, entry || {});
        name = String(name || "").trim();
        if (name && name !== d.defaultModel) entry.name = name; else delete entry.name;
        if (Object.keys(entry).length) names[d.key] = entry; else delete names[d.key];
        writeSettings({deviceNames: names});
    }

    function syncServiceSettings() {
        if (!batteryService) return;
        batteryService.lowThreshold = lowThreshold;
        batteryService.criticalThreshold = criticalThreshold;
        batteryService.notifyOnLow = notifyOnLow;
        batteryService.notifyRepeatMinutes = notifyRepeatMinutes;
        batteryService.hideLaptopBattery = hideLaptop;
        batteryService.deviceTypes = deviceTypes;
        batteryService.deviceNames = deviceNames;
    }
    onBatteryServiceChanged: syncServiceSettings()
    onLowThresholdChanged: syncServiceSettings()
    onCriticalThresholdChanged: syncServiceSettings()
    onNotifyOnLowChanged: syncServiceSettings()
    onNotifyRepeatMinutesChanged: syncServiceSettings()
    onHideLaptopChanged: syncServiceSettings()
    onDeviceTypesChanged: syncServiceSettings()
    onDeviceNamesChanged: syncServiceSettings()
    Component.onCompleted: {
        Strings.language = language;
        syncServiceSettings();
    }

    onOpenedChanged: {
        editingKey = "";
        if (opened) {
            if (panelFlick) panelFlick.contentY = 0;
            Qt.callLater(function () { keyCatcher.forceActiveFocus() });
        }
    }

    // no peripherals -> collapse so the bar keeps no dead gap.
    visible: devices.length > 0
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: DeviceIcons.summary          // battery + wireless device
        useActiveColor: false
        foreground: DeviceIcons.tierColor(root.repTier, root.bar ? root.bar.barForeground : Color.foreground)
        tooltipText: root.rep ? (root.rep.model || root.rep.type) + " " + root.rep.pct + "%" : Strings.t("title")
        onPressed: function (b) { root.toggle() }
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(380))
        contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            // hand every key to the rename field while it's open
            blocked: root.editingKey !== ""

            onCloseRequested: root.close()
            onTabRequested: function (direction) { root.switchPanel(direction) }
            onMoveRequested: function (dx, dy) {
                if (dx !== 0) root.setDisplayStyle(root.isList ? "Gauge" : "List");
                if (dy !== 0)
                    panelFlick.contentY = Math.max(0, Math.min(panelFlick.contentY + dy * Style.space(56),
                        panelFlick.contentHeight - panelFlick.height));
            }

            Flickable {
                id: panelFlick
                anchors.fill: parent
                contentWidth: width
                contentHeight: column.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                Column {
                    id: column
                    width: panelFlick.width
                    spacing: Style.space(12)

                    // ---------- Hero: glyph · title · summary · style switch ----------
                    PanelHero {
                        width: parent.width
                        title: Strings.t("title")
                        meta: root.heroMeta()
                        foreground: root.foreground
                        fontFamily: root.fontFamily

                        iconComponent: Component {
                            Text {
                                textFormat: Text.PlainText
                                text: DeviceIcons.summary
                                color: DeviceIcons.tierColor(root.repTier, root.foreground)
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.display
                            }
                        }

                        trailingControl: Component {
                            ButtonGroup {
                                options: [
                                    {value: "List", label: Strings.t("styleList")},
                                    {value: "Gauge", label: Strings.t("styleGauge")}
                                ]
                                value: root.isList ? "List" : "Gauge"
                                foreground: root.foreground
                                fontFamily: root.fontFamily
                                fontSize: Style.font.caption
                                focusable: false
                                spacing: Style.spacing.xs
                                onChanged: function (v) { root.setDisplayStyle(v) }
                            }
                        }
                    }

                    Text {
                        visible: root.devices.length === 0
                        width: parent.width
                        topPadding: Style.space(12)
                        text: Strings.t("none")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }

                    // ---------- One section per device type ----------
                    Repeater {
                        model: root.groups

                        Column {
                            id: section
                            required property var modelData
                            width: column.width
                            spacing: Style.space(12)

                            PanelSeparator { width: parent.width; foreground: root.foreground }

                            Column {
                                width: parent.width
                                spacing: Style.space(10)

                                PanelSectionHeader {
                                    width: parent.width
                                    text: Strings.typeLabel(section.modelData.type).toUpperCase()
                                    foreground: root.foreground
                                    fontFamily: root.fontFamily
                                }

                                // List layout
                                Column {
                                    visible: root.isList
                                    width: parent.width
                                    spacing: Style.space(14)

                                    Repeater {
                                        model: root.isList ? section.modelData.devices : []
                                        DeviceRow { required property var modelData; width: parent.width; device: modelData }
                                    }
                                }

                                // Rings layout
                                Grid {
                                    id: tiles
                                    visible: !root.isList
                                    width: parent.width
                                    columns: 3
                                    spacing: Style.space(8)
                                    readonly property real tileWidth: (width - spacing * (columns - 1)) / columns

                                    Repeater {
                                        model: root.isList ? [] : section.modelData.devices
                                        DeviceTile { required property var modelData; width: tiles.tileWidth; device: modelData }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.devices.length > 0
                        width: parent.width
                        topPadding: Style.space(2)
                        text: root.editingKey !== "" ? Strings.t("renameEditing") : Strings.t("renameHint")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // Device name that turns into a text field on click. Shared by both
    // layouts; `centered` is for the Rings tiles.
    component DeviceName: Item {
        id: nameItem
        property var device: ({})
        property bool centered: false
        property real fontSize: Style.font.body
        readonly property bool editing: root.editingKey !== "" && root.editingKey === device.key

        implicitHeight: editing ? field.implicitHeight : label.implicitHeight

        Text {
            id: label
            visible: !nameItem.editing
            width: parent.width
            textFormat: Text.PlainText
            text: nameItem.device.model || nameItem.device.type || ""
            color: nameHover.hovered ? Color.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: nameItem.fontSize
            horizontalAlignment: nameItem.centered ? Text.AlignHCenter : Text.AlignLeft
            elide: Text.ElideRight

            HoverHandler { id: nameHover; cursorShape: Qt.IBeamCursor }
            TapHandler { onTapped: root.beginRename(nameItem.device) }
            PanelToolTip { visible: nameHover.hovered; text: Strings.t("renameTooltip"); fontFamily: root.fontFamily }
        }

        TextField {
            id: field
            visible: nameItem.editing
            width: parent.width
            font.family: root.fontFamily
            font.pixelSize: nameItem.fontSize
            foreground: root.foreground
            horizontalPadding: Style.spacing.controlGap
            verticalPadding: Style.space(2)
            horizontalAlignment: nameItem.centered ? TextInput.AlignHCenter : TextInput.AlignLeft
            onVisibleChanged: if (visible) {
                text = nameItem.device.model || "";
                selectAll();
                Qt.callLater(forceActiveFocus);
            }
            onAccepted: root.commitRename(nameItem.device, text)
            Keys.onEscapePressed: root.editingKey = ""
        }
    }

    // List row: glyph · name · percentage, meter, then the charge state.
    component DeviceRow: Column {
        id: row
        property var device: ({})
        readonly property color tint: root.tint(device)
        spacing: Style.space(6)

        Item {
            width: parent.width
            implicitHeight: Math.max(glyph.implicitHeight, rowName.implicitHeight, pct.implicitHeight)

            Text {
                id: glyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.font.icon + Style.space(4)
                textFormat: Text.PlainText
                text: DeviceIcons.glyph(row.device.type)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.icon
            }

            DeviceName {
                id: rowName
                anchors.left: glyph.right
                anchors.leftMargin: Style.space(6)
                anchors.right: pct.left
                anchors.rightMargin: Style.spacing.sm
                anchors.verticalCenter: parent.verticalCenter
                device: row.device
            }

            Row {
                id: pct
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                Text {
                    id: bolt
                    visible: row.device.state === "charging"
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: DeviceIcons.bolt
                    color: row.tint
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption

                    SequentialAnimation on opacity {
                        running: bolt.visible
                        loops: Animation.Infinite
                        NumberAnimation { from: 1.0; to: 0.45; duration: 950; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.45; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: row.device.pct + "%"
                    color: row.tint
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                }
            }
        }

        Meter { width: parent.width; value: root.fraction(row.device); color: row.tint; charging: row.device.state === "charging" }

        Text {
            width: parent.width
            textFormat: Text.PlainText
            text: Strings.stateLabel(row.device.state)
            color: row.device.state === "charging" ? root.foreground : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
        }
    }

    // Rings tile: ring gauge, name, state — on the faint surface the Agents
    // model rows use, so tiles group without a nested border.
    component DeviceTile: Rectangle {
        id: tile
        property var device: ({})
        readonly property color tint: root.tint(device)
        readonly property bool charging: device.state === "charging"

        implicitHeight: tileCol.implicitHeight + Style.space(14) * 2
        radius: Style.cornerRadius
        color: root.alpha(root.foreground, tileHover.hovered ? 0.08 : 0.05)
        Behavior on color { ColorAnimation { duration: 120 } }

        HoverHandler { id: tileHover }

        Column {
            id: tileCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            BatteryGauge {
                anchors.horizontalCenter: parent.horizontalCenter
                pct: tile.device.pct
                state: tile.device.state
                size: Style.space(60)
                ringColor: tile.tint
                trackColor: root.track
                contentColor: root.foreground
                fontFamily: root.fontFamily
            }

            Column {
                width: parent.width
                spacing: Style.space(2)

                DeviceName {
                    width: parent.width
                    device: tile.device
                    centered: true
                    fontSize: Style.font.bodySmall
                }

                // state label; the bolt rides here while charging
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Style.space(4)

                    Text {
                        id: tileBolt
                        visible: tile.charging
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: DeviceIcons.bolt
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption

                        SequentialAnimation on opacity {
                            running: tileBolt.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.45; duration: 950; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.45; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: Strings.stateLabel(tile.device.state)
                        color: tile.charging ? root.foreground : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                    }
                }
            }
        }
    }

    // Rounded track, as in the Agents panel; breathes while charging.
    component Meter: Item {
        id: meter
        property real value: 0
        property color color: root.foreground
        property bool charging: false
        implicitHeight: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))

        Rectangle { id: meterTrack; anchors.fill: parent; radius: height / 2; color: root.track }

        Rectangle {
            anchors.left: meterTrack.left
            anchors.verticalCenter: meterTrack.verticalCenter
            height: meterTrack.height
            radius: meterTrack.radius
            width: meterTrack.width * meter.value
            color: meter.color
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            SequentialAnimation on opacity {
                running: meter.charging
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
        }
    }
}
