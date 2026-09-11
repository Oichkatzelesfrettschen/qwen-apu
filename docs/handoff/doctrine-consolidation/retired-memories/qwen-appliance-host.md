---
name: qwen-appliance-host
description: The Raven2 inference appliance is the SSH host qwen-laptop; the repository writes it as qwen-laptop
metadata:
  type: project
---

The Raven2 laptop that runs the Qwen appliance answers to `qwen-laptop`
(equivalently `qwen-laptop.local`), which is an HP 14-dk1xxx carrying the
Athlon Silver 3050U. Every `remote/` script executes from
`~/qwen-laptop-setup/remote/` there, and `rsync -a remote/
eirikr@qwen-laptop:~/qwen-laptop-setup/remote/` is what makes a workstation-side
edit real.

The repository sanitizes that name to `qwen-laptop` in checked-in text, so
`qwen-laptop` appears throughout `CLAUDE.md` and `evidence/` and resolves to
nothing. The name lives only in `~/.ssh/known_hosts`; it is absent from
`/etc/hosts` and from `~/.ssh/config`, and it reaches DNS through mDNS.

`/etc/nsswitch.conf` orders `hosts:` as `mymachines mdns_minimal
[NOTFOUND=return] resolve [!UNAVAIL=return] files`, so `files` sits after two
terminating entries and `/etc/hosts` is never consulted for a `.local` name.
Grepping `/etc/hosts` for the appliance therefore returns other machines and
finds nothing relevant: `x130e` at 10.0.0.88 is a different laptop, and treating
it as the appliance produces an unreachable address and a false conclusion that
the runtime is offline. Resolve the appliance with `getent hosts qwen-laptop`
or simply `ssh qwen-laptop`. See [[qwen-appliance-verify-host-before-blocking]].
