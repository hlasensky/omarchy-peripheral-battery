pragma Singleton
import QtQuick

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
        "gaming input", "gamepad", "pen", "other"
    ]

    // Section-header words `upower -i` can emit (path B parses these). Superset of
    // `known` plus power-supply / non-peripheral types we recognize only so the
    // parser can identify and then filter them out.
    readonly property var parseHeaders: [
        "battery", "ups", "tablet", "phone", "touchpad", "speakers"
    ].concat(known)

    function glyph(type) {
        switch (type) {
        case "mouse":        return String.fromCodePoint(0xF037D); // nf-md-mouse
        case "keyboard":     return String.fromCodePoint(0xF030C); // nf-md-keyboard
        case "headset":
        case "headphones":   return String.fromCodePoint(0xF02CB); // nf-md-headphones
        case "gamepad":
        case "gaming input": return String.fromCodePoint(0xF0296); // nf-md-gamepad
        case "pen":          return String.fromCodePoint(0xF03EA); // nf-md-pen
        default:             return String.fromCodePoint(0xF0079); // nf-md-battery
        }
    }

    // charging indicator: nf-md-lightning_bolt
    readonly property string bolt: String.fromCodePoint(0xF140B)

    // fixed bar summary icon: battery + wireless device (nf-md-battery_bluetooth)
    readonly property string summary: String.fromCodePoint(0xF0948)
}
