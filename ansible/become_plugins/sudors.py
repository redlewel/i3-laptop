# laptop-iac: the stock sudo become plugin, with prompt detection that also
# works with sudo-rs. Ubuntu 25.10+ ships sudo-rs, which renders a custom -p
# prompt as "[sudo: <prompt>] Password:". The stock plugin matches with
# startswith() and times out waiting for the prompt. Same options/vars/env as sudo.
from __future__ import annotations

DOCUMENTATION = """
    name: sudors
    short_description: sudo, with prompt detection that also works with sudo-rs (Ubuntu 25.10+)
    description:
        - This become plugin allows your remote/login user to execute commands as another user via the sudo utility.
    author: ansible (@core)
    version_added: "2.8"
    options:
        become_user:
            description: User you 'become' to execute the task
            default: root
            ini:
              - section: privilege_escalation
                key: become_user
              - section: sudo_become_plugin
                key: user
            vars:
              - name: ansible_become_user
              - name: ansible_sudo_user
            env:
              - name: ANSIBLE_BECOME_USER
              - name: ANSIBLE_SUDO_USER
            keyword:
              - name: become_user
        become_exe:
            description: Sudo executable
            default: sudo
            ini:
              - section: privilege_escalation
                key: become_exe
              - section: sudo_become_plugin
                key: executable
            vars:
              - name: ansible_become_exe
              - name: ansible_sudo_exe
            env:
              - name: ANSIBLE_BECOME_EXE
              - name: ANSIBLE_SUDO_EXE
            keyword:
              - name: become_exe
        become_flags:
            description: Options to pass to sudo
            default: -H -S -n
            ini:
              - section: privilege_escalation
                key: become_flags
              - section: sudo_become_plugin
                key: flags
            vars:
              - name: ansible_become_flags
              - name: ansible_sudo_flags
            env:
              - name: ANSIBLE_BECOME_FLAGS
              - name: ANSIBLE_SUDO_FLAGS
            keyword:
              - name: become_flags
        become_pass:
            description: Password to pass to sudo
            required: False
            vars:
              - name: ansible_become_password
              - name: ansible_become_pass
              - name: ansible_sudo_pass
            env:
              - name: ANSIBLE_BECOME_PASS
              - name: ANSIBLE_SUDO_PASS
            ini:
              - section: sudo_become_plugin
                key: password
"""

from ansible.module_utils.common.text.converters import to_bytes
from ansible.plugins.become.sudo import BecomeModule as _Sudo


class BecomeModule(_Sudo):
    name = 'sudors'

    def check_password_prompt(self, b_output):
        if self.prompt:
            b_prompt = to_bytes(self.prompt).strip()
            return any(b_prompt in line for line in b_output.splitlines())
        return False
