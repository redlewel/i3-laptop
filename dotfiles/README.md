# dotfiles (baseline)

A minimal chezmoi source: a generic i3 config wired to the tools the playbook
installs, plus Ubuntu's `fd`/`bat` name fixes. It exists so a fresh machine is
usable after one run. It is **not** a place for personal configuration.

To use your own dotfiles, set `dotfiles_source` in
`ansible/group_vars/all/local.yml` (gitignored) to either a git URL of a
chezmoi-formatted repo or a path on the target. The role then applies that
instead of this directory. Set `dotfiles_enabled: false` to leave `~` alone.
