#!/usr/bin/env bash
# Render autoinstall/user-data and meta-data from user-data.tmpl + local.env.
# Outputs are gitignored: they carry the temporary passwords and your SSH keys.
set -euo pipefail
cd "$(dirname "$0")/.."
env_file=autoinstall/local.env
[ -f "$env_file" ] || { echo "missing $env_file (copy autoinstall/local.env.example)"; exit 1; }
set -a   # export everything local.env defines, the python below reads the environment
# shellcheck disable=SC1090
. "$env_file"
REALNAME=${REALNAME:-$USERNAME}; TIMEZONE=${TIMEZONE:-Etc/UTC}; LOCALE=${LOCALE:-en_US.UTF-8}
KEYBOARD=${KEYBOARD:-us}; DISK=${DISK:-/dev/nvme0n1}
set +a
: "${HOSTNAME:?}" "${USERNAME:?}" "${PASSWORD:?}" "${ZFS_PASSPHRASE:?}" "${AUTHORIZED_KEY_FILES:?}"

hash=$(openssl passwd -6 "$PASSWORD")
keys=""
for f in $AUTHORIZED_KEY_FILES; do
  [ -r "$f" ] || { echo "cannot read key file $f"; exit 1; }
  keys+="      - \"$(tr -d '\n' < "$f")\""$'\n'
done
keys=${keys%$'\n'}

python3 - "$hash" "$keys" <<'EOF'
import sys, os
hash_, keys = sys.argv[1], sys.argv[2]
tmpl = open('autoinstall/user-data.tmpl').read()
vals = {
  'LOCALE': os.environ['LOCALE'], 'KEYBOARD': os.environ['KEYBOARD'], 'TIMEZONE': os.environ['TIMEZONE'],
  'HOSTNAME': os.environ['HOSTNAME'], 'USERNAME': os.environ['USERNAME'], 'REALNAME': os.environ['REALNAME'],
  'PASSWORD_HASH': hash_, 'AUTHORIZED_KEYS': keys, 'ZFS_PASSPHRASE': os.environ['ZFS_PASSPHRASE'], 'DISK': os.environ['DISK'],
}
for k, v in vals.items():
    tmpl = tmpl.replace('@@%s@@' % k, v)
assert '@@' not in tmpl, 'unreplaced placeholder'
open('autoinstall/user-data', 'w').write(tmpl)
open('autoinstall/meta-data', 'w').write('instance-id: %s-autoinstall\nlocal-hostname: %s\n' % (os.environ['HOSTNAME'], os.environ['HOSTNAME']))
open('autoinstall/vendor-data', 'w').write('')
print('rendered autoinstall/user-data and meta-data for', os.environ['HOSTNAME'])
EOF
if command -v cloud-init >/dev/null; then cloud-init schema --config-file autoinstall/user-data 2>/dev/null | tail -1; fi
