#!/usr/bin/env python3
# Prints "<evdev keycode> <1|0>" on every key press/release, for the SUPER+K
# cheat sheet (ui/KeymapOverlay.qml) -- it has no keyboard focus, so it can't
# see keys itself. Needs read access to /dev/input (the `input` group).
# Quickshell only runs this while the overlay is shown.
import re, selectors, struct

EVENT = struct.Struct("llHHi")  # struct input_event: timeval, type, code, value
EV_KEY = 1

# Every device with the kbd handler. Not /dev/input/by-id: Bluetooth
# keyboards (the TOTEM) get no symlink there.
with open("/proc/bus/input/devices") as f:
    events = re.findall(r"^H: Handlers=.*\bkbd\b.*?\b(event\d+)", f.read(), re.M)

sel = selectors.DefaultSelector()
for ev in events:
    try:
        sel.register(open(f"/dev/input/{ev}", "rb", buffering=0), selectors.EVENT_READ)
    except OSError:
        pass

while True:
    for key, _ in sel.select():
        try:
            data = key.fileobj.read(EVENT.size * 64)
        except OSError:  # unplugged
            sel.unregister(key.fileobj)
            continue
        for _, _, type_, code, value in EVENT.iter_unpack(data):
            if type_ == EV_KEY and value in (0, 1):  # skip autorepeat (2)
                print(code, value, flush=True)
