import QtQuick
import Quickshell.Widgets
import "../.."
import "../../services"

// Scaled-down picture of one workspace's window layout. Geometry comes from
// each toplevel's lastIpcObject (hyprctl clients: `at`/`size` in layout
// coordinates), which Quickshell only fills in on Hyprland.refreshToplevels()
// -- Workspaces.qml triggers that. A Hyprland group is one cell with a tab
// strip on top, like the group bar. Each cell is coloured and labelled per
// app from services/AppStyle.qml.
//
// Two sizes: the compact one sits in the bar pill under the number (size
// it with implicitHeight; width follows the monitor's aspect), `detailed`
// is the hover preview's big map with app icons and window titles.
Item {
    id: root

    required property var workspace
    property bool active: true
    property bool detailed: false
    // Hovered in the bar: lights the outline like the active workspace's.
    property bool highlighted: false

    // Monitor area minus reserved edges (the bar), in layout coordinates.
    readonly property var area: {
        const m = workspace ? workspace.monitor : null;
        if (!m) return null;
        const info = m.lastIpcObject || {};
        const rotated = (info.transform ?? 0) % 2 === 1;
        const r = info.reserved || [0, 0, 0, 0];
        const w = (rotated ? m.height : m.width) / m.scale;
        const h = (rotated ? m.width : m.height) / m.scale;
        return { x: m.x + r[0], y: m.y + r[1], w: w - r[0] - r[2], h: h - r[1] - r[3] };
    }

    // One cell per window, or per group. Position/size are fractions of
    // `area`; floating cells sort last so they draw on top of the tiling.
    readonly property var cells: {
        const a = area;
        if (!a || a.w <= 0 || a.h <= 0) return [];
        const clamp = v => Math.max(0, Math.min(1, v));
        const byKey = {};
        const out = [];
        for (const t of workspace.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.at || !o.size || o.hidden) continue;
            const group = o.grouped && o.grouped.length > 1 ? o.grouped : null;
            const key = group ? group.join() : o.address;
            let c = byKey[key];
            if (!c) {
                const full = o.fullscreen > 0;
                const x = full ? 0 : clamp((o.at[0] - a.x) / a.w);
                const y = full ? 0 : clamp((o.at[1] - a.y) / a.h);
                c = byKey[key] = {
                    x: x, y: y,
                    w: full ? 1 : clamp((o.at[0] + o.size[0] - a.x) / a.w) - x,
                    h: full ? 1 : clamp((o.at[1] + o.size[1] - a.y) / a.h) - y,
                    floating: !!o.floating && !full,
                    // Group order, so the tab strip matches Hyprland's.
                    members: group ? group.map(() => null) : [null],
                    // The visible group member is the most recently focused one.
                    shown: 0, shownHistory: Infinity,
                    focused: false, urgent: false,
                };
                out.push(c);
            }
            const slot = group ? Math.max(0, group.indexOf(o.address)) : 0;
            c.members[slot] = { cls: o.class || "", title: o.title || "" };
            if (o.focusHistoryID < c.shownHistory) {
                c.shownHistory = o.focusHistoryID;
                c.shown = slot;
            }
            c.focused = c.focused || t.activated;
            c.urgent = c.urgent || t.urgent;
        }
        for (const c of out)
            c.members = c.members.map(m => m || { cls: "", title: "" });
        return out.sort((p, q) => p.floating - q.floating);
    }

    readonly property int pad: detailed ? 6 : 2
    readonly property int gap: detailed ? 5 : 1

    implicitHeight: Math.round((Theme.barHeight - Math.round(8 * Theme.s)) * 0.52)
    implicitWidth: area ? Math.round(implicitHeight * area.w / area.h) : implicitHeight
    opacity: active || highlighted || detailed ? 1 : 0.75

    function tint(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // Screen outline. In the bar it is also lit like the number: urgent
    // red, active/hovered accent.
    Rectangle {
        readonly property bool lit: !root.detailed && (root.active || root.highlighted)
        readonly property bool urgent: !root.detailed && root.workspace && root.workspace.urgent
        anchors.fill: parent
        radius: root.detailed ? 9 : 3
        color: root.detailed ? Qt.rgba(0, 0, 0, 0.18) : "transparent"
        border.width: 1
        border.color: urgent ? Theme.red : lit ? Colors.accent : Theme.rule
        opacity: lit && !urgent ? 0.7 : 1
    }

    Text {
        anchors.centerIn: parent
        visible: root.detailed && root.cells.length === 0
        text: "empty"
        font.family: Theme.font
        font.pixelSize: Theme.fsLabel - Math.round(2 * Theme.s)
        color: Theme.dim
    }

    Repeater {
        model: root.cells

        Item {
            id: cell
            required property var modelData

            readonly property var app: modelData.members[modelData.shown]
            readonly property var style: AppStyle.style(app.cls)
            readonly property color appColor: modelData.urgent ? Theme.red : style.color
            readonly property bool grouped: modelData.members.length > 1

            readonly property real iw: root.width - 2 * root.pad
            readonly property real ih: root.height - 2 * root.pad
            // Snap both edges to whole pixels, then give up `gap` so
            // neighbours stay visibly apart at this scale.
            readonly property int x0: Math.round(root.pad + modelData.x * iw)
            readonly property int y0: Math.round(root.pad + modelData.y * ih)
            readonly property int x1: Math.round(root.pad + (modelData.x + modelData.w) * iw)
            readonly property int y1: Math.round(root.pad + (modelData.y + modelData.h) * ih)

            x: x0
            y: y0
            width: Math.max(2, x1 - x0 - root.gap)
            height: Math.max(2, y1 - y0 - root.gap)

            // ---- compact (bar) ---------------------------------------------
            // Tinted cell with the app glyph; the focused window is filled
            // solid with the glyph knocked out of it.
            Rectangle {
                visible: !root.detailed
                anchors.fill: parent
                radius: 1
                color: root.tint(cell.appColor, cell.modelData.focused ? 0.9 : 0.3)
                border.width: cell.modelData.floating || cell.modelData.urgent ? 1 : 0
                border.color: cell.appColor
            }

            Text {
                readonly property int size: Math.min(11, Math.min(cell.width, cell.height - (cell.grouped ? 2 : 0)) - 3)
                visible: !root.detailed && size >= 7
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: cell.grouped ? 1 : 0
                text: cell.style.glyph
                font.family: Theme.font
                font.pixelSize: size
                // Fallback letters (unknown apps) read better bold at this size.
                font.bold: /^[A-Za-z0-9]$/.test(cell.style.glyph)
                color: cell.modelData.focused ? Theme.windowShadow : cell.appColor
            }

            // Group tab strip: one segment per member in its app colour, the
            // visible one lit.
            Row {
                visible: !root.detailed && cell.grouped
                anchors { left: parent.left; right: parent.right; top: parent.top }
                spacing: 1

                Repeater {
                    model: cell.modelData.members

                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool lit: index === cell.modelData.shown
                        width: (cell.width - (cell.modelData.members.length - 1)) / cell.modelData.members.length
                        height: Math.round(2 * Theme.s)
                        color: cell.modelData.focused && lit ? Theme.windowShadow
                            : root.tint(AppStyle.style(modelData.cls).color, lit ? 1 : 0.45)
                    }
                }
            }

            // ---- detailed (hover preview) -----------------------------------
            Rectangle {
                visible: root.detailed
                anchors.fill: parent
                radius: Math.round(6 * Theme.s)
                color: root.tint(cell.appColor, cell.modelData.focused ? 0.26 : 0.13)
                border.width: cell.modelData.focused ? 2 : 1
                border.color: cell.modelData.focused ? Colors.accent : root.tint(cell.appColor, 0.55)
            }

            // Tabs: every group member's icon, the visible one on a chip.
            Row {
                id: tabs
                visible: root.detailed && cell.grouped && cell.height > 40
                anchors { left: parent.left; top: parent.top; margins: 4 }
                spacing: Math.round(3 * Theme.s)

                Repeater {
                    model: cell.modelData.members

                    Rectangle {
                        required property var modelData
                        required property int index
                        width: Math.round(20 * Theme.s)
                        height: Math.round(18 * Theme.s)
                        radius: Math.round(4 * Theme.s)
                        color: index === cell.modelData.shown ? root.tint(cell.appColor, 0.35) : "transparent"

                        AppGlyph {
                            anchors.centerIn: parent
                            cls: parent.modelData.cls
                            size: 13
                        }
                    }
                }
            }

            Column {
                visible: root.detailed
                anchors.centerIn: parent
                anchors.verticalCenterOffset: tabs.visible ? 9 : 0
                width: parent.width - Math.round(12 * Theme.s)
                spacing: Math.round(3 * Theme.s)

                AppGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    cls: cell.app.cls
                    size: Math.max(12, Math.min(34, cell.height * 0.32, cell.width * 0.4))
                }

                Text {
                    visible: cell.height > 56 && cell.width > 56
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.app.title || cell.app.cls
                    elide: Text.ElideRight
                    maximumLineCount: cell.height > 110 ? 2 : 1
                    wrapMode: Text.Wrap
                    font.family: Theme.font
                    font.pixelSize: Theme.fsLabel - Math.round(3 * Theme.s)
                    color: Theme.fg
                }
            }
        }
    }

    // App icon from the desktop entry, or the AppStyle glyph when there is
    // no themed icon for the class.
    component AppGlyph: Item {
        property string cls
        property real size: Math.round(16 * Theme.s)
        readonly property string icon: AppStyle.iconPath(cls)
        readonly property var style: AppStyle.style(cls)

        implicitWidth: size
        implicitHeight: size

        IconImage {
            anchors.fill: parent
            visible: parent.icon !== ""
            source: parent.icon
            implicitSize: parent.size
        }

        Text {
            anchors.centerIn: parent
            visible: parent.icon === ""
            text: parent.style.glyph
            font.family: Theme.font
            font.pixelSize: parent.size * 0.85
            color: parent.style.color
        }
    }
}
