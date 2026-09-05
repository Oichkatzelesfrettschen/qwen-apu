/*
 * An LD_PRELOAD barrier that holds a router child at its listener bind.
 *
 * llama-server in router mode spawns its own executable per model section
 * with LLAMA_SERVER_ROUTER_PORT in the child's environment, and the child
 * binds its HTTP port ahead of loading the model and ahead of the READY line
 * it prints to the router. Interposing bind(2) therefore holds the child in
 * the router's LOADING state at a point a test chooses, so a request can be
 * cancelled while the load is provably in flight and a second request can be
 * queued before the load completes, with no sleep asked to land inside a
 * race.
 *
 * The shim acts only where both QWEN_ROUTER_BARRIER_DIR and
 * LLAMA_SERVER_ROUTER_PORT are set, so the router process itself and every
 * other program in the environment bind unchanged. On entry the child writes
 * <dir>/held-<port> carrying its pid, then polls for <dir>/release-<port>
 * every 10 ms. A release file whose first line reads `fail` makes the bind
 * return EADDRINUSE, which the child reports as a listener failure and exits
 * on, so a load failure is produced through the same barrier; any other
 * content lets the real bind proceed.
 */
#define _GNU_SOURCE
#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <time.h>
#include <unistd.h>

typedef int (*bind_function)(int, const struct sockaddr *, socklen_t);

static unsigned bound_port(const struct sockaddr * address) {
    if (address->sa_family == AF_INET) {
        return ntohs(((const struct sockaddr_in *) address)->sin_port);
    }
    if (address->sa_family == AF_INET6) {
        return ntohs(((const struct sockaddr_in6 *) address)->sin6_port);
    }
    return 0;
}

int bind(int descriptor, const struct sockaddr * address, socklen_t length) {
    bind_function real_bind = (bind_function) dlsym(RTLD_NEXT, "bind");
    const char * barrier_directory = getenv("QWEN_ROUTER_BARRIER_DIR");
    if (barrier_directory == NULL || getenv("LLAMA_SERVER_ROUTER_PORT") == NULL) {
        return real_bind(descriptor, address, length);
    }
    unsigned port = bound_port(address);
    if (port == 0) {
        return real_bind(descriptor, address, length);
    }

    char held_path[4096];
    char release_path[4096];
    snprintf(held_path, sizeof held_path, "%s/held-%u", barrier_directory, port);
    snprintf(release_path, sizeof release_path, "%s/release-%u", barrier_directory, port);

    FILE * held = fopen(held_path, "w");
    if (held != NULL) {
        fprintf(held, "%ld\n", (long) getpid());
        fclose(held);
    }

    for (;;) {
        FILE * release = fopen(release_path, "r");
        if (release != NULL) {
            char verdict[16] = { 0 };
            if (fgets(verdict, sizeof verdict, release) == NULL) {
                verdict[0] = '\0';
            }
            fclose(release);
            if (strncmp(verdict, "fail", 4) == 0) {
                errno = EADDRINUSE;
                return -1;
            }
            return real_bind(descriptor, address, length);
        }
        struct timespec pause = { 0, 10 * 1000 * 1000 };
        nanosleep(&pause, NULL);
    }
}
