pragma Singleton
import QtQuick

// UI strings. `language` is "auto" (follow the system locale) or one of the
// keys below; anything missing falls back to English. Add a language by
// adding a table — every key in `en` is used somewhere.
QtObject {
    id: root

    property string language: "auto"

    readonly property var available: ["auto", "en", "pt", "es", "fr", "de"]
    readonly property string resolved: {
        var lang = language === "auto" ? Qt.locale().name.split("_")[0] : language;
        return tables[lang] ? lang : "en";
    }

    readonly property var tables: ({
        en: {
            title: "Peripherals",
            devices: "%1 devices", device: "1 device",
            lowest: "lowest %1", charging: "%1 charging", allCharged: "all charged",
            none: "No peripherals reporting battery",
            styleList: "List", styleGauge: "Rings",
            renameHint: "Click a name to rename it",
            renameEditing: "Enter saves · Esc cancels · empty restores",
            renameTooltip: "Rename",
            state_charging: "Charging", "state_fully-charged": "Fully charged",
            state_discharging: "Discharging", state_empty: "Empty", state_unknown: "Connected",
            type_mouse: "Mice", type_keyboard: "Keyboards", type_headset: "Headsets",
            type_headphones: "Headphones", type_gamepad: "Controllers", type_pen: "Pens", type_other: "Other",
            lowTitle: "Low battery", criticalTitle: "Critical battery"
        },
        pt: {
            title: "Periféricos",
            devices: "%1 dispositivos", device: "1 dispositivo",
            lowest: "menor %1", charging: "%1 carregando", allCharged: "tudo carregado",
            none: "Nenhum periférico informando bateria",
            styleList: "Lista", styleGauge: "Anéis",
            renameHint: "Clique no nome para renomear",
            renameEditing: "Enter salva · Esc cancela · vazio restaura",
            renameTooltip: "Renomear",
            state_charging: "Carregando", "state_fully-charged": "Carga completa",
            state_discharging: "Descarregando", state_empty: "Sem bateria", state_unknown: "Conectado",
            type_mouse: "Mouses", type_keyboard: "Teclados", type_headset: "Headsets",
            type_headphones: "Fones", type_gamepad: "Controles", type_pen: "Canetas", type_other: "Outros",
            lowTitle: "Bateria baixa", criticalTitle: "Bateria crítica"
        },
        es: {
            title: "Periféricos",
            devices: "%1 dispositivos", device: "1 dispositivo",
            lowest: "mínimo %1", charging: "%1 cargando", allCharged: "todo cargado",
            none: "Ningún periférico informa batería",
            styleList: "Lista", styleGauge: "Anillos",
            renameHint: "Haz clic en un nombre para renombrarlo",
            renameEditing: "Enter guarda · Esc cancela · vacío restaura",
            renameTooltip: "Renombrar",
            state_charging: "Cargando", "state_fully-charged": "Carga completa",
            state_discharging: "Descargando", state_empty: "Sin batería", state_unknown: "Conectado",
            type_mouse: "Ratones", type_keyboard: "Teclados", type_headset: "Auriculares con micro",
            type_headphones: "Auriculares", type_gamepad: "Mandos", type_pen: "Lápices", type_other: "Otros",
            lowTitle: "Batería baja", criticalTitle: "Batería crítica"
        },
        fr: {
            title: "Périphériques",
            devices: "%1 appareils", device: "1 appareil",
            lowest: "min. %1", charging: "%1 en charge", allCharged: "tout est chargé",
            none: "Aucun périphérique ne signale de batterie",
            styleList: "Liste", styleGauge: "Anneaux",
            renameHint: "Cliquez sur un nom pour le renommer",
            renameEditing: "Entrée valide · Échap annule · vide restaure",
            renameTooltip: "Renommer",
            state_charging: "En charge", "state_fully-charged": "Chargé",
            state_discharging: "Sur batterie", state_empty: "Vide", state_unknown: "Connecté",
            type_mouse: "Souris", type_keyboard: "Claviers", type_headset: "Casques-micro",
            type_headphones: "Casques", type_gamepad: "Manettes", type_pen: "Stylets", type_other: "Autres",
            lowTitle: "Batterie faible", criticalTitle: "Batterie critique"
        },
        de: {
            title: "Peripheriegeräte",
            devices: "%1 Geräte", device: "1 Gerät",
            lowest: "niedrigster %1", charging: "%1 lädt", allCharged: "alles geladen",
            none: "Keine Geräte melden einen Akkustand",
            styleList: "Liste", styleGauge: "Ringe",
            renameHint: "Zum Umbenennen auf einen Namen klicken",
            renameEditing: "Enter speichert · Esc bricht ab · leer setzt zurück",
            renameTooltip: "Umbenennen",
            state_charging: "Lädt", "state_fully-charged": "Voll geladen",
            state_discharging: "Entlädt", state_empty: "Leer", state_unknown: "Verbunden",
            type_mouse: "Mäuse", type_keyboard: "Tastaturen", type_headset: "Headsets",
            type_headphones: "Kopfhörer", type_gamepad: "Controller", type_pen: "Stifte", type_other: "Andere",
            lowTitle: "Akku schwach", criticalTitle: "Akku kritisch"
        }
    })

    function t(key, arg) {
        var table = tables[resolved];
        var s = table[key] !== undefined ? table[key] : (tables.en[key] !== undefined ? tables.en[key] : key);
        return arg !== undefined ? s.replace("%1", arg) : s;
    }

    function stateLabel(state) { return t("state_" + (tables.en["state_" + state] ? state : "unknown")); }
    function typeLabel(type) { return t("type_" + (tables.en["type_" + type] ? type : "other")); }
}
