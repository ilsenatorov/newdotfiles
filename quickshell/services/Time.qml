pragma Singleton

import QtQuick
import Quickshell

// Minute precision is deliberate: nothing on the card shows seconds, so there is
// no reason to wake once a second. The colon's 1Hz pulse is a QML animation and
// runs independently of this.
Singleton {
    readonly property date now: clock.date
    readonly property string hh: Qt.formatDateTime(now, "HH")
    readonly property string mm: Qt.formatDateTime(now, "mm")
    readonly property string hhmm: hh + ":" + mm
    readonly property string dateLine: Qt.formatDateTime(now, "dddd '·' dd MMM yyyy").toUpperCase()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
