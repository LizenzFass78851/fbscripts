#!/bin/bash

# Centralized TR-064 script for AVM FRITZ!Box
# Usage: ./fb_tr064.sh [action]
# Configuration via environment variables:
# FB_IPS="192.168.178.1;192.168.178.20"
# FB_USER="username"
# FB_PW="password"

# Standard values / Environment Override
IFS_OLD=$IFS
IFS=';'
read -r -a IPS <<< "${FB_IPS:-192.168.178.1}"
IFS=$IFS_OLD

FRITZUSER="${FB_USER:-}"
FRITZPW="${FB_PW:-0000}"

usage() {
    local exit_code="${1:-0}"
    cat <<EOF_USAGE
Usage: $0 [Action]

Actions:
  reboot              Reboot the FRITZ!Box
  get_info            Get general device information
  get_logs            Get device logs
  get_security_port    Get the TR-064 security port
  get_firmware_info    Get firmware/update information
  check_update         Check whether a firmware update is available
  update               Trigger the update procedure
  get_wan_status       Get Internet connection status
  get_external_ip      Get the public/external IP address
  get_dns_servers      Get configured WAN DNS servers
  get_wan_stats        Get WAN interface statistics
  get_dsl_info         Get DSL line information (DSL models only)
  get_wifi_info        Get 2.4 GHz WLAN information
  get_wifi5_info       Get 5 GHz WLAN information
  get_guest_wifi_info  Get guest WLAN information
  get_host_count       Get the number of known network devices
  get_hosts            Get host/device information
  wifi_on              Enable WLAN globally
  wifi_off             Disable WLAN globally
  guest_wifi_on        Enable guest WLAN
  guest_wifi_off       Disable guest WLAN
  reconnect            Reconnect the Internet connection

Configuration via environment variables:
  FB_IPS               Semicolon-separated list of FRITZ!Box IP addresses
  FB_USER              FRITZ!Box username
  FB_PW                FRITZ!Box password
EOF_USAGE
    exit "$exit_code"
}

# Parse SOAP XML responses for easier reading.
# Python's standard XML parser is preferred; xmlstarlet is a fallback.
format_soap_response() {
    local xml="$1"

    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$xml" | python3 -c '
import sys
import xml.etree.ElementTree as ET

raw = sys.stdin.read()

def local_name(tag):
    return tag.rsplit("}", 1)[-1].split(":")[-1]

def label(tag):
    name = local_name(tag)
    if name.endswith("Response"):
        name = name[:-8]
    elif name.startswith("New") and len(name) > 3:
        name = name[3:]
    return name

def render(element, indent=0):
    prefix = "  " * indent
    name = label(element.tag)
    children = list(element)
    value = (element.text or "").strip()

    if children:
        print(f"{prefix}{name}:")
        if value:
            print(f"{prefix}  {value}")
        for child in children:
            render(child, indent + 1)
    elif value:
        lines = value.splitlines()
        if len(lines) == 1:
            print(f"{prefix}{name}: {lines[0].strip()}")
        else:
            print(f"{prefix}{name}:")
            for line in lines:
                line = line.strip()
                if line:
                    print(f"{prefix}  {line}")
    else:
        print(f"{prefix}{name}: (leer)")

try:
    root = ET.fromstring(raw)
    body = next((node for node in root.iter()
                 if local_name(node.tag).lower() == "body"), None)
    entries = list(body) if body is not None else [root]

    if not entries:
        print("(Leere SOAP-Antwort)")
    else:
        for entry in entries:
            if local_name(entry.tag).lower() == "fault":
                print("SOAP Fault:")
                for child in entry.iter():
                    if child is not entry and not list(child) and (child.text or "").strip():
                        fault_text = (child.text or "").strip()
                        print(f"  {label(child.tag)}: {fault_text}")
            else:
                render(entry)
except ET.ParseError:
    print(raw, end="" if raw.endswith("\n") else "\n")
'
    elif command -v xmlstarlet >/dev/null 2>&1; then
        printf '%s\n' "$xml" | xmlstarlet fo -s 2
    else
        printf '%s\n' "$xml"
    fi
}

# Centralized function for TR-064 SOAP calls.
# Optional 5th argument: SOAP input XML; optional 6th: suppress failure messages.
call_action() {
    local ip=$1
    local location=$2
    local uri=$3
    local action=$4
    local soap_args="${5:-}"
    local quiet="${6:-false}"
    local curl_output curl_status http_code response_body

    [ "$quiet" = true ] || echo "[INFO] Executing '$action' on $ip..."

    curl_output=$(curl -m 8 --anyauth -u "$FRITZUSER:$FRITZPW" \
        "http://$ip:49000$location" \
        -H 'Content-Type: text/xml; charset="utf-8"' \
        -H "SoapAction:$uri#$action" \
        -d "<?xml version='1.0' encoding='utf-8'?><s:Envelope s:encodingStyle='http://schemas.xmlsoap.org/soap/encoding/' xmlns:s='http://schemas.xmlsoap.org/soap/envelope/'><s:Body><u:$action xmlns:u='$uri'>$soap_args</u:$action></s:Body></s:Envelope>" \
        -sS -w $'\n%{http_code}')
    curl_status=$?

    http_code=${curl_output##*$'\n'}
    response_body=${curl_output%$'\n'*}

    if [ "$curl_status" -ne 0 ]; then
        if [ "$quiet" != true ]; then
            echo "[ERROR] Action '$action' on $ip failed (curl exit $curl_status, HTTP $http_code)." >&2
            [ -n "$response_body" ] && format_soap_response "$response_body" >&2
        fi
        return 1
    fi

    case "$http_code" in
        2??)
            echo "[SUCCESS] Action '$action' on $ip successful."
            [ -n "$response_body" ] && format_soap_response "$response_body"
            return 0
            ;;
        *)
            if [ "$quiet" != true ]; then
                echo "[ERROR] Action '$action' on $ip failed (HTTP $http_code)." >&2
                [ -n "$response_body" ] && format_soap_response "$response_body" >&2
            fi
            return 1
            ;;
    esac
}

# Execute an action on all configured FRITZ!Box IPs and report failures.
run_on_all_ips() {
    local location=$1
    local uri=$2
    local action=$3
    local soap_args="${4:-}"
    local ip status=0

    for ip in "${IPS[@]}"; do
        [ -n "$ip" ] || continue
        call_action "$ip" "$location" "$uri" "$action" "$soap_args" || status=1
    done

    return "$status"
}

# WAN services differ depending on the connection type (IP or PPP).
# Try WANIPConnection first and fall back to WANPPPConnection.
run_wan_action() {
    local ip=$1
    local action=$2
    local soap_args="${3:-}"

    if call_action "$ip" "/upnp/control/wanipconnection1" \
        "urn:dslforum-org:service:WANIPConnection:1" "$action" "$soap_args" true; then
        return 0
    fi

    if call_action "$ip" "/upnp/control/wanpppconn1" \
        "urn:dslforum-org:service:WANPPPConnection:1" "$action" "$soap_args" true; then
        return 0
    fi

    echo "[ERROR] WAN action '$action' is unavailable or failed on $ip (IP and PPP services)." >&2
    return 1
}

# Existing actions
do_reboot() { run_on_all_ips "/upnp/control/deviceconfig" "urn:dslforum-org:service:DeviceConfig:1" "Reboot"; }
do_get_info() { run_on_all_ips "/upnp/control/deviceinfo" "urn:dslforum-org:service:DeviceInfo:1" "GetInfo"; }
do_get_logs() { run_on_all_ips "/upnp/control/deviceinfo" "urn:dslforum-org:service:DeviceInfo:1" "GetDeviceLog"; }
do_update() { run_on_all_ips "/upnp/control/userif" "urn:dslforum-org:service:UserInterface:1" "X_AVM-DE_DoUpdate"; }

# System / firmware information
do_get_security_port() {
    run_on_all_ips "/upnp/control/deviceinfo" "urn:dslforum-org:service:DeviceInfo:1" "GetSecurityPort"
}

do_get_firmware_info() {
    run_on_all_ips "/upnp/control/userif" "urn:dslforum-org:service:UserInterface:1" "GetInfo"
}

do_check_update() {
    local ip status=0
    for ip in "${IPS[@]}"; do
        [ -n "$ip" ] || continue
        if call_action "$ip" "/upnp/control/userif" "urn:dslforum-org:service:UserInterface:1" "X_AVM-DE_CheckUpdate"; then
            call_action "$ip" "/upnp/control/userif" "urn:dslforum-org:service:UserInterface:1" "GetInfo" || status=1
        else
            status=1
        fi
    done
    return "$status"
}

# Internet / WAN information
do_get_wan_status() {
    local ip status=0
    for ip in "${IPS[@]}"; do
        [ -n "$ip" ] || continue
        run_wan_action "$ip" "GetStatusInfo" || status=1
    done
    return "$status"
}

do_get_external_ip() {
    local ip status=0
    for ip in "${IPS[@]}"; do
        [ -n "$ip" ] || continue
        run_wan_action "$ip" "GetExternalIPAddress" || status=1
    done
    return "$status"
}

do_get_dns_servers() {
    local ip status=0
    for ip in "${IPS[@]}"; do
        [ -n "$ip" ] || continue
        run_wan_action "$ip" "X_GetDNSServers" || status=1
    done
    return "$status"
}

do_get_wan_stats() {
    local status=0
    run_on_all_ips "/upnp/control/wancommonifconfig1" "urn:dslforum-org:service:WANCommonInterfaceConfig:1" "GetCommonLinkProperties" || status=1
    run_on_all_ips "/upnp/control/wancommonifconfig1" "urn:dslforum-org:service:WANCommonInterfaceConfig:1" "GetTotalBytesReceived" || status=1
    run_on_all_ips "/upnp/control/wancommonifconfig1" "urn:dslforum-org:service:WANCommonInterfaceConfig:1" "GetTotalBytesSent" || status=1
    return "$status"
}

do_get_dsl_info() {
    run_on_all_ips "/upnp/control/wandslifconfig1" "urn:dslforum-org:service:WANDSLInterfaceConfig:1" "GetInfo"
}

# WLAN information and controls
do_get_wifi_info() {
    run_on_all_ips "/upnp/control/wlanconfig1" "urn:dslforum-org:service:WLANConfiguration:1" "GetInfo"
}

do_get_wifi5_info() {
    run_on_all_ips "/upnp/control/wlanconfig2" "urn:dslforum-org:service:WLANConfiguration:2" "GetInfo"
}

do_get_guest_wifi_info() {
    run_on_all_ips "/upnp/control/wlanconfig3" "urn:dslforum-org:service:WLANConfiguration:3" "GetInfo"
}

do_wifi_on() {
    run_on_all_ips "/upnp/control/wlanconfig1" "urn:dslforum-org:service:WLANConfiguration:1" \
        "X_AVM-DE_SetWLANGlobalEnable" "<NewX_AVM-DE_WLANGlobalEnable>1</NewX_AVM-DE_WLANGlobalEnable>"
}

do_wifi_off() {
    run_on_all_ips "/upnp/control/wlanconfig1" "urn:dslforum-org:service:WLANConfiguration:1" \
        "X_AVM-DE_SetWLANGlobalEnable" "<NewX_AVM-DE_WLANGlobalEnable>0</NewX_AVM-DE_WLANGlobalEnable>"
}

do_guest_wifi_on() {
    run_on_all_ips "/upnp/control/wlanconfig3" "urn:dslforum-org:service:WLANConfiguration:3" \
        "SetEnable" "<NewEnable>1</NewEnable>"
}

do_guest_wifi_off() {
    run_on_all_ips "/upnp/control/wlanconfig3" "urn:dslforum-org:service:WLANConfiguration:3" \
        "SetEnable" "<NewEnable>0</NewEnable>"
}

# Home network devices
do_get_host_count() {
    run_on_all_ips "/upnp/control/hosts" "urn:dslforum-org:service:Hosts:1" "GetHostNumberOfEntries"
}

do_get_hosts() {
    run_on_all_ips "/upnp/control/hosts" "urn:dslforum-org:service:Hosts:1" "X_AVM-DE_GetInfo"
}

# Reconnect the Internet using whichever WAN service the box supports.
do_reconnect() {
    local ip status=0
    for ip in "${IPS[@]}"; do
        [ -n "$ip" ] || continue
        if call_action "$ip" "/upnp/control/wanipconnection1" \
            "urn:dslforum-org:service:WANIPConnection:1" "ForceTermination" "" true; then
            call_action "$ip" "/upnp/control/wanipconnection1" \
                "urn:dslforum-org:service:WANIPConnection:1" "RequestConnection" || status=1
        elif call_action "$ip" "/upnp/control/wanpppconn1" \
            "urn:dslforum-org:service:WANPPPConnection:1" "ForceTermination" "" true; then
            call_action "$ip" "/upnp/control/wanpppconn1" \
                "urn:dslforum-org:service:WANPPPConnection:1" "RequestConnection" || status=1
        else
            echo "[ERROR] Could not initiate WAN reconnection on $ip." >&2
            status=1
        fi
    done
    return "$status"
}

# Show which XML parser will be used by format_soap_response().
# Python 3 is preferred; xmlstarlet is the fallback; otherwise raw XML is shown.
if [[ -n "${1:-}" && "${1:-}" != "-h" && "${1:-}" != "--help" ]]; then
    if command -v python3 >/dev/null 2>&1; then
        echo "[INFO] XML parser: Python 3 (xml.etree.ElementTree)"
    elif command -v xmlstarlet >/dev/null 2>&1; then
        echo "[INFO] XML parser: xmlstarlet (XML formatting fallback)"
    else
        echo "[WARN] XML parser: none found; raw XML responses will be displayed."
    fi
fi

# Main logic
case "${1:-}" in
    reboot)             do_reboot ;;
    get_info)            do_get_info ;;
    get_logs)            do_get_logs ;;
    get_security_port)   do_get_security_port ;;
    get_firmware_info)   do_get_firmware_info ;;
    check_update)        do_check_update ;;
    update)              do_update ;;
    get_wan_status)      do_get_wan_status ;;
    get_external_ip)     do_get_external_ip ;;
    get_dns_servers)     do_get_dns_servers ;;
    get_wan_stats)       do_get_wan_stats ;;
    get_dsl_info)        do_get_dsl_info ;;
    get_wifi_info)       do_get_wifi_info ;;
    get_wifi5_info)      do_get_wifi5_info ;;
    get_guest_wifi_info) do_get_guest_wifi_info ;;
    get_host_count)      do_get_host_count ;;
    get_hosts)           do_get_hosts ;;
    wifi_on)             do_wifi_on ;;
    wifi_off)            do_wifi_off ;;
    guest_wifi_on)       do_guest_wifi_on ;;
    guest_wifi_off)      do_guest_wifi_off ;;
    reconnect)            do_reconnect ;;
    -h|--help)           usage 0 ;;
    "")                 usage 1 ;;
    *)
        echo "Unknown action: $1" >&2
        usage 1
        ;;
esac
