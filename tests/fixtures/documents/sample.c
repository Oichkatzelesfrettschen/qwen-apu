/* The submission limit the profile exports, read by the Vulkan backend. */
#include <stdint.h>

enum { MAX_NODES_PER_SUBMIT = 16 };

uint32_t submit_limit(uint32_t requested) {
    return requested < MAX_NODES_PER_SUBMIT ? requested : MAX_NODES_PER_SUBMIT;
}
