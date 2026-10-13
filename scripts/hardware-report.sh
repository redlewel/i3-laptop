#!/usr/bin/env bash
# Hardware inventory. Output is plain text; `just hw > docs/hardware-report-$(date +%F).txt`.
s() { echo; echo "===== $* ====="; }
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

s DMI; for k in system-manufacturer system-product-name bios-version bios-release-date; do $SUDO dmidecode -s $k; done
s KERNEL; uname -r; grep PRETTY /etc/os-release
s CPU; lscpu | grep -E 'Model name|^CPU\(s\)|Thread|Core|Socket'
s MEM; free -h | head -2
s GPU; lspci -nnk | grep -A3 -iE 'vga|3d|display'
s DRM; for c in /sys/class/drm/card?; do echo "$c: $(grep DRIVER $c/device/uevent)"; done
s PANEL; for p in /sys/class/drm/card*-eDP*; do echo "$p: $(cat $p/status) $(head -1 $p/modes)"; done; for b in /sys/class/backlight/*; do echo "$b max=$(cat $b/max_brightness) cur=$(cat $b/brightness)"; done
s NET; lspci -nnk | grep -A3 -iE 'network|ethernet'; ip -br link
s WIFI; $SUDO dmesg | grep -i 'iwlwifi.*Detected Intel' | head -1; iw dev 2>/dev/null | grep -E 'Interface|channel'
s STORAGE; lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL | grep -v loop; zpool status 2>/dev/null | head -20
s SLEEP; cat /sys/power/mem_sleep
s SECUREBOOT; mokutil --sb-state 2>&1
s TPM; ls /dev/tpm* 2>&1; cat /sys/class/tpm/tpm0/tpm_version_major 2>/dev/null
s PSTATE; cat /sys/devices/system/cpu/intel_pstate/status 2>&1; cat /sys/devices/system/cpu/cpufreq/policy0/energy_performance_preference 2>/dev/null
s PLATFORM_PROFILE; cat /sys/firmware/acpi/platform_profile_choices 2>&1; cat /sys/firmware/acpi/platform_profile 2>&1
s BATTERY; for b in /sys/class/power_supply/BAT*; do
  cf=$(cat $b/charge_full 2>/dev/null); cd=$(cat $b/charge_full_design 2>/dev/null)
  echo "$b: $(cat $b/model_name 2>/dev/null) status=$(cat $b/status) capacity=$(cat $b/capacity)% full=$cf design=$cd cycles=$(cat $b/cycle_count 2>/dev/null)"
  [ -n "$cf" ] && [ -n "$cd" ] && echo "  health: $(( cf * 100 / cd ))% of design"
done
s DGPU_PM; cat /sys/bus/pci/devices/$(lspci -D -d 10de: | awk '/VGA|3D/ {print $1; exit}')/power/runtime_status 2>/dev/null || echo "no NVIDIA dGPU"
s THUNDERBOLT; boltctl list 2>/dev/null | grep -E '^ \*|type|status' || ls /sys/bus/thunderbolt/devices/
s INPUT; grep -E '^N: Name' /proc/bus/input/devices | grep -iE 'touchpad|keyboard'
s AUDIO; lspci -nnk | grep -A2 -i 'audio controller' | grep -E 'audio|driver in use'
s CAMERA; timeout 10 gst-device-monitor-1.0 Video/Source 2>/dev/null </dev/null | grep -E 'name' | sort -u || echo "none"
s USB; lsusb | grep -v 'root hub'
s FIRMWARE; fwupdmgr get-devices --no-unreported-check 2>/dev/null | grep -E '^[A-Z]|Current version' | head -20
s DMESG_WARN; $SUDO dmesg --level=err,warn | grep -viE 'ACPI BIOS|int3472|usb' | head -15
