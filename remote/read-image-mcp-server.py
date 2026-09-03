#!/usr/bin/env python3
"""Report the image server a generated MCP configuration carries.

llama-server hands each router child the section's own MCP configuration and
the child spawns whatever `mcpServers` names, so that file rather than a
generator marker is what decides whether a section reaches the image runtime.
Two readers act on it -- qwen-capacity-policy.sh rejoins it to the preset's
image marker before the exec, and the image launch library reads the deadline
and the five child settings out of it -- and one parser keeps the two from
disagreeing about what an image server is.

The output is `name=value` lines a POSIX shell reads with sed. A configuration
naming no image server prints `image_server=absent` and exits 0, which is the
state every ordinary section carries; an image server missing one of the names
its child reads, or bounding its call and its own socket read at two different
numbers, exits 1 with the reason on stderr.
"""

import json
import sys

REQUIRED_ENVIRONMENT = (
    "QWEN_IMAGE_LANGUAGE_PROFILE",
    "QWEN_IMAGE_PROFILE",
    "QWEN_IMAGE_TOKEN_KEY_FILE",
    "QWEN_IMAGE_STATE_DIR",
    "QWEN_IMAGE_SERVICE_SOCKET",
    "QWEN_IMAGE_PROFILES_JSON",
    "QWEN_IMAGE_MCP_TIMEOUT_S",
)


def main(argv):
    if len(argv) != 2:
        print("usage: read-image-mcp-server.py CONFIGURATION", file=sys.stderr)
        return 2
    configuration_path = argv[1]
    try:
        with open(configuration_path, encoding="utf-8") as handle:
            configuration = json.load(handle)
    except (OSError, ValueError) as reason:
        print(
            "the MCP configuration is unreadable: %s: %s"
            % (configuration_path, reason),
            file=sys.stderr,
        )
        return 1
    # The question this reader answers is whether an image server is armed, and
    # a configuration naming no servers at all answers it truthfully with `no`.
    # Refusing that shape instead would make the image rejoin the first reader
    # of every web configuration, which llama-server's own child startup already
    # is.
    servers = configuration.get("mcpServers")
    if not isinstance(servers, dict):
        print("image_server=absent")
        return 0
    image = servers.get("image")
    if image is None:
        print("image_server=absent")
        return 0
    if not isinstance(image, dict):
        print(
            "the image server is not an object: %s" % configuration_path,
            file=sys.stderr,
        )
        return 1
    environment = image.get("env")
    if not isinstance(environment, dict):
        print(
            "the image server names no env object: %s" % configuration_path,
            file=sys.stderr,
        )
        return 1
    for name in REQUIRED_ENVIRONMENT:
        if not environment.get(name):
            print(
                "the image server names no %s: %s" % (name, configuration_path),
                file=sys.stderr,
            )
            return 1
    try:
        router_limit = int(image["timeout_ms"])
        child_limit = float(environment["QWEN_IMAGE_MCP_TIMEOUT_S"])
    except (KeyError, TypeError, ValueError):
        print(
            "the image server bounds its call with no readable timeout_ms: %s"
            % configuration_path,
            file=sys.stderr,
        )
        return 1
    # The router bounds the call at timeout_ms and the child bounds its own
    # socket read at QWEN_IMAGE_MCP_TIMEOUT_S. Two numbers for one deadline let
    # the router wait past the point the child gave up, so they have to agree.
    if abs(router_limit / 1000.0 - child_limit) > 0.001:
        print(
            "the image server bounds its call at %d ms and its own read at %g s"
            % (router_limit, child_limit),
            file=sys.stderr,
        )
        return 1
    print("image_server=present")
    print("image_timeout_ms=%d" % router_limit)
    for name in REQUIRED_ENVIRONMENT:
        print("%s=%s" % (name, environment[name]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
