pragma Singleton
import QtQuick

// type -> glyph. Register in a qmldir if the host needs it for the singleton import.
QtObject {
    // Nerd Font (Material Design) glyphs. Needs a Nerd-Font-patched family at the
    // bar for these to render.
    function glyph(type) {
        switch (type) {
        case "mouse":        return "D";  // nf-md-mouse
        case "keyboard":     return "C";  // nf-md-keyboard
        case "headset":
        case "headphones":   return "B";  // nf-md-headphones
        case "gamepad":
        case "gaming input": return "6";  // nf-md-gamepad
        case "pen":          return "A";  // nf-md-pen
        default:             return "9";  // nf-md-battery
        }
    }

    // charging indicator: nf-md-lightning_bolt
    readonly property string bolt: "󱐋"
}
