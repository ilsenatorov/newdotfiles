import QtQuick
import Quickshell
import ".."
import Quickshell.Io
import "../ui"

// SUPER+SHIFT+M. Replaces the two `rofi -dmenu` prompts that used to live
// inside hypr/scripts/monitor-place.sh ("Which display?" then a list of six
// placements). Drawn as a diagram instead of a list: where a display goes is
// a spatial question, and a column of words was the wrong shape for it.
//
// This panel computes NO geometry. It reads `monitor-place.sh --query` for
// the anchor, the candidate outputs and where each one currently sits, and
// resolves to a (placement, output) pair that it hands straight back to the
// script. All the scale/logical-size/mirror/disabled maths -- and the
// `hyprctl eval` apply, which Hyprland's Lua config parser requires instead
// of `hyprctl keyword` -- stay in the script, where --dry-run can test them.
Item {
    id: root

    signal closeRequested

    // shellPath(), not Qt.resolvedUrl() -- see panels/Wallpaper.qml.
    readonly property string script: Quickshell.shellPath("../hypr/scripts/monitor-place.sh")

    property string anchorName: ""
    property var targets: []
    property string chosen: ""
    property string error: ""
    property string sel: "Right"

    readonly property var chosenTarget: root.targets.find(t => t.name === root.chosen) ?? null
    // With more than one external display the script cannot guess, so the
    // output gets picked first -- the same two-step the rofi version had.
    readonly property bool needsTargetPick: root.chosen === "" && root.targets.length > 1

    readonly property var placements: ["Left", "Right", "Above", "Below", "Mirror", "Disable"]

    function apply(): void {
        if (root.chosen === "")
            return;
        root.closeRequested();
        Quickshell.execDetached([root.script, root.sel.toLowerCase(), root.chosen]);
    }

    Process {
        running: true
        command: [root.script, "--query"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.anchorName = d.anchor ?? "";
                    root.targets = d.targets ?? [];
                    if (root.targets.length === 0)
                        root.error = "No external display connected.";
                    else if (root.targets.length === 1)
                        root.chosen = root.targets[0].name;
                } catch (e) {
                    root.error = "Could not read the display layout.";
                }
            }
        }
    }

    // Opening on the placement the display already has means Enter is a
    // no-op rather than a surprise.
    onChosenTargetChanged: {
        if (root.chosenTarget && root.chosenTarget.current)
            root.sel = root.chosenTarget.current;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // Step one: which display. Reuses the same card every other ported menu
    // uses rather than growing a second list widget here.
    Picker {
        anchors.fill: parent
        visible: root.needsTargetPick
        placeholder: "Which display?"
        cardWidth: Theme.menuW
        items: root.targets.map(t => ({
                    label: t.name,
                    sublabel: t.description,
                    key: t.name
                }))
        onAccepted: item => root.chosen = item.key
        onCloseRequested: root.closeRequested()
    }

    // Step two: where it goes.
    Rectangle {
        id: card

        visible: !root.needsTargetPick
        anchors.centerIn: parent
        width: Theme.menuW
        height: col.implicitHeight + Theme.pad
        radius: Theme.radius
        color: Theme.dashboardSurface
        border.width: 1
        border.color: Theme.rule

        focus: card.visible
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested();
            } else if (event.key === Qt.Key_Left) {
                root.sel = "Left";
            } else if (event.key === Qt.Key_Right) {
                root.sel = "Right";
            } else if (event.key === Qt.Key_Up) {
                root.sel = "Above";
            } else if (event.key === Qt.Key_Down) {
                root.sel = "Below";
            } else if (event.key === Qt.Key_M) {
                root.sel = "Mirror";
            } else if (event.key === Qt.Key_D) {
                root.sel = "Disable";
            } else if (event.key === Qt.Key_Tab) {
                root.sel = root.placements[(root.placements.indexOf(root.sel) + 1) % root.placements.length];
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.apply();
            } else {
                return;
            }
            event.accepted = true;
        }

        Component.onCompleted: card.forceActiveFocus()

        // A tile is one placement. `current` is marked so the diagram shows
        // where the display is now, not just where it could go.
        component Tile: Rectangle {
            id: tile

            required property string placement
            property int tileW: Theme.menuTileW

            width: tile.tileW
            height: Theme.menuTileH
            radius: Theme.radius / 2
            color: root.sel === tile.placement ? Colors.surface : Theme.surface
            border.width: 1
            border.color: root.sel === tile.placement ? Colors.accent : Theme.rule

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: tile.placement
                    color: root.sel === tile.placement ? Colors.accent : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.chosenTarget && root.chosenTarget.current === tile.placement
                    text: "current"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    root.sel = tile.placement;
                    root.apply();
                }
            }
        }

        Column {
            id: col

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.pad / 2
            spacing: 8

            Text {
                text: root.error !== "" ? root.error : root.chosen + (root.chosenTarget && root.chosenTarget.description ? "  ·  " + root.chosenTarget.description : "")
                color: root.error !== "" ? Theme.red : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                font.bold: true
                elide: Text.ElideRight
                width: col.width
            }

            // The diagram: the anchor in the middle, the four directions
            // around it, exactly as they will end up on the desk.
            Grid {
                visible: root.error === ""
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 3
                spacing: 6

                Item {
                    width: Theme.menuTileW
                    height: Theme.menuTileH
                }
                Tile {
                    placement: "Above"
                }
                Item {
                    width: Theme.menuTileW
                    height: Theme.menuTileH
                }

                Tile {
                    placement: "Left"
                }
                Rectangle {
                    width: Theme.menuTileW
                    height: Theme.menuTileH
                    radius: Theme.radius / 2
                    color: Theme.barPill
                    border.width: 1
                    border.color: Theme.divider

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                        text: root.anchorName
                        elide: Text.ElideRight
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel
                    }
                }
                Tile {
                    placement: "Right"
                }

                Item {
                    width: Theme.menuTileW
                    height: Theme.menuTileH
                }
                Tile {
                    placement: "Below"
                }
                Item {
                    width: Theme.menuTileW
                    height: Theme.menuTileH
                }
            }

            Row {
                visible: root.error === ""
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Tile {
                    placement: "Mirror"
                    tileW: Theme.menuTileW * 1.5
                }
                Tile {
                    placement: "Disable"
                    tileW: Theme.menuTileW * 1.5
                }
            }

            Text {
                visible: root.error === ""
                width: col.width
                horizontalAlignment: Text.AlignHCenter
                text: "arrows place · m mirror · d disable · Enter apply"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
            }
        }
    }
}
