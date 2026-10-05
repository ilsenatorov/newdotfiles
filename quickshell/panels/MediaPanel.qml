import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Mpris
import ".."
import "../services"
import "../ui"

// Now playing: cover, track, scrubber, transport, the player's own volume and
// synced lyrics (services/Lyrics.qml, fetched only while this is open).
// Hosted both as the bar dropdown (click the media pill) and as a SUPER+D
// page (s), like AudioPanel.
//
// Keys: Space play/pause, ←/→ seek 5s, ↑/↓ app volume, n/p next/previous,
// Tab switch player. Esc falls through to shell.qml.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: Math.round(10 * Theme.s)
    focus: true

    readonly property var player: Media.player
    readonly property color hue: Media.artAccent

    Component.onCompleted: {
        root.forceActiveFocus();
        Lyrics.wanted = true;
    }
    Component.onDestruction: Lyrics.wanted = false

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Space) Media.toggle();
        else if (k === Qt.Key_Left) Media.seekBy(-5);
        else if (k === Qt.Key_Right) Media.seekBy(5);
        else if (k === Qt.Key_Up) Media.nudgeVolume(0.05);
        else if (k === Qt.Key_Down) Media.nudgeVolume(-0.05);
        else if (k === Qt.Key_N) Media.next();
        else if (k === Qt.Key_P) Media.previous();
        else if (k === Qt.Key_Tab) Media.cyclePlayer(1);
        else if (k === Qt.Key_Backtab) Media.cyclePlayer(-1);
        else return;
        event.accepted = true;
    }

    Text {
        visible: !Media.present
        text: "Nothing playing"
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
    }

    // ---- player chips (only with more than one) ---------------------------
    Row {
        visible: Media.players.length > 1
        spacing: Math.round(6 * Theme.s)

        Repeater {
            model: Media.players

            Rectangle {
                required property var modelData
                readonly property bool current: modelData === Media.player
                width: chip.implicitWidth + Math.round(16 * Theme.s)
                height: Math.round(24 * Theme.s)
                radius: Math.round(8 * Theme.s)
                color: current ? Colors.surface : "transparent"
                border.width: 1
                border.color: current ? root.hue : Theme.rule

                Text {
                    id: chip
                    anchors.centerIn: parent
                    text: parent.modelData.identity || "Player"
                    color: parent.current ? root.hue : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel - Math.round(2 * Theme.s)
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Media.pinned = parent.modelData
                }
            }
        }
    }

    // ---- cover + track ----------------------------------------------------
    Row {
        visible: Media.present
        width: parent.width
        spacing: Math.round(12 * Theme.s)

        ClippingRectangle {
            width: Theme.mediaArt
            height: Theme.mediaArt
            radius: Theme.radius * 0.75
            color: Theme.track

            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: Media.spotify ? "󰓇" : "󰝚"
                color: root.hue
                font.family: Theme.font
                font.pixelSize: Math.round(Theme.mediaArt * 0.4)
            }

            Image {
                id: art
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: Theme.mediaArt * 2
                sourceSize.height: Theme.mediaArt * 2
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.durFade } }
            }
        }

        Column {
            width: parent.width - Theme.mediaArt - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(3 * Theme.s)

            Text {
                width: parent.width
                text: Media.title
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: Media.artist
                color: root.hue
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: Media.album
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel - 1
                elide: Text.ElideRight
            }
        }
    }

    // ---- scrubber -----------------------------------------------------------
    Column {
        visible: Media.present && Media.length > 0
        width: parent.width
        spacing: Math.round(2 * Theme.s)

        Slider {
            width: parent.width
            value: Media.length > 0 ? Media.position / Media.length : 0
            fill: root.hue
            enabled_: root.player !== null && root.player.canSeek
            onMoved: v => Media.seekTo(v * Media.length)
        }

        Item {
            width: parent.width
            height: elapsed.implicitHeight

            Text {
                id: elapsed
                text: Media.formatTime(Media.position)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel - Math.round(2 * Theme.s)
            }
            Text {
                anchors.right: parent.right
                text: Media.formatTime(Media.length)
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel - Math.round(2 * Theme.s)
            }
        }
    }

    // ---- transport ----------------------------------------------------------
    Item {
        visible: Media.present
        width: parent.width
        height: Math.round(44 * Theme.s)

        component Btn: Rectangle {
            id: btn
            property string glyph: ""
            property bool on: true
            property bool primary: false
            signal pressed_
            width: primary ? Math.round(44 * Theme.s) : Math.round(34 * Theme.s)
            height: width
            radius: width / 2
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            color: primary ? root.hue : (btnArea.containsMouse ? Colors.surface : "transparent")
            opacity: btn.enabled ? 1 : 0.35

            Text {
                anchors.centerIn: parent
                text: btn.glyph
                color: btn.primary ? Theme.windowSurface : (btn.on ? root.hue : Theme.dim)
                font.family: Theme.font
                font.pixelSize: btn.primary ? Math.round(22 * Theme.s) : Math.round(18 * Theme.s)
            }

            MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: btn.pressed_()
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Math.round(10 * Theme.s)

            Btn {
                visible: root.player !== null && root.player.shuffleSupported
                glyph: root.player && root.player.shuffle ? "󰒝" : "󰒞"
                on: root.player !== null && root.player.shuffle
                onPressed_: root.player.shuffle = !root.player.shuffle
            }
            Btn {
                glyph: "󰒮"
                enabled: root.player !== null && root.player.canGoPrevious
                onPressed_: Media.previous()
            }
            Btn {
                primary: true
                glyph: Media.active ? "󰏤" : "󰐊"
                onPressed_: Media.toggle()
            }
            Btn {
                glyph: "󰒭"
                enabled: root.player !== null && root.player.canGoNext
                onPressed_: Media.next()
            }
            Btn {
                visible: root.player !== null && root.player.loopSupported
                readonly property int loop: root.player ? root.player.loopState : MprisLoopState.None
                glyph: loop === MprisLoopState.Track ? "󰑘" : (loop === MprisLoopState.Playlist ? "󰑖" : "󰑗")
                on: loop !== MprisLoopState.None
                onPressed_: root.player.loopState = loop === MprisLoopState.None ? MprisLoopState.Playlist
                    : (loop === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
            }
        }
    }

    // ---- app volume -----------------------------------------------------------
    Row {
        visible: Media.present && Media.volumeAvailable
        width: parent.width
        spacing: Math.round(8 * Theme.s)

        Text {
            text: Media.volume === 0 ? "󰝟" : "󰕾"
            color: root.hue
            font.family: Theme.font
            font.pixelSize: Theme.fsValue
            anchors.verticalCenter: parent.verticalCenter
        }
        Slider {
            width: parent.width - Math.round(70 * Theme.s)
            anchors.verticalCenter: parent.verticalCenter
            value: Media.volume
            fill: root.hue
            knob: false
            onMoved: v => Media.setVolume(v)
        }
        Text {
            text: Math.round(Media.volume * 100) + "%"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ---- lyrics -----------------------------------------------------------------
    Rectangle {
        visible: Media.present
        width: parent.width
        height: 1
        color: Theme.rule
    }

    Column {
        visible: Media.present
        width: parent.width
        spacing: Math.round(4 * Theme.s)

        Text {
            visible: Lyrics.state !== "ok"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Lyrics.state === "loading" ? "Looking for lyrics…" : "No lyrics"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
        }

        // Synced: the previous, current and next line, current highlighted.
        // Unsynced: the first few lines, all dim -- better than nothing.
        Repeater {
            model: {
                if (Lyrics.state !== "ok") return [];
                const L = Lyrics.lines;
                if (!Lyrics.synced) return L.filter(l => l.text !== "").slice(0, 3).map(l => ({ text: l.text, cur: false }));
                const i = Lyrics.index;
                const out = [];
                for (let j = i - 1; j <= i + 1; j++)
                    out.push({ text: j >= 0 && j < L.length ? (L[j].text || "♪") : "", cur: j === i });
                return out;
            }

            Text {
                required property var modelData
                width: root.width
                horizontalAlignment: Text.AlignHCenter
                text: modelData.text
                color: modelData.cur ? root.hue : Theme.dim
                font.family: Theme.font
                font.pixelSize: modelData.cur ? Theme.fsValue : Theme.fsLabel - 1
                font.bold: modelData.cur
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    Text {
        visible: Media.present
        width: parent.width
        text: "space play · ←→ seek · ↑↓ volume · n/p skip" + (Media.players.length > 1 ? " · tab player" : "")
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel - 1
        wrapMode: Text.Wrap
    }
}
