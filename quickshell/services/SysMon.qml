pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Machine stats for the dashboard. CPU/RAM/temperature come straight off sysfs
// with no subprocess; only disk needs one, and only once a minute.
Singleton {
    id: root

    // All 0..1 except tempC, which is real degrees.
    property real cpu: 0
    property real ram: 0
    property real ramUsedBytes: 0
    property real ramTotalBytes: 0
    property real tempC: 0
    property real disk: 0
    property real diskFreeBytes: 0
    property real swapUsedBytes: 0
    property real swapTotalBytes: 0
    property real uptimeSeconds: 0
    property real load1: 0
    property real netUp: 0            // bytes/sec
    property real netDown: 0

    // NVIDIA only (nvidia-smi) -- this box is an Optimus laptop with an
    // Intel iGPU alongside the NVIDIA card, and there is no free/no-root way
    // to read Intel GPU utilization without intel_gpu_top, which isn't
    // installed here. gpuAvailable stays false (and the dashboard hides the
    // GPU stats) when nvidia-smi is missing or reports no device.
    property bool gpuAvailable: false
    property real gpuUtil: 0          // 0..1
    property real gpuTempC: 0
    property real gpuVramUsedBytes: 0
    property real gpuVramTotalBytes: 0

    // Expanded -> 2s, collapsed -> 10s. Collapsed there is nothing to look at,
    // but staying warm means expanding never animates from stale values.
    property bool fast: false

    // Only sampled while the SUPER+G dashboard overlay is actually open --
    // ps is cheap but there's no reason to run it in the background.
    property bool procsActive: false
    property var topProcesses: []

    // Static machine identity for the dashboard's fastfetch-style header --
    // sampled once at startup, never changes without a reboot/shell change.
    property string hostname: ""
    property string osName: ""
    property string kernelVersion: ""
    property string shellName: ""

    readonly property real tempMin: 30
    readonly property real tempMax: 95
    readonly property real tempFrac: Math.max(0, Math.min(1, (tempC - tempMin) / (tempMax - tempMin)))

    property string tempPath: ""
    property string netIface: ""
    property int prevBusy: -1
    property int prevTotal: -1
    property real prevRx: -1
    property real prevTx: -1
    property real prevNetAt: 0

    readonly property string uptimeText: {
        const t = Math.floor(uptimeSeconds);
        const d = Math.floor(t / 86400);
        const h = Math.floor((t % 86400) / 3600);
        const m = Math.floor((t % 3600) / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    function fmtBytes(b: real): string {
        if (b >= 1024 * 1024 * 1024) return (b / (1024 * 1024 * 1024)).toFixed(b < 10.5 * 1024 * 1024 * 1024 ? 1 : 0) + "G";
        if (b >= 1024 * 1024) return Math.round(b / (1024 * 1024)) + "M";
        if (b >= 1024) return Math.round(b / 1024) + "K";
        return Math.round(b) + "B";
    }

    // hwmon indices shuffle between boots (coretemp is hwmon7 today), so find it
    // by name once at startup rather than hardcoding an index.
    Process {
        running: true
        command: ["sh", "-c", "grep -l coretemp /sys/class/hwmon/*/name | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p !== "") root.tempPath = p.replace(/\/name$/, "/temp1_input");
            }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: { root.gpuAvailable = text.trim() === "yes"; }
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "ip route show default | awk '{ print $5; exit }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = text.trim();
                if (n !== "") root.netIface = n;
            }
        }
    }

    // hostname / kernel / distro / shell, tab-separated in one process.
    Process {
        running: true
        command: ["sh", "-c", "hostname; uname -r; sh -c '. /etc/os-release 2>/dev/null; echo \"$PRETTY_NAME\"'; basename \"$SHELL\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.hostname = lines[0] ?? "";
                root.kernelVersion = lines[1] ?? "";
                root.osName = lines[2] ?? "";
                root.shellName = lines[3] ?? "";
            }
        }
    }

    Process {
        id: psProc
        command: ["sh", "-c", "ps -eo comm,%cpu --sort=-%cpu --no-headers | head -5"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.topProcesses = text.trim().split("\n").map(line => {
                    const m = /^(.*\S)\s+([\d.]+)$/.exec(line.trim());
                    return m ? { name: m[1], cpu: parseFloat(m[2]) } : null;
                }).filter(r => r !== null);
            }
        }
    }

    Timer {
        running: root.procsActive
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: psProc.running = true
    }

    FileView {
        id: netView
        path: "/proc/net/dev"
        blockLoading: true
        watchChanges: false
    }

    FileView {
        id: uptimeView
        path: "/proc/uptime"
        blockLoading: true
        watchChanges: false
    }

    FileView {
        id: loadView
        path: "/proc/loadavg"
        blockLoading: true
        watchChanges: false
    }

    FileView {
        id: statView
        path: "/proc/stat"
        blockLoading: true
        watchChanges: false
    }

    FileView {
        id: memView
        path: "/proc/meminfo"
        blockLoading: true
        watchChanges: false
    }

    FileView {
        id: tempView
        path: root.tempPath
        blockLoading: true
        watchChanges: false
    }

    Process {
        id: diskProc
        command: ["sh", "-c", "df -P / | awk 'NR==2 { gsub(/%/, \"\", $5); print $5, $4 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(/\s+/);
                const pct = parseFloat(f[0]);
                const availKb = parseFloat(f[1]);
                if (!isNaN(pct)) root.disk = pct / 100;
                if (!isNaN(availKb)) root.diskFreeBytes = availKb * 1024;
            }
        }
    }

    Process {
        id: gpuProc
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu",
                  "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                // "12, 512, 2048, 47" -- util%, vram used/total in MiB, temp C.
                const f = text.trim().split(",").map(s => parseFloat(s.trim()));
                if (f.length < 4 || f.some(isNaN)) return;
                root.gpuUtil = f[0] / 100;
                root.gpuVramUsedBytes = f[1] * 1024 * 1024;
                root.gpuVramTotalBytes = f[2] * 1024 * 1024;
                root.gpuTempC = f[3];
            }
        }
    }

    function sampleCpu(): void {
        // First line of /proc/stat: cpu user nice system idle iowait irq softirq steal ...
        // These are cumulative jiffies since boot, so usage is the delta between samples.
        const line = statView.text().split("\n")[0];
        if (!line.startsWith("cpu ")) return;

        const f = line.trim().split(/\s+/).slice(1).map(Number);
        if (f.length < 5) return;

        let total = 0;
        for (const v of f) total += v;
        const busy = total - f[3] - f[4]; // minus idle and iowait

        if (root.prevTotal >= 0) {
            const dTotal = total - root.prevTotal;
            if (dTotal > 0) root.cpu = Math.max(0, Math.min(1, (busy - root.prevBusy) / dTotal));
        }
        root.prevBusy = busy;
        root.prevTotal = total;
    }

    function sampleMem(): void {
        // MemAvailable already accounts for reclaimable cache, which is what
        // "used" should mean here -- MemFree alone would read ~95% on any box.
        const t = memView.text();
        const total = /MemTotal:\s+(\d+)/.exec(t);
        const avail = /MemAvailable:\s+(\d+)/.exec(t);
        if (total && avail && Number(total[1]) > 0) {
            root.ram = 1 - Number(avail[1]) / Number(total[1]);
            root.ramTotalBytes = Number(total[1]) * 1024;
            root.ramUsedBytes = root.ramTotalBytes - Number(avail[1]) * 1024;
        }

        const st = /SwapTotal:\s+(\d+)/.exec(t);
        const sf = /SwapFree:\s+(\d+)/.exec(t);
        if (st && sf) {
            root.swapTotalBytes = Number(st[1]) * 1024;
            root.swapUsedBytes = (Number(st[1]) - Number(sf[1])) * 1024;
        }
    }

    function sampleMisc(): void {
        const up = parseFloat(uptimeView.text().split(/\s+/)[0]);
        if (!isNaN(up)) root.uptimeSeconds = up;

        const l = parseFloat(loadView.text().split(/\s+/)[0]);
        if (!isNaN(l)) root.load1 = l;
    }

    function sampleNet(): void {
        // Same cumulative-counter delta as the CPU sampler, over the interface
        // that currently holds the default route.
        if (root.netIface === "") return;

        for (const line of netView.text().split("\n")) {
            const m = new RegExp("^\\s*" + root.netIface + ":\\s*(.*)$").exec(line);
            if (!m) continue;

            const f = m[1].trim().split(/\s+/).map(Number);
            const rx = f[0];
            const tx = f[8];
            const now = Date.now() / 1000;

            if (root.prevRx >= 0 && now > root.prevNetAt) {
                const dt = now - root.prevNetAt;
                root.netDown = Math.max(0, (rx - root.prevRx) / dt);
                root.netUp = Math.max(0, (tx - root.prevTx) / dt);
            }
            root.prevRx = rx;
            root.prevTx = tx;
            root.prevNetAt = now;
            return;
        }
    }

    function sampleTemp(): void {
        const v = parseInt(tempView.text().trim(), 10); // millidegrees
        if (!isNaN(v)) root.tempC = v / 1000;
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.fast ? 2000 : 10000
        onTriggered: {
            statView.reload();
            root.sampleCpu();
            memView.reload();
            root.sampleMem();
            if (root.tempPath !== "") {
                tempView.reload();
                root.sampleTemp();
            }
            uptimeView.reload();
            loadView.reload();
            root.sampleMisc();
            netView.reload();
            root.sampleNet();
            if (root.gpuAvailable) gpuProc.running = true;
        }
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: diskProc.running = true
    }
}
