/* Exhaustive and randomized check of the two int24 forms against the signed
   4x8 dot product dotPacked4x8EXT computes, in the same integer widths the
   GLSL uses. */
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

static int32_t reference_dot(uint32_t a, uint32_t b) {
    int32_t sum = 0;
    for (int byte = 0; byte < 4; ++byte) {
        int32_t av = (int8_t)((a >> (8 * byte)) & 0xFFu);
        int32_t bv = (int8_t)((b >> (8 * byte)) & 0xFFu);
        sum += av * bv;
    }
    return sum;
}

static int32_t int24_general(uint32_t packed_a, uint32_t packed_b) {
    uint32_t au = packed_a ^ 0x80808080u;
    uint32_t bu = packed_b ^ 0x80808080u;
    uint32_t a0 = au & 0xFFu, a1 = (au >> 8) & 0xFFu, a2 = (au >> 16) & 0xFFu, a3 = (au >> 24) & 0xFFu;
    uint32_t b0 = bu & 0xFFu, b1 = (bu >> 8) & 0xFFu, b2 = (bu >> 16) & 0xFFu, b3 = (bu >> 24) & 0xFFu;
    uint32_t sum_ab = a0 * b0 + a1 * b1 + a2 * b2 + a3 * b3;
    uint32_t sum_a = a0 + a1 + a2 + a3;
    uint32_t sum_b = b0 + b1 + b2 + b3;
    return (int32_t)sum_ab - (int32_t)(128u * (sum_a + sum_b)) + 65536;
}

/* The Q4_K and Q5_K specialization, over the four words of one call. */
static int32_t int24_nibble(const uint32_t quants[4], const uint32_t activations[4]) {
    uint32_t sum_nb = 0;
    uint32_t sum_n = 0;
    for (int w = 0; w < 4; ++w) {
        uint32_t biased = activations[w] ^ 0x80808080u;
        for (int byte = 0; byte < 4; ++byte) {
            uint32_t n = (quants[w] >> (8 * byte)) & 0xFFu;
            uint32_t b = (biased >> (8 * byte)) & 0xFFu;
            sum_nb += n * b;
            sum_n += n;
        }
    }
    return (int32_t)sum_nb - (int32_t)(sum_n << 7);
}

int main(void) {
    /* Every byte pair of the general form, which covers the whole input domain
       one lane at a time. */
    for (int a = 0; a < 256; ++a) {
        for (int b = 0; b < 256; ++b) {
            uint32_t pa = (uint32_t)a, pb = (uint32_t)b;
            if (int24_general(pa, pb) != reference_dot(pa, pb)) {
                printf("general lane mismatch a=%d b=%d\n", a, b);
                return 1;
            }
        }
    }

    srand(20260903);
    for (long i = 0; i < 4000000; ++i) {
        uint32_t pa = ((uint32_t)rand() << 17) ^ (uint32_t)rand();
        uint32_t pb = ((uint32_t)rand() << 17) ^ (uint32_t)rand();
        if (int24_general(pa, pb) != reference_dot(pa, pb)) {
            printf("general mismatch a=%08x b=%08x\n", pa, pb);
            return 1;
        }
    }

    /* The specialization only claims the domain repack4 produces: Q4_K masks
       every byte to 0..15 and Q5_K merges one more bit for 0..31. */
    for (long i = 0; i < 2000000; ++i) {
        uint32_t quants[4], activations[4];
        int32_t expected = 0;
        for (int w = 0; w < 4; ++w) {
            uint32_t q = 0;
            for (int byte = 0; byte < 4; ++byte) {
                q |= (uint32_t)(rand() & 0x1F) << (8 * byte);
            }
            quants[w] = q;
            activations[w] = ((uint32_t)rand() << 17) ^ (uint32_t)rand();
            expected += reference_dot(quants[w], activations[w]);
        }
        if (int24_nibble(quants, activations) != expected) {
            printf("nibble mismatch at %ld\n", i);
            return 1;
        }
    }

    printf("int24_general=exact_over_lane_domain_and_4000000_random_words\n");
    printf("int24_nibble=exact_over_2000000_random_calls_quant_bytes_0_31\n");
    return 0;
}
