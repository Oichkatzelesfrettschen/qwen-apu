# The appliance's declared expansion.
#
# A checkout of this repository is the complete declaration of the appliance,
# and these targets expand it into one ignored runtime tree beside it, the
# runtime root remote/qwen-home.sh names as QWEN_HOME (default .runtime under
# this directory). Every target calls a checked-in script, so a recipe here
# states which script owns a component rather than how it is built, and
# `make status` enumerates every component the repository claims ownership
# of, present or absent, into $(QWEN_HOME)/manifest.tsv.
#
# QWEN_HOME on the command line moves the root: `make QWEN_HOME=/mnt/x bootstrap`.

SHELL := /bin/sh
REMOTE := remote
QWEN_HOME ?= $(shell $(REMOTE)/qwen-home.sh print qwen_home)
export QWEN_HOME

.PHONY: bootstrap install-searxng verify-searxng install-ryzenadj \
        install-image-runtime install-shaderc install-models build-llama \
        status doctor verify verify-layout verify-components verify-live \
        uninstall purge purge-legacy \
        install-sudo-policy verify-sudo-policy uninstall-sudo-policy \
        check-paths test

# The root and its marker; every install target lays the root out first.
bootstrap:
	$(REMOTE)/runtime-root.sh init

install-searxng: bootstrap
	$(REMOTE)/install-searxng.sh install

verify-searxng:
	$(REMOTE)/install-searxng.sh verify

install-ryzenadj: bootstrap
	$(REMOTE)/build-ryzenadj.sh

install-image-runtime: bootstrap
	$(REMOTE)/build-stable-diffusion-vulkan.sh

install-shaderc: bootstrap
	$(REMOTE)/fetch-shaderc-toolchain.sh

# The pinned checkpoints the registry serves; each download script pins a
# revision, a byte count, and a SHA-256 and verifies an existing file in place.
install-models: bootstrap
	$(REMOTE)/download-qwen38-2b-distill-q4km.sh
	$(REMOTE)/download-qwen35-08b-q80.sh
	$(REMOTE)/download-qwen38-4b-distill-q4km.sh
	$(REMOTE)/download-qwen35-4b-q4km.sh
	$(REMOTE)/download-qwen35-4b-mmproj.sh

build-llama: bootstrap
	$(REMOTE)/build-llama-vulkan.sh

# Every component the repository claims, present or absent, as one manifest.
status:
	$(REMOTE)/runtime-root.sh status

# The inverse: predecessor paths outside the root, foreign entries under it,
# and transient system state, reported and untouched.
doctor:
	$(REMOTE)/runtime-root.sh doctor

# Three verifications answering three questions and failing for three
# reasons. verify-layout reads the structure alone -- the marker, its schema,
# its binding to this checkout, the layout directories, and any entry under
# the root outside the layout -- beside the lexical ratchet. verify-components
# reads the identity of every installed component out of the manifest and
# names each present, absent, or mutable, beside the sudo policy.
# verify-live reads the transient system state and the legacy summary and
# passes where a node is absent, since the workstation carries no amdgpu
# sysfs. `make verify` is their union.
verify-layout:
	$(REMOTE)/runtime-root.sh verify-layout
	$(REMOTE)/check-appliance-paths.py

verify-components: verify-sudo-policy
	$(REMOTE)/runtime-root.sh status >/dev/null
	$(REMOTE)/runtime-root.sh verify-components

verify-live:
	$(REMOTE)/runtime-root.sh verify-live

verify: verify-layout verify-components verify-live

# uninstall keeps state/ and models/; purge removes the root whole and
# requires QWEN_RUNTIME_ROOT_CONFIRM=$(QWEN_HOME); purge-legacy removes the
# enumerated predecessor paths outside the root and requires
# QWEN_PURGE_LEGACY_CONFIRM=yes. Each refuses a directory carrying no
# runtime-root marker.
uninstall:
	$(REMOTE)/runtime-root.sh uninstall

purge:
	$(REMOTE)/runtime-root.sh purge

purge-legacy:
	$(REMOTE)/runtime-root.sh purge-legacy

# The one persistent root-owned object, reproducible from its checked-in
# source: installed at mode 0440 and required to hash to that source.
install-sudo-policy:
	$(REMOTE)/sudo-policy.sh install

verify-sudo-policy:
	$(REMOTE)/sudo-policy.sh verify

uninstall-sudo-policy:
	$(REMOTE)/sudo-policy.sh uninstall

# The lexical ratchet: a production script names no owned storage outside
# the root.
check-paths:
	$(REMOTE)/check-appliance-paths.py

test:
	$(REMOTE)/repository-quality-gates.sh
