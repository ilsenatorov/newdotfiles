import QtQuick
import ".."

// Static "|" divider between module groups -- waybar's custom/sep, never an
// exec module, just text.
Text {
    text: "|"
    height: Theme.barHeight
    verticalAlignment: Text.AlignVCenter
    font.family: Theme.font
    font.pixelSize: Theme.fsBar
    color: Theme.rule
}
