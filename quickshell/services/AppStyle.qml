pragma Singleton

import QtQuick
import Quickshell
import ".."

// How an app shows up in the workspace minimap (bar/modules/WorkspaceMap.qml):
// a colour and a nerd-font glyph per Hyprland window class, plus the app's
// real icon for the hover preview. Matched top to bottom against the class
// (case-insensitive regex); add a row to teach it a new app. Glyphs must
// exist in Theme.font (MesloLGS NF: Font Awesome 4.7 at U+F0xx and Material
// Design at U+F0xxx are both there). Unknown classes get the first letter of
// the class and a stable colour from the matugen palette.
Singleton {
    readonly property var table: [
        { match: /^(kitty|alacritty|foot|wezterm|ghostty|konsole|.*terminal.*)$/i, glyph: "", color: "#93A1A1" },
        { match: /firefox|librewolf|zen/i, glyph: "", color: "#FF7139" },
        { match: /brave/i, glyph: "", color: "#FB542B" },
        { match: /chrom/i, glyph: "", color: "#4285F4" },
        { match: /spotify/i, glyph: "", color: "#1DB954" },
        { match: /telegram/i, glyph: "", color: "#2AABEE" },
        { match: /slack/i, glyph: "", color: "#E01E5A" },
        { match: /discord|vesktop|webcord/i, glyph: String.fromCodePoint(0xf066f), color: "#5865F2" },
        { match: /zathura|evince|okular|pdf/i, glyph: "", color: "#E5534B" },
        { match: /freecad|blender|openscad|prusa|orca|cura/i, glyph: "", color: "#E0A030" },
        { match: /^(code|code-oss|codium|vscodium|cursor|zed|dev\.zed\.zed)$|jetbrains/i, glyph: "", color: "#23A9F2" },
        { match: /nautilus|thunar|dolphin|nemo|pcmanfm|files/i, glyph: "", color: "#E9B96E" },
        { match: /steam/i, glyph: "", color: "#66C0F4" },
        { match: /obsidian|logseq|notion/i, glyph: "", color: "#A882FF" },
        { match: /gimp|inkscape|krita/i, glyph: "", color: "#C8A2C8" },
        { match: /mpv|vlc|celluloid|totem/i, glyph: "", color: "#B96BE0" },
        { match: /thunderbird|geary|evolution|mail/i, glyph: "", color: "#4F9CF9" },
        { match: /libreoffice|soffice/i, glyph: "", color: "#18A303" },
        { match: /pavucontrol|easyeffects|helvum/i, glyph: "", color: "#61C766" },
        { match: /zoom|teams|meet/i, glyph: "", color: "#2D8CFF" },
        { match: /settings|nwg-look|qt[56]ct|blueman/i, glyph: "", color: "#6D8895" },
    ]

    function style(cls: string): var {
        for (const row of table)
            if (row.match.test(cls))
                return { glyph: row.glyph, color: row.color };
        const palette = [Colors.red, Colors.orange, Colors.green, Colors.cyan, Colors.blue, Colors.purple];
        let h = 0;
        for (let i = 0; i < cls.length; i++)
            h = (h * 31 + cls.charCodeAt(i)) >>> 0;
        // Last dotted segment, so "org.pwmt.zathura" would read "Z" not "O".
        const name = cls.split(".").pop() || "?";
        return { glyph: name[0].toUpperCase(), color: palette[h % palette.length] };
    }

    // Themed icon file for the class, or "" -- callers fall back to the glyph.
    function iconPath(cls: string): string {
        const entry = DesktopEntries.heuristicLookup(cls);
        return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
    }
}
