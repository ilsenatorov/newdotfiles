import QtQuick
import Quickshell.Io
import Quickshell.Hyprland
import ".."

// SUPER+K cheat sheet: the active layout's letter keys, drawn as a
// see-through keyboard so you can keep typing underneath it (learning
// Graphite). Follows layout switches live, same activelayout source as
// bar/modules/Language.qml. shell.qml hosts it click-through.
//
// Rows are space-separated tokens, base level then shift level; a shift
// glyph is only drawn when it isn't just the uppercase letter. Graphite
// mirrors xkb/symbols/graphite -- keep them in sync.
//
// While the TOTEM is the keyboard in use it's drawn in the TOTEM's shape
// instead. Its firmware sends qwerty keycodes, so the same rows and codes
// apply; the outer pinky keys and thumbs are labelled by hand from its base
// layer.
Item {
    id: root

    property string layout: ""
    // Hyprland's main keyboard, i.e. the one last typed on.
    property string keyboard: ""
    // SUPER+SHIFT+K pins the other shape until the shell restarts.
    property var forceTotem: null
    readonly property bool totem: forceTotem ?? /totem/i.test(keyboard)
    function flip() { forceTotem = !totem }
    // Set by shell.qml while visible; gates the keypress reader.
    property bool active: false
    // Evdev keycodes currently held, from scripts/keypress.py.
    property var down: []

    // Physical keycodes per row, so highlighting works on every layout.
    readonly property var codes: [
        [41, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
        [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 43],
        [30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40],
        [44, 45, 46, 47, 48, 49, 50, 51, 52, 53],
    ]

    readonly property var maps: ({
        us: [
            ["` 1 2 3 4 5 6 7 8 9 0 - =", "~ ! @ # $ % ^ & * ( ) _ +"],
            ["q w e r t y u i o p [ ] \\", "Q W E R T Y U I O P { } |"],
            ["a s d f g h j k l ; '", "A S D F G H J K L : \""],
            ["z x c v b n m , . /", "Z X C V B N M < > ?"],
        ],
        graphite: [
            ["` 1 2 3 4 5 6 7 8 9 0 [ ]", "~ ! @ # $ % ^ & * ( ) { }"],
            ["b l d w z - f o u j ; = \\", "B L D W Z _ F O U J : + |"],
            ["n r t s g y h a e i '", "N R T S G Y H A E I \""],
            ["x m c v q k p , . /", "X M C V Q K P < > ?"],
        ],
        ru: [
            ["ё 1 2 3 4 5 6 7 8 9 0 - =", "Ё ! \" № ; % : ? * ( ) _ +"],
            ["й ц у к е н г ш щ з х ъ \\", "Й Ц У К Е Н Г Ш Щ З Х Ъ /"],
            ["ф ы в а п р о л д ж э", "Ф Ы В А П Р О Л Д Ж Э"],
            ["я ч с м и т ь б ю .", "Я Ч С М И Т Ь Б Ю ,"],
        ],
    })
    readonly property string mapName: /graphite/i.test(layout) ? "graphite"
        : /russian/i.test(layout) ? "ru" : "us"
    // Tab / Caps / Shift widths, in keys, before each row starts.
    readonly property var stagger: [0, 1.5, 1.75, 2.25]

    readonly property int unit: Math.round(46 * Theme.s)
    readonly property int gap: Math.round(5 * Theme.s)
    readonly property int step: unit + gap

    // TOTEM column stagger (in keys, down from the middle finger), outer
    // pinky to inner index on the left, mirrored on the right.
    readonly property var totemStagger: [0.5, 0.15, 0, 0.15, 0.3]
    // Thumbs left to right: label, evdev keycode, column, drop.
    readonly property var totemThumbs: [
        ["esc", 1, 3, 3.3], ["spc", 57, 4, 3.4], ["ret", 28, 5, 3.6],
        ["bsp", 14, 7.5, 3.6], ["tab", 15, 8.5, 3.4], ["del", 111, 9.5, 3.3],
    ]

    // Every drawn key: position in key units, legends, evdev code, home row.
    readonly property var keys: {
        const rows = maps[mapName].map(r => [r[0].split(" "), r[1].split(" ")]);
        const key = (x, y, row, i) => ({
            x, y, base: rows[row][0][i], shift: rows[row][1][i] ?? "",
            code: codes[row][i], home: row === 2 && i < 10,
        });
        const out = [];
        if (!totem) {
            rows.forEach((r, row) => r[0].forEach((_, i) => out.push(key(stagger[row] + i, row, row, i))));
            return out;
        }
        // Rows 1-3 are the 3x5 halves; column 0 is the outer pinky key.
        for (let row = 1; row <= 3; row++)
            for (let i = 0; i < 10; i++)
                out.push(key(i < 5 ? i + 1 : i + 2.5, row - 1 + totemStagger[i < 5 ? i : 9 - i], row, i));
        out.push({ x: 0, y: 2.5, base: "fn", shift: "", code: -1, home: false });
        out.push({ x: 12.5, y: 2.5, base: "adj", shift: "", code: -1, home: false });
        for (const [label, code, x, y] of totemThumbs)
            out.push({ x, y, base: label, shift: "", code, home: false });
        return out;
    }

    implicitWidth: board.implicitWidth + Theme.pad * 2
    implicitHeight: board.implicitHeight + Theme.pad * 2

    // Main keyboard can change while hidden; re-read it on every show.
    onActiveChanged: if (active) devicesProc.running = true

    Process {
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const kb = kbs.filter(k => k.main === true)[0] ?? kbs[0];
                    if (kb) {
                        root.layout = kb.active_keymap;
                        root.keyboard = kb.name;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        running: root.active
        command: ["python3", Qt.resolvedUrl("../scripts/keypress.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: line => {
                const [code, value] = line.split(" ").map(Number);
                const rest = root.down.filter(c => c !== code);
                root.down = value ? rest.concat(code) : rest;
            }
        }
        onRunningChanged: if (!running) root.down = []
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            const parts = event.data.split(",");
            root.keyboard = parts[0];
            root.layout = parts[parts.length - 1] ?? "";
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Qt.alpha(Colors.baseBg, 0.45)
        border.color: Qt.alpha(Theme.rule, 0.6)
    }

    Item {
        id: board
        anchors.centerIn: parent
        implicitWidth: Math.max(...root.keys.map(k => k.x)) * root.step + root.unit
        implicitHeight: title.height + root.gap + Math.max(...root.keys.map(k => k.y)) * root.step + root.unit

        Text {
            id: title
            text: root.layout || root.mapName
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            color: Theme.dim
        }

        Repeater {
            model: root.keys

            Rectangle {
                id: key
                required property var modelData
                readonly property bool held: root.down.includes(modelData.code)
                readonly property bool word: modelData.base.length > 1

                x: Math.round(modelData.x * root.step)
                y: title.height + root.gap + Math.round(modelData.y * root.step)
                width: root.unit
                height: root.unit
                radius: Math.round(6 * Theme.s)
                // Home row tinted so your fingers' anchor is easy to find.
                color: held ? Colors.accent
                    : modelData.home ? Qt.alpha(Colors.accentDim, 0.45)
                    : Qt.alpha(Theme.rule, 0.35)
                Behavior on color { ColorAnimation { duration: 80 } }

                Text {
                    anchors.centerIn: parent
                    text: key.modelData.base
                    font.family: Theme.font
                    font.pixelSize: Math.round((key.word ? 13 : 20) * Theme.s)
                    font.bold: true
                    color: key.held ? Colors.baseBg : key.word ? Theme.dim : Colors.accent
                }
                Text {
                    visible: key.modelData.shift !== key.modelData.base.toUpperCase()
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: Math.round(3 * Theme.s)
                    text: key.modelData.shift
                    font.family: Theme.font
                    font.pixelSize: Math.round(11 * Theme.s)
                    color: Theme.dim
                }
            }
        }
    }
}
