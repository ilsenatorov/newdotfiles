#!/bin/bash
# Wi-Fi share QR: prints "meta\t<iface>\t<security>\t<ssid>" then an NxN 0/1
# matrix (one char per QR module) for the active Wi-Fi connection, or the
# interface given as $1. Ported from omarchy's omarchy-network-qr --meta.

set -euo pipefail

interface=${1:-}
if [[ -z $interface ]]; then
  route_device=$(ip route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
  if [[ -n $route_device && -d /sys/class/net/$route_device/wireless ]]; then
    interface=$route_device
  else
    interface=$(LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
      awk -F: '$2 == "wifi" && $3 ~ /^connected/ { print $1; exit }')
  fi
fi
[[ -n $interface ]] || { echo "No active Wi-Fi connection" >&2; exit 1; }
uuid=$(nmcli --get-values GENERAL.CON-UUID device show "$interface" | head -n 1)
[[ -n $uuid && $uuid != "--" ]] || { echo "No active Wi-Fi connection" >&2; exit 1; }

mapfile -t fields < <(nmcli --show-secrets --escape no --get-values \
  802-11-wireless.ssid,802-11-wireless-security.key-mgmt,802-11-wireless-security.psk,802-11-wireless.hidden,802-11-wireless-security.wep-key0 \
  connection show uuid "$uuid")

ssid=${fields[0]:-}
key_management=${fields[1]:-}
password=${fields[2]:-}
hidden=${fields[3]:-no}
wep_key=${fields[4]:-}

[[ -n $ssid ]] || { echo "Could not read the Wi-Fi name" >&2; exit 1; }
[[ $key_management != *eap* && $key_management != *ieee8021x* ]] || {
  echo "Enterprise Wi-Fi cannot be shared with a password QR code" >&2
  exit 1
}

escape_wifi_qr() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//;/\\;}
  value=${value//,/\\,}
  value=${value//:/\\:}
  printf '%s' "$value"
}

if [[ -n $key_management && $key_management != "none" ]]; then
  [[ -n $password ]] || { echo "Could not read the Wi-Fi password" >&2; exit 1; }
  security=WPA
elif [[ -n $wep_key ]]; then
  password=$wep_key
  security=WEP
else
  security=nopass
fi

payload="WIFI:T:$security;S:$(escape_wifi_qr "$ssid");P:$(escape_wifi_qr "$password");"
[[ $hidden == "yes" ]] && payload+="H:true;"
payload+=";"

printf 'meta\t%s\t%s\t%s\n' "$interface" "$security" "$ssid"

# ASCII uses two characters per module; collapse each pair to one 0/1 value
# so the QML side can render a square matrix directly with native rectangles.
ascii=$(printf '%s' "$payload" | qrencode --type ASCII --margin 4 --output -)
while IFS= read -r line; do
  row=
  for ((column = 0; column < ${#line}; column += 2)); do
    [[ ${line:column:2} == *#* ]] && row+=1 || row+=0
  done
  printf '%s\n' "$row"
done <<<"$ascii"
