# Installer choices

Recorded so a rebuild reproduces the same base. Everything here is encoded in
`autoinstall/user-data`; this is the human-readable version.

| Choice | Value | Why |
|---|---|---|
| Image | Ubuntu 26.04.1 LTS Desktop, amd64 | Kernel 7.0 for Arrow Lake-H and BE201; desktop image carries hardware enablement the server ISO lacks |
| Delivery | NoCloud on the stick's EFI partition relabelled `CIDATA` + `autoinstall` kernel arg | Laptop is Wi-Fi only; the live installer has no network, so HTTP delivery can't work |
| Source | `ubuntu-desktop-minimal` | No GNOME daemon stack by default; GNOME session kept as emergency fallback |
| Storage | ZFS, encrypted (LUKS keystore), whole `/dev/nvme0n1` | Snapshot rollback; passphrase, not TPM, so it's portable and corporate-IT friendly |
| Swap | encrypted swap partition, installer-sized | Created by the ZFS layout automatically; hibernate is not supported |
| Drivers | third-party drivers **off** | NVIDIA (595 open modules, prime mode nvidia) is installed by roles/hardware, not the installer |
| Codecs | off | handled by Ansible |
| Packages | `openssh-server` only | only thing in the ISO's offline pool that Ansible needs |
| Updates | security | fast install; Ansible does the rest |
| User | from `autoinstall/local.env` (username, hostname, timezone); locale en_US.UTF-8 | identity stays out of the repo |
| SSH | key-only, two keys seeded | password auth off from the first boot |

Temporary secrets in the file (rotate at first login):

- user password (`PASSWORD` in local.env, default `machine-changeme`) → `passwd`
- ZFS passphrase (`ZFS_PASSPHRASE` in local.env, default `machine-changeme`) → `sudo cryptsetup luksChangeKey /dev/zvol/rpool/keystore`

Dataset layout the installer creates: `bpool/BOOT/ubuntu_<id>` on `/boot`,
`rpool/ROOT/ubuntu_<id>` on `/` with child datasets for `/var/*`, `/srv`, `/usr/local`,
and `rpool/USERDATA/home_<id>` on `/home`. `just snapshot` targets the `rpool/ROOT/ubuntu_*`
dataset; `/home` is on its own dataset and is not rolled back with the system.
