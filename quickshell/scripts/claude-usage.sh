#!/bin/sh
# Current Claude subscription limit utilisation, as JSON on stdout.
#
# This is the same endpoint Claude Code's own /usage view calls (its binary logs
# "fetchUtilization: GET /api/oauth/usage"). It is undocumented, so treat a
# non-200 as "no data" rather than an error worth shouting about -- the widget
# keeps showing its last good value.
#
# The bearer token is Claude Code's OAuth access token. It is deliberately NOT
# passed on the curl command line: argv is world-readable via /proc, and a
# credential there would leak to every process on the box. It goes through a
# 0600 curl config file in the runtime dir instead.
set -eu

CREDS="$HOME/.claude/.credentials.json"
[ -r "$CREDS" ] || exit 0

TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS")
[ -n "$TOKEN" ] || exit 0

CFG=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/qs-usage.XXXXXX")
chmod 600 "$CFG"
trap 'rm -f "$CFG"' EXIT INT TERM
printf 'header = "Authorization: Bearer %s"\n' "$TOKEN" > "$CFG"

curl -sS --max-time 10 -K "$CFG" \
    -H 'Content-Type: application/json' \
    https://api.anthropic.com/api/oauth/usage 2>/dev/null || exit 0
