#!/usr/bin/env python3
"""Claude Code status line drawn like the starship prompt (starship.base.toml).

Same gruvbox-rainbow chain, same matugen palette read live from
starship/colors.toml, so it follows the wallpaper with no rebuild:

    os+user(@host) > directory > git > model > context > time

Claude Code pipes session JSON on stdin and prints whatever we write. Stdlib
only: the homeserver has no jq.
"""

import json
import os
import re
import subprocess
import sys
import time
import tomllib

DOTS = os.path.expanduser("~/dotfiles")
SEP = ""  #
CAP_L = ""  #

# Fallbacks = matugen/defaults/starship/colors.toml, used if the file is unreadable.
PALETTE = {
    "hue_red": "#72333b", "hue_orange": "#71361b", "hue_green": "#025233",
    "hue_cyan": "#004e59", "on_hue": "#e2e2e9", "surface_bright": "#37393e",
    "surface_container": "#1e2025", "on_surface": "#e2e2e9",
    "error": "#ffb4ab", "on_error": "#690005",
    "green": "#61C766", "red": "#EC7875", "yellow": "#FDD835",
}


def load_palette():
    try:
        with open(os.path.join(DOTS, "starship/colors.toml"), "rb") as f:
            PALETTE.update(tomllib.load(f)["palettes"]["dots"])
    except Exception:
        pass


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def fg(name):
    return "\033[38;2;%d;%d;%dm" % rgb(PALETTE[name])


def bg(name):
    return "\033[48;2;%d;%d;%dm" % rgb(PALETTE[name])


RESET = "\033[0m"
BOLD = "\033[1m"
NOBOLD = "\033[22m"


def git_info(cwd):
    """(branch, counters, state) the way starship's git_* modules print them."""
    try:
        out = subprocess.run(
            ["git", "-C", cwd, "--no-optional-locks", "status",
             "--porcelain=v2", "--branch", "--show-stash"],
            capture_output=True, text=True, timeout=0.5,
        )
    except Exception:
        return None
    if out.returncode != 0:
        return None
    branch, ahead, behind, stash = "", 0, 0, 0
    c = dict(conflicted=0, staged=0, modified=0, untracked=0, renamed=0, deleted=0)
    for line in out.stdout.splitlines():
        if line.startswith("# branch.head "):
            branch = line.split(" ", 2)[2]
        elif line.startswith("# branch.oid ") and not branch:
            branch = line.split(" ", 2)[2][:7]
        elif line.startswith("# branch.ab "):
            a, b = line.split()[2:4]
            ahead, behind = int(a), -int(b)
        elif line.startswith("# stash "):
            stash = int(line.split()[2])
        elif line[:2] in ("1 ", "2 "):
            xy = line[2:4]
            if xy[0] == "R":
                c["renamed"] += 1
            elif xy[0] != ".":
                c["staged"] += 1
            if xy[1] == "D":
                c["deleted"] += 1
            elif xy[1] != ".":
                c["modified"] += 1
        elif line.startswith("u "):
            c["conflicted"] += 1
        elif line.startswith("? "):
            c["untracked"] += 1
    if branch == "(detached)":
        branch = "HEAD"
    # Same marker order as starship's $all_status, same symbols as starship.base.toml.
    marks = [("~", "conflicted"), ("*", None), ("»", "renamed"), ("✘", "deleted"),
             ("!", "modified"), ("+", "staged"), ("?", "untracked")]
    counts = ""
    for sym, key in marks:
        n = stash if key is None else c[key]
        if n:
            counts += f"{sym}{n}"
    if ahead and behind:
        counts += f"⇡{ahead}⇣{behind}"
    elif ahead:
        counts += f"⇡{ahead}"
    elif behind:
        counts += f"⇣{behind}"

    state = ""
    try:
        gd = subprocess.run(["git", "-C", cwd, "rev-parse", "--git-dir"],
                            capture_output=True, text=True, timeout=0.3).stdout.strip()
        gd = os.path.join(cwd, gd)
        for marker, name in (("rebase-merge", "REBASING"), ("rebase-apply", "REBASING"),
                             ("MERGE_HEAD", "MERGING"), ("CHERRY_PICK_HEAD", "CHERRY-PICKING"),
                             ("REVERT_HEAD", "REVERTING"), ("BISECT_LOG", "BISECTING")):
            if os.path.exists(os.path.join(gd, marker)):
                state = name
                break
    except Exception:
        pass
    return branch, counts, state


def repo_root(cwd):
    try:
        r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, timeout=0.3)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None


def tilde(p):
    home = os.path.expanduser("~")
    return "~" + p[len(home):] if p == home or p.startswith(home + "/") else p


def main():
    load_palette()
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}
    cwd = (data.get("workspace") or {}).get("current_dir") or data.get("cwd") or os.getcwd()

    segs = []  # (bg_name, text) -- text already carries its own fg/bold codes

    # 1. os + user (+@host over ssh), like [os] [username] [hostname]
    user = os.environ.get("USER", "")
    host = ""
    if os.environ.get("SSH_CONNECTION") or os.environ.get("SSH_TTY"):
        host = f"{BOLD}@{os.uname().nodename}{NOBOLD} "
    segs.append(("error" if user == "root" else "hue_red", f" 󰣇 {user} {host}"))

    # 2. directory, repo root bold (repo_root_style)
    root = repo_root(cwd)
    path = tilde(cwd)
    if root and (cwd == root or cwd.startswith(root + "/")):
        troot = tilde(root)
        name = os.path.basename(troot)
        path = f"{troot[:len(troot) - len(name)]}{BOLD}{name}{NOBOLD}{cwd[len(root):]}"
    ro = "" if os.access(cwd, os.W_OK) else f"{fg('red')} {fg('on_hue')}"
    segs.append(("hue_orange", f" {path}{ro} "))

    # 3. git: branch, state, counters
    g = git_info(cwd) if root else None
    if g:
        branch, counts, state = g
        txt = f"  {branch} "
        if state:
            txt += f"{BOLD}{state}{NOBOLD} "
        if counts:
            txt += f"{counts} "
        segs.append(("hue_green", txt))
    else:
        segs.append(("hue_green", ""))

    # 4. cyan slot (languages in starship) -> the model, plus a uv venv if active
    model = (data.get("model") or {}).get("display_name") or ""
    venv = os.path.basename(os.environ.get("VIRTUAL_ENV", ""))
    txt = f" 󰚩 {model} " if model else ""
    if venv:
        txt += f"({venv}) "
    segs.append(("hue_cyan", txt))

    # 5. surface_bright slot (docker in starship) -> context window used
    ctx = data.get("context_window") or {}
    pct = ctx.get("used_percentage")
    txt = ""
    if pct is not None:
        pct = float(pct)
        warn = fg("yellow") if pct >= 60 else ""
        if pct >= 85:
            warn = fg("red")
        txt = f" {warn}󰍛 {pct:.0f}%{fg('on_surface')} "
    segs.append(("surface_bright", txt))

    # 6. time, like [time]
    segs.append(("surface_container", f" 󰥔 {time.strftime('%H:%M:%S')} "))

    # Render the chain: leading cap, segment, separator in (prev fg, next bg).
    on = {"hue_red": "on_hue", "hue_orange": "on_hue", "hue_green": "on_hue",
          "hue_cyan": "on_hue", "surface_bright": "on_surface",
          "surface_container": "on_surface", "error": "on_error"}
    out = fg(segs[0][0]) + CAP_L
    for i, (b, text) in enumerate(segs):
        out += bg(b) + fg(on[b]) + text
        if i + 1 < len(segs):
            out += fg(b) + bg(segs[i + 1][0]) + SEP
        else:
            out += RESET + fg(b) + SEP + RESET

    sys.stdout.write(out)


if __name__ == "__main__":
    main()
