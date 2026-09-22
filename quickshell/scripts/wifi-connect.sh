#!/bin/bash
# nmcli wrapper behind panels/Network.qml -- the connection types
# Quickshell.Networking can't set up on its own (open networks, WPA-Enterprise,
# hidden SSIDs, re-entering a wrong saved password) plus an on-demand rescan.
#
#   wifi-connect.sh psk    <ifname> <ssid>                    (password on stdin)
#   wifi-connect.sh open   <ifname> <ssid>
#   wifi-connect.sh eap    <ifname> <ssid> <peap|ttls> <identity> (password on stdin)
#   wifi-connect.sh hidden <ifname> <ssid>                    (password on stdin, empty = open)
#   wifi-connect.sh rescan <ifname>
#
# Secrets come in on stdin so they never sit in this script's argv; nmcli
# itself still takes them as arguments for the brief moment it runs. On
# failure a single human-readable line goes to stderr and the exit code is
# non-zero.

set -uo pipefail

mode=${1:?Usage: wifi-connect.sh <psk|open|eap|hidden|rescan> <ifname> [ssid] ...}
iface=${2:?missing interface}
ssid=${3:-}

wait_secs=30

read_secret() {
  IFS= read -r secret || true
  printf '%s' "$secret"
}

# UUIDs of every saved Wi-Fi profile whose SSID is exactly $1.
profiles_for() {
  local uuid type
  while IFS=: read -r uuid type; do
    [[ $type == 802-11-wireless ]] || continue
    [[ $(nmcli --get-values 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null) == "$1" ]] && echo "$uuid"
  done < <(nmcli -t -f UUID,TYPE connection show)
}

delete_profiles() {
  local uuid
  for uuid in $(profiles_for "$1"); do
    nmcli connection delete uuid "$uuid" >/dev/null 2>&1
  done
}

# Runs nmcli, turning its "Error: ..." output into one short line on failure.
run() {
  local out
  if out=$(nmcli --wait "$wait_secs" "$@" 2>&1); then
    return 0
  fi
  local msg
  msg=$(grep -m1 -i 'error' <<<"$out" || head -n1 <<<"$out")
  msg=${msg#Error: }
  case ${msg,,} in
    *secrets*|*802.1x*supplicant*|*password*) msg="Wrong password" ;;
    *"no network with ssid"*) msg="Network not found -- try refreshing" ;;
    *timeout*|*"timed out"*) msg="Timed out connecting" ;;
    *"ip configuration"*) msg="Connected but got no IP address" ;;
  esac
  echo "${msg:-Connection failed}" >&2
  return 1
}

case $mode in
  rescan)
    # NM refuses a rescan while one is already running (or right after one);
    # that's not an error from the user's point of view.
    nmcli device wifi rescan ifname "$iface" >/dev/null 2>&1
    exit 0
    ;;

  open)
    [[ -n $ssid ]] || { echo "missing SSID" >&2; exit 2; }
    run device wifi connect "$ssid" ifname "$iface"
    ;;

  psk)
    [[ -n $ssid ]] || { echo "missing SSID" >&2; exit 2; }
    password=$(read_secret)
    [[ -n $password ]] || { echo "Enter a password" >&2; exit 2; }

    # A saved profile with the wrong password: fix the secret in place so any
    # other tweaks (autoconnect priority, metered, ...) survive.
    uuid=$(profiles_for "$ssid" | head -n1)
    if [[ -n $uuid ]]; then
      key_mgmt=$(nmcli --get-values 802-11-wireless-security.key-mgmt connection show uuid "$uuid" 2>/dev/null)
      case $key_mgmt in
        wpa-psk|sae)
          nmcli connection modify uuid "$uuid" 802-11-wireless-security.psk "$password" >/dev/null 2>&1 &&
            { run connection up uuid "$uuid" ifname "$iface"; exit; }
          ;;
        none)
          nmcli connection modify uuid "$uuid" 802-11-wireless-security.wep-key0 "$password" >/dev/null 2>&1 &&
            { run connection up uuid "$uuid" ifname "$iface"; exit; }
          ;;
      esac
      # Profile of some other shape (or modify failed) -- start over.
      delete_profiles "$ssid"
    fi
    run device wifi connect "$ssid" password "$password" ifname "$iface"
    ;;

  eap)
    [[ -n $ssid ]] || { echo "missing SSID" >&2; exit 2; }
    method=${4:?missing EAP method}
    identity=${5:-}
    password=$(read_secret)
    [[ -n $identity ]] || { echo "Enter a username" >&2; exit 2; }
    [[ -n $password ]] || { echo "Enter a password" >&2; exit 2; }
    case $method in
      peap) phase2=mschapv2 ;;
      ttls) phase2=pap ;;
      *) echo "Unknown EAP method: $method" >&2; exit 2 ;;
    esac

    delete_profiles "$ssid"
    if ! out=$(nmcli connection add type wifi ifname "$iface" con-name "$ssid" ssid "$ssid" \
        wifi-sec.key-mgmt wpa-eap \
        802-1x.eap "$method" \
        802-1x.phase2-auth "$phase2" \
        802-1x.identity "$identity" \
        802-1x.password "$password" 2>&1); then
      msg=$(head -n1 <<<"$out")
      echo "${msg#Error: }" >&2
      exit 1
    fi
    uuid=$(profiles_for "$ssid" | head -n1)
    run connection up uuid "$uuid" ifname "$iface"
    ;;

  hidden)
    [[ -n $ssid ]] || { echo "Enter the network name" >&2; exit 2; }
    password=$(read_secret)
    delete_profiles "$ssid"
    if [[ -n $password ]]; then
      run device wifi connect "$ssid" password "$password" hidden yes ifname "$iface"
    else
      run device wifi connect "$ssid" hidden yes ifname "$iface"
    fi
    ;;

  *)
    echo "Unknown mode: $mode" >&2
    exit 2
    ;;
esac
