# The workload-lease patch admitted on the device: both writers, one file, a measured wait

```text
harness=remote/test-vulkan-workload-lease.sh, run on the appliance with the router torn down
patch=patches/llama-server-vulkan-workload-lease.patch sha256 179391b1...
candidate server=$HOME/src/llama.cpp-lease/build-workstation-vulkan/bin/llama-server
                 sha256 8553d425a057e50b773f2927c730aca2c6ad709ff96369f13e3c4fd4dac5cada
source=f280b26983ad0fdb705a0d9ebf0503e76f2899b0 plus the eight-member production series plus this candidate
model=Qwen3.5-0.8B Q8_0, context 256, threads 2
result=served_lease=admitted waited_ms=5890 elapsed_s=6
```

```text
ok lock_basename=vulkan-workload.lock shared by the policy and the service
ok both writers resolve the lock under the session state directory
ok the workload lock variable survives the environment scrub
ok patch_applies=yes sha256=179391b17c8c24a3e7de0a3e7ccf91c5dfec2015f14fce63bf0665fea4516a9e
ok the server arms the lease at startup
ok an idle loaded server leaves the lease free
ok the reply waits for the holder: elapsed=6s hold=6s
ok the acquire names the wait: waited_ms=5890
ok the completion answers after the lease is taken
ok the lease returns once every slot is idle
```

The invariant `evidence/vulkan-workload-lease/README.md` registers is met on the device.
An external holder took the lock for 6 s, the server's own completion returned after 6 s
having logged `waited_ms=5890`, and the loaded but idle server held nothing before and
after, which is the two-sided transition `server_context_impl::update_slots` performs at
its all-idle check.

This is admission alone. The patch stays a candidate under
`QWEN_LLAMA_CANDIDATE_PATCHES=1` and `remote/llama-patch-series.tsv` keeps it in the
`candidate` stage; nothing here promotes it into the production prefix.

## The harness could not run before this campaign repaired its first check

`test-vulkan-workload-lease.sh` refused at its own first check on every branch in the
tree, and the refusal was a reader defect rather than a lease defect:

```text
FAIL qwen-capacity-policy.sh exports no workload lock path
```

The check reads the policy's lock basename with a `sed` expression written against
`export QWEN_VULKAN_WORKLOAD_LOCK="$workload_lease_state_directory/vulkan-workload.lock"`.
`7c20c7e` refactored the policy to assign the path to `workload_lease_path` first and
export that variable, and the expression matched nothing from then on, so
`policy_lock_expression` came back empty and the guard for an empty value fired. The
repair reads the export's right-hand side, follows the one level of variable indirection
it names, and takes the text after the last slash, so a policy that spells the path
either way is read and a policy whose basename diverges from `image-service.py`'s
`LEASE_FILE_NAME` still fails the comparison. Both sides read `vulkan-workload.lock`.

A stale reader that returns nothing is the failure mode the design calls failing open:
the check that exists to prove the two writers name one file was answering about its own
regular expression instead. It sat unnoticed because the served half reports itself
`not run` without a patched build, so no run reached the check with anything to compare.

## The candidate build carries the container's own library path

`remote/build-llama-on-workstation.sh` compiles inside `ubuntu:24.04` with the source
bind-mounted at `/src`, and CMake bakes that absolute path into the executable:

```text
RUNPATH  /src/build-workstation-vulkan/bin:
```

The appliance holds no `/src`, so the shipped binary failed to load
`libllama-server-impl.so` and the served half reported `the server never reported
health`. Running it under `LD_LIBRARY_PATH` naming the directory the libraries were
shipped into is what this run did, and every `ok` line above comes from that invocation.
A build produced by the laptop's own `remote/build-llama-vulkan.sh` carries a RUNPATH
that resolves in place and needs no such variable. The shipping step in the workstation
build script also assumes its destination directory exists: its `rsync` refused with
`mkdir ... failed: No such file or directory` against a fresh path, and the directory was
created by hand before the binaries travelled.

Neither observation is about the patch. Both belong to the workstation build path, and
both are recorded here because the next run of this harness against a container-built
binary meets them again.

## What did not run

The pinned clock cell `manual-gfx1100-fclk933` was not applied: the DPM write needs a
`sudo` timestamp the appliance did not hold. The harness measures a lock transition and
a wait in whole seconds rather than a rate, so the operating point bounds nothing here.
