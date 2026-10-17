## FRITZ!Box TR-064 Scripts

A collection of centralized scripts to manage AVM FRITZ!Box devices using the TR-064 protocol via `curl`.

- Requires a Linux system or Windows Subsystem for Linux (WSL) with `bash` and `curl` installed.
- No longer requires editing individual files for IP addresses or passwords; configuration is handled entirely via environment variables.

### Usage

```bash
./fb_tr064.sh [Action]
```

### Available Actions

| Action | Description |
| :--- | :--- |
| `reboot` | Reboot the FRITZ!Box |
| `get_info` | Get general device information |
| `get_logs` | Get device logs |
| `get_security_port` | Get the TR-064 security port |
| `get_firmware_info` | Get firmware/update information |
| `check_update` | Check whether a firmware update is available |
| `update` | Trigger the update procedure |
| `get_wan_status` | Get Internet connection status |
| `get_external_ip` | Get the public/external IP address |
| `get_dns_servers` | Get configured WAN DNS servers |
| `get_wan_stats` | Get WAN interface statistics |
| `get_dsl_info` | Get DSL line information |
| `get_wifi_info` | Get 2.4 GHz WLAN information |
| `get_wifi5_info` | Get 5 GHz WLAN information |
| `get_guest_wifi_info` | Get guest WLAN information |
| `get_host_count` | Get the number of known network devices |
| `get_hosts` | Get host/device information |
| `wifi_on` | Enable WLAN globally |
| `wifi_off` | Disable WLAN globally |
| `guest_wifi_on` | Enable guest WLAN |
| `guest_wifi_off` | Disable guest WLAN |
| `reconnect` | Reconnect the Internet connection |

### Configuration

Configuration is done using environment variables:

- `FB_IPS`: Semicolon-separated list of FRITZ!Box IP addresses (default: `192.168.178.1`)
- `FB_USER`: FRITZ!Box username
- `FB_PW`: FRITZ!Box password (default: `0000`)

### Example

```bash
export FB_IPS="192.168.178.1;192.168.178.20"
export FB_USER="admin"
export FB_PW="your_password"
./fb_tr064.sh reboot
```

