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
Item {
    id: root

    property string layout: ""
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
            ["b l d w z ' f o u j ; = \\", "B L D W Z _ F O U J : + |"],
            ["n r t s g y h a e i ,", "N R T S G Y H A E I ?"],
            ["q x m c v k p . - /", "Q X M C V K P > \" <"],
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

    implicitWidth: board.implicitWidth + Theme.pad * 2
    implicitHeight: board.implicitHeight + Theme.pad * 2

    Process {
        id: devicesProc
        command: ["hyprctl", "-j", "devices"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const kb = kbs.filter(k => k.main === true)[0] ?? kbs[0];
                    if (kb) root.layout = kb.active_keymap;
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
            root.layout = parts[parts.length - 1] ?? "";
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Qt.alpha(Colors.baseBg, 0.45)
        border.color: Qt.alpha(Theme.rule, 0.6)
    }

    Column {
        id: board
        anchors.centerIn: parent
        spacing: root.gap

        Text {
            text: root.layout || root.mapName
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            color: Theme.dim
        }

        Repeater {
            model: root.maps[root.mapName]

            Row {
                id: keyRow
                required property var modelData
                required property int index
                readonly property var base: modelData[0].split(" ")
                readonly property var shifted: modelData[1].split(" ")

                spacing: root.gap
                leftPadding: root.stagger[index] * (root.unit + root.gap)

                Repeater {
                    model: keyRow.base

                    Rectangle {
                        id: key
                        required property string modelData
                        required property int index
                        readonly property string shift: keyRow.shifted[index] ?? ""
                        readonly property bool held: root.down.includes(root.codes[keyRow.index][index])

                        width: root.unit
                        height: root.unit
                        radius: Math.round(6 * Theme.s)
                        // Home row tinted so your fingers' anchor is easy to find.
                        color: held ? Colors.accent
                            : keyRow.index === 2 ? Qt.alpha(Colors.accentDim, 0.45)
                            : Qt.alpha(Theme.rule, 0.35)
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.centerIn: parent
                            text: key.modelData
                            font.family: Theme.font
                            font.pixelSize: Math.round(20 * Theme.s)
                            font.bold: true
                            color: key.held ? Colors.baseBg : Colors.accent
                        }
                        Text {
                            visible: key.shift !== key.modelData.toUpperCase()
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: Math.round(3 * Theme.s)
                            text: key.shift
                            font.family: Theme.font
                            font.pixelSize: Math.round(11 * Theme.s)
                            color: Theme.dim
                        }
                    }
                }
            }
        }
    }
}
