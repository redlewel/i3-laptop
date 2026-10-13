# Known gaps

## Webcam (blocking for built-in camera, not for calls)
The internal camera is an OmniVision **OV08F4** sensor behind Intel IPU6 (`intel-ipu6` binds,
reports "Found supported sensor OVTI08F4", but no `ov08f4` i2c driver exists in kernel 7.0;
only ov08x40/ov08d10 ship). libcamera 0.7 reports "No sensor found for /dev/media0".
Workaround: USB webcam. Revisit when a sensor driver lands upstream or in Intel's
out-of-tree `ipu6-drivers`.

## Hibernate
ZFS root means no safe swap target for hibernation. s2idle is the only sleep state the
platform offers anyway. Measure overnight drain; if it exceeds ~15 %, the options are
a shorter idle-to-poweroff policy or a non-ZFS reinstall, not hibernate.

## NVIDIA RTX PRO 2000 (Blackwell)
On nouveau (GSP firmware, RM 570.144) and runtime-suspended at idle. No CUDA. If needed,
set `nvidia_driver_enabled: true` (open modules only; closed modules don't support Blackwell).
Secure Boot is off, so no MOK enrollment. Re-check `runtime_status` after switching.

## Cursor and GitKraken `.deb` URLs
Cursor's download API returned an error and GitKraken's historical URL 404s on 2026-10-12.
Entries are commented out in `ansible/group_vars/all/packages.yml`.

## Platform profile
`/sys/firmware/acpi/platform_profile_choices` = cool quiet balanced performance. TLP's
`PLATFORM_PROFILE_ON_BAT` is `quiet`, not `low-power`.

## Battery sysfs
`BAT0` exposes `charge_*`, `current_now`, `voltage_now` (µA/µV), **not** `power_now`.
`scripts/power-baseline.sh` computes watts from the pair.

## iGPU driver
Arc 140T binds to `i915` on 7.0, not `xe`. Fine, but any guide assuming `xe` sysfs paths won't apply.

## Fingerprint reader
Goodix 27c6:634c; libfprint support unknown, not configured.

## Desktop runs Xorg + i3 on the proprietary NVIDIA driver (2026-10-12)

The dock's display outputs are wired to the RTX PRO 2000, and wlroots handles a
secondary NVIDIA GPU poorly (it was visibly laggy on nouveau). The laptop now
runs lightdm + i3 on Xorg with nvidia-driver-595-open in prime-select "nvidia"
mode: X renders on the dGPU, the laptop panel is reached through the Intel GPU
(PRIME display offload via `prime-offload`), external monitors just work.
Cost: the dGPU never powers down, so battery suffers. Follow-ups:
- measure idle draw on battery (`just power`) and, if it hurts in meetings,
  try `nvidia_prime_mode: on-demand` (X on the iGPU, NVIDIA ports via reverse PRIME).
- sway stays in the manifest under `desktop_session: sway` for the Zenbook.

## Dock link to the U4025QW runs at half bandwidth (2026-10-12)

`boltctl` reports the monitor's USB4 link at 20 Gb/s (2 lanes x 10 Gb/s), and
sway only sees 2560x1080@60, 3840x2160@60 and 5120x2160@30 on it. Native
5120x2160@60 needs a 40 Gb/s link. Check the cable (needs a TB4/USB4 40G
cable) and the monitor's USB-C prioritisation setting. kanshi's docked profile
deliberately sets no mode so it follows whatever the link negotiates.
