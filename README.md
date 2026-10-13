# laptop-iac

Declarative, reproducible configuration for a Dell Pro Max 14 Premium (MA14250) work laptop
running Ubuntu 26.04 LTS. Clone, run one command, get the machine back. A second command
answers "does the live machine still match the repo?"

## Architecture

| Layer | Tool | What it owns |
|---|---|---|
| 0 Install | autoinstall (`autoinstall/`) | partitioning (ZFS, encrypted), user, SSH |
| 1 System | Ansible, local or over SSH (`ansible/`) | apt, vendor repos, services, display manager, power, NVIDIA |
| 2 User | chezmoi | generic baseline in `dotfiles/`; your own repo via `dotfiles_source` in `local.yml` |
| 3 Data | restic (`backup/`) | home backup, independent of config |

Rollback is a ZFS snapshot: `just apply` snapshots the root dataset before every run.

## Hardware (as found 2026-10-12)

| Component | Found |
|---|---|
| CPU | Intel Core Ultra 7 265H, 16 cores (6P+8E+2LPE), Arrow Lake-H |
| RAM | 32 GB LPDDR5x 8533 |
| iGPU | Intel Arc 140T, driver **i915** on kernel 7.0 (not xe) |
| dGPU | NVIDIA RTX PRO 2000 Blackwell 8 GB, **drives the dock's display outputs**; nvidia-driver-595-open, prime mode `nvidia` |
| Panel | 14" 1920x1200 IPS, `intel_backlight` (no OLED, no PWM concern) |
| Wi-Fi | Intel BE201 Wi-Fi 7, 6 GHz band present |
| Disk | 1 TB SK hynix PC811 NVMe |
| Firmware | BIOS 1.13.1, Secure Boot **disabled**, TPM 2.0 |
| Sleep | s2idle only |
| Dock | Dell U4025QW over USB4, authorized by bolt; 5120x2160 through the NVIDIA GPU |

Full probe output: `docs/hardware-report-2026-10-12.txt`. Re-run with `just hw`.

## Install (what was actually done)

1. Ubuntu **26.04.1 Desktop** ISO (`ubuntu-26.04.1-desktop-amd64.iso`) written to USB with `dd`.
2. `cp autoinstall/local.env.example autoinstall/local.env`, fill in hostname, user, key
   files (passwords default to `machine-changeme`), then `just autoinstall` renders
   `autoinstall/user-data` + `meta-data` (gitignored, since they carry your keys and the
   temporary passwords). Copy both onto the stick's own 5 MB EFI partition (`/dev/sda2`)
   and relabel it `CIDATA` with `fatlabel`. cloud-init's NoCloud datasource finds it; no
   network is needed during the install.
3. At the GRUB menu: press `e`, append `autoinstall` to the `linux` line before `---`, boot.
4. Installer choices encoded in the file: `ubuntu-desktop-minimal` (GNOME kept as fallback
   session), ZFS layout with passphrase (= LUKS keystore + encrypted swap partition),
   no third-party drivers from the installer (Ansible installs NVIDIA), `openssh-server` only.

Details and rationale: `docs/installer-choices.md`.

### Fresh laptop, start to finish

1. Autoinstall as above. First boot lands in GNOME (gdm) with the temporary passwords.
2. Rotate them:
   ```bash
   passwd
   sudo cryptsetup luksChangeKey /dev/zvol/rpool/keystore
   ```
3. Run the playbook once. Either from another machine over SSH
   (`just apply-remote <ip>`, become password prompted), or locally:
   ```bash
   sudo apt install -y git ansible just
   git clone <this repo> ~/laptop-iac && cd ~/laptop-iac
   cp ansible/group_vars/all/local.yml.example ansible/group_vars/all/local.yml   # user, tz, dotfiles repo
   just apply
   ```
   One pass is enough: every failure seen on 2026-10-12 has its fix in the roles
   (sudo-rs prompt, stale apt lists, display-manager preseed, chezmoi force-apply).
4. **Reboot.** The NVIDIA driver, lightdm and the touchpad config take effect at boot.
   Log into i3 at the lightdm greeter.
5. Per-user, interactive, not automatable: `sudo tailscale up` (SSO), Slack and Chrome
   logins, restore `~/.ssh` and GPG keys, `autorandr --save docked` with the monitor
   arranged in arandr, `feh --bg-fill <image>` for a wallpaper.

## Running

```bash
just apply            # local, work profile (skips `personal`), ZFS snapshot first
just check            # drift: --check --diff; clean output == repo matches machine
just capture          # pull live state back: package lists + chezmoi re-add
just apply-remote IP  # same as apply, over SSH
just snapshots        # list rollback points
just rollback SNAP    # zfs rollback -r, then reboot
```

Drift is "clean" when `just check` reports no changes **and** `just capture` lists nothing
installed that the manifest doesn't know about.

`dotfiles/` is only a generic baseline (an i3 config wired to the installed tools). Personal
configuration belongs in your own repo: point `dotfiles_source` at it in `local.yml`, or set
`dotfiles_enabled: false` to keep the playbook out of `~`.

Dotfiles are applied with `chezmoi apply --force`: the source wins. Edit a managed file on
the laptop (nvim's `lazy-lock.json` after `:Lazy update`, for instance) and `just capture`
it back before the next apply, or the apply overwrites it. New files, such as autorandr
profiles, need `chezmoi add <path> --source dotfiles` once.

Tags: `base repos packages desktop hardware power dev dotfiles work personal`.
`--skip-tags personal` is the work profile.

## Public / private split

This repo is public. Never commit: Wi-Fi PSKs, Tailscale keys or tailnet names, internal
hostnames or apt mirrors, proxy URLs, anything naming internal company tooling, SSH/GPG
private keys. Those live in a separate private `work-overlay` repo with sops+age encrypted
vars. The age key lives in a password manager, never in either repo.

## Known gaps

- **Webcam**: OmniVision OV08F4 sensor behind Intel IPU6, no kernel driver. Use a USB webcam.
- **Hibernate**: not possible on ZFS (swap-on-zvol is unsafe). s2idle only; measure overnight drain.
- **Cursor / GitKraken**: no stable `.deb` URL resolved yet; placeholders in `packages.yml`.
- **Platform profile**: firmware exposes cool/quiet/balanced/performance, no low-power. TLP uses `balanced` + `balance_power` on battery (`quiet`/`power` felt laggy).
- **Battery with the dGPU always on**: prime mode `nvidia` keeps the RTX powered. Unmeasured; `nvidia_prime_mode: on-demand` is the fallback if meetings on battery suffer.
- **Dock link**: the U4025QW negotiated only 20 Gb/s through the dock earlier; check the cable if 5K60 drops out.

More in `docs/known-gaps.md`.

## Open decisions

- Classify GitKraken, Remmina, RustDesk, OBS as work / personal / both.
- Does the personal Zenbook share this repo (tag-gated) or get its own?
- Nix + home-manager (Phase 4) only after `nix run nixpkgs#hello` passes on the corporate network.

## Ubuntu 26.04 note: sudo-rs

26.04 ships sudo-rs, which prints Ansible's custom password prompt as
`[sudo: <prompt>] Password:`. The stock `sudo` become plugin does not recognise
that and times out on every privileged task. `ansible/become_plugins/sudors.py`
is a one-method subclass that fixes the match, and `ansible.cfg` selects it with
`become_method = sudors`. Nothing on the target changes.

## Per-machine settings

`ansible/machines/<dmi-product-name>.yml` holds what differs between laptops: NVIDIA on or
off and its driver version, the prime mode, and the TLP platform profiles. The playbook
slugs `ansible_facts.product_name` ("Dell Pro Max 14 Premium MA14250" becomes
`dell-pro-max-14-premium-ma14250.yml`) and falls back to `machines/default.yml`, which is
conservative: no NVIDIA, balanced power. The dGPU's PCI address is detected, not configured.
Everything else in the repo is generic Ubuntu 26.04.

## Desktop flavour

`ansible/group_vars/all/settings.yml` selects the stack: `desktop_session: i3`
with `display_manager: lightdm` (Xorg, what the Dell runs), or
`desktop_session: sway` with `display_manager: greetd` (Wayland, the original
design). Package lists are split accordingly in `packages.yml`, and
`roles/hardware` installs the NVIDIA open driver and sets the prime mode when
`nvidia_driver_enabled` is true. See docs/known-gaps.md for why the Dell is on Xorg.
