#!/usr/bin/env python3
"""Top processes for the dashboard, one JSON line per sample:

    {"cpu": [row...], "mem": [row...]}   row = {pid, name, detail, cpu, rss}

cpu is percent of one core over the last interval (ps's %cpu is the average
over the process's whole lifetime, useless for "what is busy right now").
name/detail come from the full command line and working directory, so
`python` reads as `run_model.py  myproject · --epochs 3`.

    topprocs.py          run until killed (SysMon starts/stops it)
    topprocs.py --test   self-check of the naming rules
"""
import json
import os
import re
import sys
import time

N = 6
INTERVAL = 2.0
TICK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
HOME = os.path.expanduser("~")
INTERP = re.compile(r"^(python[\d.]*|node|bun|deno|bash|sh|zsh|fish|ruby|perl|lua|java|Rscript|electron\d*)$")


def describe(argv, comm, cwd):
    """(name, detail) for one process. argv may be empty (kernel threads)."""
    argv = [a for a in argv if a]
    if not argv:
        return comm, ""
    exe = os.path.basename(argv[0].lstrip("-")) or comm
    name, rest = exe, argv[1:]

    if INTERP.match(exe):
        # ponytail: flags are assumed to take no value (true for -I/-u/-O;
        # `python -X dev x.py` would name it "dev"). Add a table if it bites.
        i = 0
        while i < len(rest):
            a = rest[i]
            if a in ("-m", "-jar") and i + 1 < len(rest):
                name, rest = os.path.basename(rest[i + 1]), rest[i + 2:]
                break
            if a == "-c":
                name, rest = exe + " -c", rest[i + 1:]
                break
            if not a.startswith("-"):
                name, rest = os.path.basename(a), rest[i + 1:]
                break
            i += 1
        else:
            rest = []

    kind = next((a.split("=", 1)[1] for a in rest if a.startswith("--type=")), None)
    if kind is None and "-contentproc" in rest:
        kind = rest[-1]                      # firefox: ... -contentproc ... tab
    extra = kind if kind is not None else " ".join(a for a in rest if a != "--")[:80]

    # A working directory only says something when it is a project: not ~ or /,
    # not /proc/<pid>/fdinfo (sandboxed renderers), not app state under a dotdir.
    hidden = cwd.startswith("/proc/") or "/." in cwd
    project = "" if hidden or cwd in ("", "/", HOME) else os.path.basename(cwd)
    parts = [p for p in (project if project != name else "", extra) if p]
    return name, " · ".join(parts)


def read_procs():
    """{(pid, starttime): (ticks, rss_bytes, comm)} for every process."""
    out = {}
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/stat") as f:
                s = f.read()
        except OSError:
            continue
        # comm sits in parens and may itself contain spaces and parens.
        comm = s[s.index("(") + 1:s.rindex(")")]
        f = s[s.rindex(")") + 2:].split()   # f[0] is field 3 (state)
        out[(int(pid), f[19])] = (int(f[11]) + int(f[12]), int(f[21]) * PAGE, comm)
    return out


def row(pid, cpu, rss, comm):
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            argv = f.read().decode(errors="replace").split("\0")
    except OSError:
        argv = []
    # Chromium rewrites its cmdline as one space-joined string.
    # ponytail: breaks a lone argv[0] whose path contains " -"; rare.
    if len([a for a in argv if a]) == 1 and " -" in argv[0]:
        argv = argv[0].split(" ")
    try:
        cwd = os.readlink(f"/proc/{pid}/cwd")
    except OSError:
        cwd = ""                            # other users' processes
    name, detail = describe(argv, comm, cwd)
    return {"pid": pid, "name": name, "detail": detail, "cpu": round(cpu, 1), "rss": rss}


def main():
    me = os.getpid()
    prev, prev_t = read_procs(), time.monotonic()
    delay = 0.5                             # first frame quickly, then settle
    while True:
        time.sleep(delay)
        delay = INTERVAL
        cur, now = read_procs(), time.monotonic()
        dt = now - prev_t
        # A key missing from prev started inside this interval: all its ticks count.
        procs = [(pid, (t - prev.get((pid, st), (0,))[0]) / TICK / dt * 100, rss, comm)
                 for (pid, st), (t, rss, comm) in cur.items() if pid != me]
        prev, prev_t = cur, now
        top = lambda k: [row(*p) for p in sorted(procs, key=k, reverse=True)[:N]]
        print(json.dumps({"cpu": top(lambda p: p[1]), "mem": top(lambda p: p[2])}), flush=True)


def test():
    d = lambda cmd, cwd="/", comm="x": describe(cmd.split(" "), comm, cwd)
    assert d(".venv/bin/python -I scripts/run.py data out", "/home/u/proj") == ("run.py", "proj · data out")
    assert d("python3 -m http.server 8000", HOME) == ("http.server", "8000")
    assert d("/usr/bin/node /x/server.js", "/srv/api") == ("server.js", "api")
    assert d("java -Xmx2g -jar /opt/app.jar") == ("app.jar", "")
    assert d("python3") == ("python3", "")
    assert d("bash -c sleep 9") == ("bash -c", "sleep 9")
    assert d("/opt/brave-bin/brave --type=renderer --foo=1", HOME) == ("brave", "renderer")
    assert d("/usr/lib/firefox/firefox -contentproc -x 3 tab") == ("firefox", "tab")
    assert d("claude", "/home/u/dotfiles") == ("claude", "dotfiles")
    assert d("rust/target/release/krest duel -n 4", "/home/u/krest") == ("krest", "duel -n 4")
    assert d("/opt/brave-bin/brave --type=renderer", "/proc/42/fdinfo") == ("brave", "renderer")
    assert d("/usr/bin/Telegram --", "/home/u/.local/share/TelegramDesktop") == ("Telegram", "")
    assert d("-zsh", HOME) == ("zsh", "")
    assert describe([], "kworker/0:1", "") == ("kworker/0:1", "")
    print("ok")


if __name__ == "__main__":
    try:
        test() if "--test" in sys.argv else main()
    except (BrokenPipeError, KeyboardInterrupt):
        pass
