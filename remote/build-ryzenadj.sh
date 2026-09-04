#!/bin/sh
set -eu
script_directory=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=remote/qwen-home.sh
. "$script_directory/qwen-home.sh"

# RyzenAdj built from one pinned revision into the appliance's own bin directory.
#
# power-envelope.sh writes the package budget through this binary, so the binary
# is an appliance artifact with an identity rather than a package the
# distribution happens to carry. The revision below is the commit this tree read
# when it wrote the SMU message table in evidence/power-envelope/README.md:
# `lib/cpuid.c` maps CPUID family 0x17 model 32 onto `FAM_DALI`, and `lib/api.c`
# gives that family the message IDs the evidence names. A later revision may
# route a family differently, so the build pins the revision and refuses a tree
# that resolved to another one.
#
# The build itself needs no privilege. `CMakeLists.txt` links libpci, so the
# development headers are the one system dependency: `libpci-dev` on the
# appliance's Debian-derived userspace, `pciutils-devel` on Fedora, `pciutils`
# on Arch. The install is a copy rather than a symlink into the build tree, so
# the artifact keeps working across a rebuild or a move of the source.
#
# Running the binary needs root, because it reaches the SMN index and data
# registers through PCI configuration space and the power-metrics table through
# `/dev/mem`. power-envelope.sh supplies that with `sudo -n`; this script never
# needs it and never asks for it.
#
# The build compiles a handful of C files and allocates nothing on the Vulkan
# device, so it takes the device from nothing. It does take both cores for the
# length of the compile, which is the resource a timed measurement arm is
# sensitive to, so it belongs outside a measurement window rather than inside
# one.

usage() {
    printf 'usage: %s [SOURCE_DIRECTORY]\n' "$0" >&2
    printf 'environment: QWEN_RYZENADJ_REVISION QWEN_RYZENADJ_REPOSITORY QWEN_RYZENADJ_INSTALL\n' >&2
    exit 2
}

if [ "$#" -gt 1 ]; then
    usage
fi

ryzenadj_repository=${QWEN_RYZENADJ_REPOSITORY:-https://github.com/FlyGoat/RyzenAdj.git}
ryzenadj_revision=${QWEN_RYZENADJ_REVISION:-5775fc3e6dbb25c7030ee2d100a1bdd6e8bf2d0a}
ryzenadj_source=${1:-${QWEN_RYZENADJ_SOURCE:-"$qwen_home_ryzenadj_source"}}
# The build directory sits outside the checkout, because the cleanliness check
# below refuses an untracked file and a build tree inside the source would make
# every second run refuse its own first run's output.
ryzenadj_build=${QWEN_RYZENADJ_BUILD:-"$qwen_home_cache/ryzenadj-build"}
ryzenadj_install=${QWEN_RYZENADJ_INSTALL:-"$qwen_home_ryzenadj"}

case $ryzenadj_revision in
    ????????????????????????????????????????)
        case $ryzenadj_revision in
            *[!0-9a-f]*)
                printf 'the pinned revision is not 40 hexadecimal characters: %s\n' \
                    "$ryzenadj_revision" >&2
                exit 2
                ;;
        esac
        ;;
    *)
        printf 'the pinned revision is not 40 hexadecimal characters: %s\n' \
            "$ryzenadj_revision" >&2
        exit 2
        ;;
esac

for required_command in git cmake cc; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        printf 'a required command is absent: %s\n' "$required_command" >&2
        exit 2
    fi
done

# The libpci headers are checked by name so a missing package is a named
# refusal ahead of a CMake configure error that buries it.
libpci_present=0
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists libpci 2>/dev/null; then
    libpci_present=1
fi
for libpci_header in /usr/include/pci/pci.h /usr/local/include/pci/pci.h; do
    if [ -r "$libpci_header" ]; then
        libpci_present=1
    fi
done
if [ "$libpci_present" -eq 0 ]; then
    printf 'the libpci development headers are absent; install libpci-dev (Debian and Ubuntu), pciutils-devel (Fedora), or pciutils (Arch)\n' >&2
    exit 2
fi

if [ ! -d "$ryzenadj_source/.git" ]; then
    printf 'ryzenadj_clone=%s revision=%s destination=%s\n' \
        "$ryzenadj_repository" "$ryzenadj_revision" "$ryzenadj_source"
    mkdir -p -- "$(dirname -- "$ryzenadj_source")"
    git clone -- "$ryzenadj_repository" "$ryzenadj_source"
fi

if ! git -C "$ryzenadj_source" cat-file -e "$ryzenadj_revision^{commit}" 2>/dev/null; then
    git -C "$ryzenadj_source" fetch --tags origin
fi
git -C "$ryzenadj_source" checkout --quiet --detach "$ryzenadj_revision"

resolved_revision=$(git -C "$ryzenadj_source" rev-parse HEAD)
if [ "$resolved_revision" != "$ryzenadj_revision" ]; then
    printf 'the source tree resolved to %s where %s is pinned: %s\n' \
        "$resolved_revision" "$ryzenadj_revision" "$ryzenadj_source" >&2
    exit 2
fi

# The comparison resolves what exists and leaves what does not alone, so a
# refused build directory is refused without this script first creating it
# inside the checkout it is protecting.
resolved_source=$(CDPATH='' cd -- "$ryzenadj_source" && pwd -P)
if [ -d "$ryzenadj_build" ]; then
    resolved_build=$(CDPATH='' cd -- "$ryzenadj_build" && pwd -P)
else
    case $ryzenadj_build in
        /*) resolved_build=$ryzenadj_build ;;
        *) resolved_build=$(pwd -P)/$ryzenadj_build ;;
    esac
fi
case $resolved_build in
    "$resolved_source" | "$resolved_source"/*)
        printf 'the build directory sits inside the source checkout, which the revision check below reads as an unclean tree: %s\n' \
            "$resolved_build" >&2
        exit 2
        ;;
esac

# A modified tree builds something the revision does not name, so the identity
# the manifest would record would be false.
if [ -n "$(git -C "$ryzenadj_source" status --porcelain)" ]; then
    printf 'the source tree carries uncommitted changes, so the built binary would not be revision %s: %s\n' \
        "$ryzenadj_revision" "$ryzenadj_source" >&2
    exit 2
fi

cmake -S "$ryzenadj_source" -B "$ryzenadj_build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$ryzenadj_build" --parallel "$(nproc 2>/dev/null || printf '2\n')"

built_binary=$ryzenadj_build/ryzenadj
if [ ! -x "$built_binary" ]; then
    printf 'the build produced no executable at %s\n' "$built_binary" >&2
    exit 1
fi

# `--help` parses arguments and touches neither PCI configuration space nor
# /dev/mem, so it proves the binary links and runs without any privilege.
if ! "$built_binary" --help >/dev/null 2>&1; then
    printf 'the built binary failed to run its own --help: %s\n' "$built_binary" >&2
    exit 1
fi

mkdir -p -- "$(dirname -- "$ryzenadj_install")"
install_temporary=$ryzenadj_install.new.$$
cp -- "$built_binary" "$install_temporary"
chmod 0755 "$install_temporary"
mv -- "$install_temporary" "$ryzenadj_install"

installed_digest=$(LC_ALL=C sha256sum "$ryzenadj_install" | awk '{ print $1; exit }')
printf 'ryzenadj_built=%s revision=%s sha256=%s\n' \
    "$ryzenadj_install" "$ryzenadj_revision" "$installed_digest"
printf 'ryzenadj_next=run `sudo -v` and then `%s --info` to read the platform limits\n' \
    "$ryzenadj_install"
