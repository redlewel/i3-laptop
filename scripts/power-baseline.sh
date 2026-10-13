#!/usr/bin/env bash
# Append one power sample to docs/power-log.md. Run on battery, idle, screen on, before and after tuning.
# This battery exposes current_now/voltage_now (µA/µV), not power_now.
set -euo pipefail
cd "$(dirname "$0")/.."
B=/sys/class/power_supply/BAT0
cur=$(cat $B/current_now); volt=$(cat $B/voltage_now)
watts=$(awk -v c="$cur" -v v="$volt" 'BEGIN{printf "%.2f", c*v/1e12}')
status=$(cat $B/status)
profile=$(cat /sys/firmware/acpi/platform_profile 2>/dev/null || echo n/a)
epp=$(cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference 2>/dev/null || echo n/a)
dgpu=$(cat /sys/bus/pci/devices/$(lspci -D -d 10de: | awk '/VGA|3D/ {print $1; exit}')/power/runtime_status 2>/dev/null || echo n/a)
bl=$(cat /sys/class/backlight/intel_backlight/brightness 2>/dev/null || echo n/a)
tlp=$(systemctl is-active tlp 2>/dev/null || echo inactive)
note="${1:-}"
[ -f docs/power-log.md ] || printf '# Power log\n\n| when | status | watts | profile | epp | dGPU | backlight | tlp | note |\n|---|---|---|---|---|---|---|---|---|\n' > docs/power-log.md
line="| $(date -Is) | $status | $watts | $profile | $epp | $dgpu | $bl | $tlp | $note |"
echo "$line" | tee -a docs/power-log.md
