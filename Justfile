# laptop-iac. `just` lists targets.
set shell := ["bash", "-euo", "pipefail", "-c"]

inv := "ansible/inventory.yml"
play := "ansible/site.yml"

default:
    @just --list

# Apply the work profile to this machine (snapshots root first).
apply: snapshot
    ansible-playbook -i {{inv}} {{play}} -l localhost -K --skip-tags personal

# Apply everything, including personal apps.
apply-all: snapshot
    ansible-playbook -i {{inv}} {{play}} -l localhost -K

# Drift detection: a clean run means the repo describes the machine.
check:
    ansible-playbook -i {{inv}} {{play}} -l localhost -K --check --diff --skip-tags personal

# Same, but drive a remote laptop over SSH (used while building the repo).
apply-remote HOST:
    IAC_HOST={{HOST}} ansible-playbook -i {{inv}} {{play}} -l laptop -K --skip-tags personal

check-remote HOST:
    IAC_HOST={{HOST}} ansible-playbook -i {{inv}} {{play}} -l laptop -K --check --diff --skip-tags personal

# --- rollback: ZFS snapshots of the root dataset ---------------------------

root_ds := `zfs list -H -o name -r rpool/ROOT 2>/dev/null | grep '^rpool/ROOT/ubuntu_' | head -1 || true`

snapshot:
    #!/usr/bin/env bash
    set -euo pipefail
    ds="{{root_ds}}"
    if [ -z "$ds" ]; then echo "no ZFS root dataset found; skipping snapshot"; exit 0; fi
    snap="$ds@iac-$(date +%Y%m%d-%H%M%S)"
    sudo zfs snapshot "$snap" && echo "snapshot: $snap"

snapshots:
    zfs list -t snapshot -o name,used,creation -s creation -r rpool/ROOT

# Roll the root dataset back to SNAP (full name, e.g. rpool/ROOT/ubuntu_abc@iac-20261012-1900). Reboot after.
rollback SNAP:
    sudo zfs rollback -r {{SNAP}}
    @echo "rolled back to {{SNAP}}; reboot to run on it"

# --- capture / inspect -------------------------------------------------------

# Pull live state back into the repo: package lists + dotfiles.
capture:
    ./scripts/capture-packages.sh
    chezmoi re-add --source "$PWD/dotfiles"

hw:
    ./scripts/hardware-report.sh

# Render autoinstall/user-data from user-data.tmpl + local.env (both passwords, SSH keys).
autoinstall:
    ./scripts/render-autoinstall.sh

power:
    ./scripts/power-baseline.sh

lint:
    #!/usr/bin/env bash
    if command -v ansible-lint >/dev/null; then ansible-lint ansible/site.yml; fi
    ansible-playbook -i {{inv}} {{play}} -l localhost --syntax-check
