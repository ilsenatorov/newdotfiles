#!/usr/bin/env python3
"""Remember display layouts locally; save and restore named snapshots."""

import argparse
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

STATE = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "dotfiles"


def hyprctl(*args):
    return subprocess.check_output(["hyprctl", *args], text=True).strip()


def connected():
    monitors = json.loads(hyprctl("monitors", "all", "-j"))
    descriptions = [m.get("description") for m in monitors]
    for monitor in monitors:
        description = monitor.get("description")
        monitor["identity"] = (
            "desc:" + description
            if description and descriptions.count(description) == 1
            else "name:" + monitor["name"]
        )
    return monitors


def topology(monitors):
    return json.dumps(sorted(m["identity"] for m in monitors))


def snapshot(monitors, previous):
    old = {m["identity"]: m for m in previous}
    identities = {m["name"]: m["identity"] for m in monitors}
    layout = []
    for monitor in monitors:
        identity = monitor["identity"]
        disabled = monitor.get("disabled", False)
        if disabled and identity in old:
            entry = dict(old[identity], disabled=True)
        else:
            width, height = monitor["width"], monitor["height"]
            transform = monitor.get("transform", 0)
            if transform % 2:
                width, height = height, width
            mode = (
                f"{width}x{height}@{monitor['refreshRate']:.5f}"
                if width and height else "preferred"
            )
            entry = {
                "identity": identity,
                "mode": mode,
                "position": f"{monitor['x']}x{monitor['y']}",
                "scale": monitor.get("scale") or 1,
                "transform": transform,
                "disabled": disabled,
                "mirror": identities.get(monitor.get("mirrorOf"), ""),
            }
        layout.append(entry)
    return layout


def lua(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (float, int)):
        return str(value)
    escaped = ""
    for char in value:
        if char in ('"', "\\"):
            escaped += "\\" + char
        elif ord(char) < 32:
            escaped += f"\\{ord(char):03d}"
        else:
            escaped += char
    return '"' + escaped + '"'


def apply(layout, monitors):
    names = {m["identity"]: m["name"] for m in monitors}
    if set(names) != {m["identity"] for m in layout}:
        raise ValueError("This layout needs a different set of connected displays.")
    if not any(not m["disabled"] and not m["mirror"] for m in layout):
        raise ValueError("A layout must leave at least one independent display enabled.")
    calls = []
    # Bring independent outputs up before mirrors, and disable outputs last.
    for monitor in sorted(layout, key=lambda m: (m["disabled"], bool(m["mirror"]))):
        spec = {key: monitor[key] for key in ("mode", "position", "scale", "transform", "disabled")}
        spec["output"] = names[monitor["identity"]]
        spec["mirror"] = names[monitor["mirror"]] if monitor["mirror"] else ""
        calls.append("hl.monitor({" + ",".join(key + "=" + lua(value) for key, value in spec.items()) + "})")
    result = hyprctl("eval", ";".join(calls))
    if "error" in result.lower():
        raise ValueError(result)


def write_state(data):
    with tempfile.NamedTemporaryFile(mode="w", dir=STATE, delete=False) as output:
        temporary = Path(output.name)
        try:
            json.dump(data, output, ensure_ascii=False, indent=2)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
            os.replace(temporary, STATE / "displays.json")
        finally:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--remember", action="store_true")
    action.add_argument("--save", metavar="NAME")
    action.add_argument("--apply", metavar="NAME")
    action.add_argument("--restore", action="store_true")
    action.add_argument("--list", action="store_true")
    action.add_argument("--place", nargs=2, metavar=("PLACEMENT", "OUTPUT"))
    args = parser.parse_args()

    if args.restore:
        # Let config reload/hotplug settle before querying the connected set.
        time.sleep(0.3)
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / "displays.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | (fcntl.LOCK_NB if args.restore else 0))
        except BlockingIOError:
            return
        path = STATE / "displays.json"
        data = json.loads(path.read_text()) if path.exists() else {"last": {}, "profiles": {}}
        if args.list:
            print(json.dumps(sorted(data["profiles"]), ensure_ascii=False))
            return

        monitors = connected()
        if not monitors:
            raise ValueError("No connected displays.")
        key = topology(monitors)
        previous = data["last"].get(key, [])
        if args.place:
            calls = subprocess.check_output(
                [str(Path(__file__).with_name("monitor-place.sh")), "--dry-run", *args.place], text=True
            )
            result = hyprctl("eval", ";".join(calls.splitlines()))
            if "error" in result.lower():
                raise ValueError(result)
            time.sleep(0.1)
            monitors = connected()
            layout = snapshot(monitors, previous)
        elif args.apply is not None or args.restore:
            if args.apply is not None:
                if args.apply not in data["profiles"]:
                    raise ValueError("No saved layout named " + args.apply)
                layout = data["profiles"][args.apply]
            else:
                layout = previous
                if not layout or snapshot(monitors, previous) == layout:
                    return
            apply(layout, monitors)
        else:
            layout = snapshot(monitors, previous)
        if args.save is not None:
            name = args.save.strip()
            if not name:
                raise ValueError("Enter a layout name.")
            if name in data["profiles"]:
                raise ValueError("That name is already saved; choose another name.")
            data["profiles"][name] = layout
        if not args.restore:
            data["last"][key] = layout
            write_state(data)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
