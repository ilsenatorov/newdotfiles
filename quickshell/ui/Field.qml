import QtQuick
import ".."

// Text input for the panel forms and filters: placeholder, optional secret
// with a show/hide eye, Tab / Shift+Tab to the neighbouring fields.
Rectangle {
    id: field

    property alias input: textInput
    property string placeholder: ""
    property bool secret: false
    property bool revealed: false
    // Tab / Shift+Tab targets -- the neighbouring fields in the form.
    property Item next: null
    property Item prev: null
    signal accepted

    width: parent.width
    height: Math.round(32 * Theme.s)
    radius: Math.round(6 * Theme.s)
    color: Theme.surface
    border.width: 1
    border.color: textInput.activeFocus ? Colors.accent : Theme.rule

    TextInput {
        id: textInput
        anchors.fill: parent
        anchors.leftMargin: Math.round(8 * Theme.s)
        anchors.rightMargin: field.secret ? eye.width + Math.round(16 * Theme.s) : Math.round(8 * Theme.s)
        verticalAlignment: TextInput.AlignVCenter
        echoMode: field.secret && !field.revealed ? TextInput.Password : TextInput.Normal
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
        clip: true
        KeyNavigation.tab: field.next
        KeyNavigation.backtab: field.prev
        onAccepted: field.accepted()
    }

    Text {
        anchors.fill: textInput
        verticalAlignment: Text.AlignVCenter
        visible: textInput.text === ""
        text: field.placeholder
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel
        elide: Text.ElideRight
    }

    Text {
        id: eye
        visible: field.secret
        anchors.right: parent.right
        anchors.rightMargin: Math.round(8 * Theme.s)
        anchors.verticalCenter: parent.verticalCenter
        text: field.revealed ? "󰈉" : "󰈈"
        font.family: Theme.font
        font.pixelSize: Theme.fsValue
        color: eyeArea.containsMouse ? Colors.accent : Theme.dim

        MouseArea {
            id: eyeArea
            anchors.fill: parent
            anchors.margins: Math.round(-4 * Theme.s)
            hoverEnabled: true
            onClicked: field.revealed = !field.revealed
        }
    }
}
