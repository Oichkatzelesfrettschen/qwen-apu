# shellcheck shell=sh

# One reading of the deployment bundle namespace, sourced by every script that
# assembles, activates, verifies, or resolves a bundle. A bundle name is one
# path component matching [A-Za-z0-9][A-Za-z0-9._-]*, so the leading
# alphanumeric keeps it clear of every dot-prefixed entry the root owns --
# .activate.lock, the .staging parent and its bundle.XXXXXX leaves, . and .. --
# and the explicit names keep it clear of the role and generation links. A
# reader admitting a name another reader refuses is what lets a directory
# planted as .activate.lock or .staging reach an activation or a launch, so
# the four readers share this function rather than repeating a case pattern.
#
# The function returns 0 or 1 and prints nothing, leaving each caller its own
# message and exit status.

deployment_bundle_name_is_valid() {
    case $1 in
        '' | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]* | deployment-current | \
            deployment-previous | deployment-state | deployment-state.*)
            return 1
            ;;
    esac
    return 0
}
