---
name: qwen-appliance-verify-host-before-blocking
description: Confirm which machine an address belongs to before reporting the appliance unreachable
metadata:
  type: feedback
---

Report a host unreachable only after confirming the address belongs to that
host. Guessing the appliance's identity from an `/etc/hosts` entry that merely
looked like a laptop produced a wrong address, a wrong "ARP INCOMPLETE, the
runtime is off the network" conclusion, and a turn of offline-only work while
the machine was up and answering.

**Why:** an unreachable-host claim ends a campaign and hands the user a task
only they can perform, so it costs more than most wrong claims and gets less
scrutiny, since a failed ping reads as conclusive. The ping was conclusive about
10.0.0.88 and said nothing about the appliance.

**How to apply:** name the host from [[qwen-appliance-host]] rather than
inferring it. When a name fails to resolve, resolve the name -- `getent hosts`,
`~/.ssh/known_hosts`, `ssh` itself -- rather than substituting a different
machine's address. A negative result about an address is evidence about that
address alone.
