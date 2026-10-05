import QtQuick
import ".."
import "../ui"
import "../services"

// SUPER+D, i: quick-question overlay. Purely a view: all state and process
// management live in AskService (services/AskService.qml) as a singleton, so
// an in-flight question or a background conversation survives this Item
// being destroyed when the overlay closes (shell.qml's Loader tears it down
// on every close -- a fresh instance is created on every open).
//
// Every fresh open starts a brand-new, blank conversation (AskService's
// startNewConversation, called from shell.qml before this loads). Closing
// doesn't end it: it's a real pi session plus our own transcript file, both
// still there when you come back. Tab/Shift+Tab cycle through past
// conversations (most recent first) so you can pick one up and keep typing
// into it.
Item {
    id: root

    implicitWidth: Theme.askW
    implicitHeight: Theme.askH

    signal closeRequested()

    // Message text: read-only but mouse-selectable, so commands in an answer
    // can be selected and Ctrl+C'd. Clicking takes focus from the input;
    // click the input again to keep typing.
    component Body: TextEdit {
        readOnly: true
        selectByMouse: true
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText
        color: Theme.fg
        selectionColor: Colors.accent
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
    }

    // TextInput's own `focus: true` isn't enough to win active focus when
    // it's created by a Loader (shell.qml's askLoader) -- the FocusScope
    // above it may already have settled its focus chain before this item
    // exists, so give it an explicit kick once it's actually on screen.
    Component.onCompleted: input.forceActiveFocus()

    Surface {
        anchors.fill: parent
    }

    // Anchors rather than Column below: the transcript needs to fill
    // whatever space the header/input/status rows leave, not just take its
    // implicit size.
    Item {
        id: col
        anchors.fill: parent
        anchors.margins: Theme.pad

        Text {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            text: "Ask"
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            font.bold: true
            color: Theme.fg
        }

        Text {
            id: sessionLabel
            anchors.top: parent.top
            anchors.right: parent.right
            text: AskService.currentIndex === -1
                ? "New conversation" + (AskService.sessionList.length > 0 ? "  ·  Tab for history" : "")
                : "Conversation " + (AskService.currentIndex + 1) + "/" + AskService.sessionList.length + "  ·  Tab/Shift+Tab"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
        }

        Rectangle {
            id: inputBox
            anchors.top: header.bottom
            anchors.topMargin: Math.round(10 * Theme.s)
            anchors.left: parent.left
            anchors.right: parent.right
            height: input.implicitHeight + Math.round(16 * Theme.s)
            radius: Theme.radius / 2
            color: Theme.surface
            border.width: 1
            border.color: input.activeFocus ? Colors.accent : Theme.rule

            Text {
                visible: input.text === ""
                text: "Ask a quick question…"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
                anchors.left: parent.left
                anchors.leftMargin: Math.round(10 * Theme.s)
                anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
                id: input
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Math.round(10 * Theme.s)
                anchors.rightMargin: Math.round(10 * Theme.s)
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font
                font.pixelSize: Theme.fsValue
                color: Theme.fg
                clip: true
                focus: true
                enabled: !AskService.running

                // Enter asks. Ctrl+Enter hands this conversation off to a
                // full terminal. Tab/Shift+Tab browse past conversations --
                // handled here (not left to Qt's default focus-on-Tab) since
                // there's nowhere else in this popup for focus to go anyway.
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (event.modifiers & Qt.ControlModifier) {
                            AskService.openInTerminal(AskService.currentSessionId);
                            root.closeRequested();
                        } else {
                            AskService.ask(input.text);
                            input.text = "";
                        }
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier)) {
                        AskService.switchTo(AskService.currentIndex + 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                        AskService.switchTo(AskService.currentIndex - 1);
                        event.accepted = true;
                    }
                }
            }
        }

        Text {
            id: status
            anchors.top: inputBox.bottom
            anchors.topMargin: ((AskService.running && AskService.partialAnswer === "") || AskService.error !== "") ? 10 : 0
            anchors.left: parent.left
            anchors.right: parent.right
            height: ((AskService.running && AskService.partialAnswer === "") || AskService.error !== "") ? implicitHeight : 0
            clip: true
            visible: (AskService.running && AskService.partialAnswer === "") || AskService.error !== ""
            text: AskService.error !== "" ? AskService.error
                : (AskService._askCtx && AskService._askCtx.sid !== AskService.currentSessionId ? "Thinking… (another conversation)" : "Thinking…")
            color: AskService.error !== "" ? Theme.red : Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            wrapMode: Text.Wrap
        }

        Flickable {
            id: convoScroll
            anchors.top: status.bottom
            anchors.topMargin: Math.round(10 * Theme.s)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            contentHeight: convoCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            // Mouse drag selects text instead of flicking; wheel still scrolls.
            acceptedButtons: Qt.NoButton

            onContentHeightChanged: convoScroll.contentY = Math.max(0, contentHeight - height)

            Column {
                id: convoCol
                width: convoScroll.width
                spacing: Math.round(14 * Theme.s)

                Text {
                    visible: AskService.messages.length === 0 && AskService.partialAnswer === ""
                    width: convoCol.width
                    text: "Nothing here yet -- ask away."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fsValue
                }

                Repeater {
                    model: AskService.messages

                    Column {
                        required property var modelData
                        width: convoCol.width
                        spacing: Math.round(2 * Theme.s)

                        Text {
                            text: modelData.role === "you" ? "You" : "Ask"
                            font.family: Theme.font
                            font.pixelSize: Theme.fsLabel
                            font.bold: true
                            color: modelData.role === "you" ? Colors.accent : Theme.dim
                        }

                        Body {
                            width: convoCol.width
                            text: modelData.text
                        }
                    }
                }

                Column {
                    visible: AskService.partialAnswer !== ""
                    width: convoCol.width
                    spacing: Math.round(2 * Theme.s)

                    Text {
                        text: "Ask"
                        font.family: Theme.font
                        font.pixelSize: Theme.fsLabel
                        font.bold: true
                        color: Theme.dim
                    }

                    Body {
                        width: convoCol.width
                        text: AskService.partialAnswer
                    }
                }
            }
        }
    }
}
