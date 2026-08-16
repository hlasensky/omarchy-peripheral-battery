pragma Singleton
import QtQuick
import qs.Commons    // Color tokens

// Single source of truth for device *types*: the canonical type list, the words
// the `upower` CLI can emit, and the type -> glyph mapping. Registered as a
// singleton in qmldir, so BatteryService / UPowerSource / Panel all share it.
//
// Nerd Font (Material Design) codepoints — needs a Nerd-Font-patched family at the
// bar for these to render. Built via String.fromCodePoint so the Plane-15 (5-hex)
// codepoints can't get truncated/mangled by text encoding.
QtObject {
    // Canonical peripheral types we display. Also the default filter set.
    readonly property var known: [
        "mouse", "keyboard", "headset", "headphones",
        "gamepad", "pen", "other"
    ]

    // Section-header words `upower -i` can emit (path B parses these). Superset of
    // `known` plus power-supply / non-peripheral types we recognize only so the
    // parser can identify and then filter them out.
    readonly property var parseHeaders: [
        "gaming-input", "gaming input",
        "battery", "ups", "tablet", "phone", "touchpad", "speakers"
    ].concat(known)

    function normalizeType(type) {
        var normalized = String(type || "").trim().toLowerCase();
        if (normalized === "gaming-input" || normalized === "gaming input")
            return "gamepad";
        return normalized;
    }

    // Charge tier shared by Widget's bar icon and DevicePanel's card tint:
    // 0 = normal, 1 = warning (<= lowThreshold), 2 = critical (<= criticalThreshold).
    // Charging/fully-charged is always 0 regardless of pct.
    function tier(pct, state, lowThreshold, criticalThreshold) {
        if (state === "charging" || state === "fully-charged") return 0;
        if (pct <= criticalThreshold) return 2;
        if (pct <= lowThreshold) return 1;
        return 0;
    }

    // Color.qml (the theme's Commons singleton) only defines
    // foreground/background/accent/urgent/muted — there's no separate
    // "warning/amber" token to reach for. So tier 1 is Color.urgent at
    // reduced opacity (a visibly softer red) and tier 2 is full-strength
    // Color.urgent; `normalColor` is whatever the caller uses at tier 0
    // (differs between the bar icon and the popup card text).
    function tierColor(tier, normalColor) {
        if (tier === 2) return Color.urgent;
        if (tier === 1) return Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.6);
        return normalColor;
    }

    function glyph(type) {
        switch (type) {
        case "mouse":        return String.fromCodePoint(0xF037D); // nf-md-mouse
        case "keyboard":     return String.fromCodePoint(0xF030C); // nf-md-keyboard
        case "headset":
        case "headphones":   return String.fromCodePoint(0xF02CB); // nf-md-headphones
        case "gamepad":      return String.fromCodePoint(0xF0296); // nf-md-gamepad
        case "pen":          return String.fromCodePoint(0xF03EA); // nf-md-pen
        default:             return String.fromCodePoint(0xF0079); // nf-md-battery
        }
    }

    // charging indicator: nf-md-lightning_bolt
    readonly property string bolt: String.fromCodePoint(0xF140B)

    // fixed bar summary icon: battery + wireless device (nf-md-battery_bluetooth)
    readonly property string summary: String.fromCodePoint(0xF0948)
}
