pragma Singleton

import QtQuick
import Quickshell

// Minute precision is deliberate: nothing on the card shows seconds, so there is
// no reason to wake once a second. The colon's 1Hz pulse is a QML animation and
// runs independently of this.
//
// Not SystemClock: on the DST fall-back (2026-10-25 02:00-03:00) its Minutes
// precision computed a negative wait and spun at 1ms for the whole repeated
// hour. Epoch ms never goes backwards, so this wait is never negative.
Singleton {
    id: root
    property date now: new Date()
    readonly property string hh: Qt.formatDateTime(now, "HH")
    readonly property string mm: Qt.formatDateTime(now, "mm")
    readonly property string hhmm: hh + ":" + mm
    readonly property string dateLine: Qt.formatDateTime(now, "dddd '·' dd MMM yyyy").toUpperCase()

    // Until just past the next minute boundary (+50ms, never just before it),
    // capped at 10s: QTimer runs on the monotonic clock, which stops during
    // suspend, so an uncapped wait would show a stale minute after resume.
    function wait(): int {
        return Math.min(10000, 60000 - Date.now() % 60000 + 50);
    }

    Timer {
        id: tick
        running: true
        interval: root.wait()
        onTriggered: {
            const d = new Date();
            // only on a new minute, so bindings on `now` don't churn every 10s
            if (Math.floor(d.getTime() / 60000) !== Math.floor(root.now.getTime() / 60000))
                root.now = d;
            tick.interval = root.wait();
            tick.start();
        }
    }
}
