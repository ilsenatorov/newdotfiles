pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Current conditions from Open-Meteo: free, no API key, no account.
Singleton {
    id: root

    // Saarbrücken, hardcoded on purpose. Open-Meteo needs a coordinate, and a
    // fixed one means this never IP-geolocates or talks to a second service.
    readonly property real latitude: 49.23262
    readonly property real longitude: 7.00982

    property real tempC: 0
    property int code: -1
    property bool isDay: true
    property bool valid: false

    // WMO weather codes, collapsed to the handful of buckets worth drawing.
    readonly property var bucket: {
        const c = root.code;
        if (c < 0) return { icon: "", label: "--" };
        if (c === 0) return { icon: root.isDay ? "" : "", label: "CLEAR" };
        if (c <= 2) return { icon: root.isDay ? "" : "", label: "PARTLY" };
        if (c === 3) return { icon: "", label: "OVERCAST" };
        if (c <= 48) return { icon: "", label: "FOG" };
        if (c <= 57) return { icon: "", label: "DRIZZLE" };
        if (c <= 67) return { icon: "", label: "RAIN" };
        if (c <= 77) return { icon: "", label: "SNOW" };
        if (c <= 82) return { icon: "", label: "SHOWERS" };
        if (c <= 86) return { icon: "", label: "SNOW" };
        return { icon: "", label: "STORM" };
    }

    readonly property string text: valid
        ? bucket.icon + "  " + Math.round(tempC) + "° " + bucket.label
        : "--"

    Process {
        id: proc
        command: ["curl", "-sS", "--max-time", "12",
            "https://api.open-meteo.com/v1/forecast"
                + "?latitude=" + root.latitude
                + "&longitude=" + root.longitude
                + "&current=temperature_2m,weather_code,is_day&timezone=auto"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const c = JSON.parse(text).current;
                    if (c === undefined) return;
                    root.tempC = c.temperature_2m;
                    root.code = c.weather_code;
                    root.isDay = c.is_day === 1;
                    root.valid = true;
                } catch (e) {
                    // Offline or a bad payload: keep whatever we last had.
                }
            }
        }
    }

    // local.conf's SVC_WEATHER=0 stops this timer outright -- on a weak
    // machine there is no reason to shell out to curl every 15 minutes for a
    // widget that may not even be in BAR_LEFT/CENTER/RIGHT.
    Timer {
        running: Local.svcWeather
        repeat: true
        triggeredOnStart: true
        interval: 900000 // 15 min -- the upstream model only updates every 15
        onTriggered: proc.running = true
    }
}
