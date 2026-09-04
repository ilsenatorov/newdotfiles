import QtQuick
import ".."
import "../services"

// Month calendar, opened by clicking the bar clock. Replaces waybar's
// tooltip-format: "<tt>{calendar}</tt>" with a real interactive popup.
Column {
    id: root
    width: parent ? parent.width : Theme.panelW
    spacing: 10

    property date viewDate: new Date(Time.now.getFullYear(), Time.now.getMonth(), 1)

    Row {
        width: parent.width

        Text {
            width: parent.width - nav.width
            text: Qt.formatDate(root.viewDate, "MMMM yyyy")
            font.family: Theme.font
            font.pixelSize: Theme.fsLabel
            font.bold: true
            color: Colors.accent
            verticalAlignment: Text.AlignVCenter
            height: nav.height
        }

        Row {
            id: nav
            spacing: 4

            Text {
                text: "‹"
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                color: Theme.fg
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() - 1, 1)
                }
            }
            Text {
                text: "›"
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel
                color: Theme.fg
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: root.viewDate = new Date(root.viewDate.getFullYear(), root.viewDate.getMonth() + 1, 1)
                }
            }
        }
    }

    Grid {
        width: parent.width
        columns: 7
        rowSpacing: 6
        columnSpacing: 0

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text {
                required property string modelData
                width: root.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: Theme.font
                font.pixelSize: Theme.fsLabel - 2
                color: Theme.dim
            }
        }

        Repeater {
            model: root.cells()
            Rectangle {
                required property var modelData
                width: root.width / 7
                height: width
                radius: width / 2
                color: modelData.today ? Colors.accent : (modelData.hover ? Colors.surface : "transparent")

                Text {
                    anchors.centerIn: parent
                    visible: parent.modelData.day > 0
                    text: parent.modelData.day
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel - 1
                    color: parent.modelData.today ? Theme.surface : Theme.fg
                }
            }
        }
    }

    // Mo-first ISO week grid for the visible month, padded with empty
    // leading cells and marked with today's date when the view is on the
    // current month.
    function cells(): var {
        const y = viewDate.getFullYear();
        const m = viewDate.getMonth();
        const first = new Date(y, m, 1);
        // getDay(): 0=Sun..6=Sat -> convert to Mo-first offset.
        const lead = (first.getDay() + 6) % 7;
        const daysInMonth = new Date(y, m + 1, 0).getDate();
        const today = Time.now;
        const isCurrentMonth = today.getFullYear() === y && today.getMonth() === m;

        const out = [];
        for (let i = 0; i < lead; i++) out.push({ day: 0, today: false, hover: false });
        for (let d = 1; d <= daysInMonth; d++)
            out.push({ day: d, today: isCurrentMonth && d === today.getDate(), hover: false });
        return out;
    }
}
