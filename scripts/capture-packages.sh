#!/usr/bin/env bash
# Second half of drift detection: what is installed that the manifest doesn't know about?
# Also dumps the live package lists into docs/ for the record.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs
apt-mark showmanual | sort > docs/apt-manual.txt
flatpak list --app --columns=application 2>/dev/null | sort > docs/flatpaks.txt || true
snap list 2>/dev/null | awk 'NR>1{print $1}' | sort > docs/snaps.txt || true
echo "wrote docs/apt-manual.txt docs/flatpaks.txt docs/snaps.txt"

python3 - <<'PY'
import subprocess, yaml, re
m = yaml.safe_load(open("ansible/group_vars/all/packages.yml"))
manifest = set()
for k, v in m.items():
    if k.startswith("apt_") and isinstance(v, list):
        manifest |= set(v)
# packages the roles install outside the apt_* lists
manifest |= {"unattended-upgrades","tlp","tlp-rdw","thermald","powertop","intel-media-va-driver-non-free",
             "vainfo","linux-tools-common","fwupd","bolt","flatpak","openssh-server","python3-yaml"}
for d in m.get("deb_downloads", []):
    manifest.add(d["name"])
installed = set(open("docs/apt-manual.txt").read().split())
# ignore the base image's own metapackages and kernels
noise = re.compile(r"^(linux-|ubuntu-desktop|ubuntu-minimal|ubuntu-standard|grub-|shim-|zfs-|libc6|language-pack|gnome-|yaru-|snapd|lib)")
extra = sorted(p for p in installed - manifest if not noise.match(p))
missing = sorted(p for p in manifest - installed)
print(f"\n{len(extra)} manually-installed packages NOT in the manifest:")
for p in extra: print("  +", p)
print(f"\n{len(missing)} manifest packages NOT installed (expected for skipped tags, e.g. personal):")
for p in missing: print("  -", p)
PY
