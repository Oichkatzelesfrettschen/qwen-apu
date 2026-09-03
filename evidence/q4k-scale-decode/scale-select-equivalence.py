#!/usr/bin/env python3
"""Every scale-decode formulation against the post-E4 control, over the input space.

`scale_0_4_l` and `scale8_u32` are functions of one superblock's twelve scale bytes and of
`v_im` alone, and every formulation below reads those twelve bytes through a different view
of the same buffer, so the claim that an arm changes the instruction stream and not the value
is settled by enumeration rather than by a device run. The space is covered by driving each
of the ninety-six scale bits alone, both saturating words, and 200,000 random draws, against
both values of `v_im`.

Exit 0 where every arm matches the control on every case, 1 otherwise.

usage: scale-select-equivalence.py
"""
import random
import sys

MASK32 = 0xFFFFFFFF


def words(scales):
    """The twelve scale bytes as the three four-byte-aligned words of the packed32 view."""
    return [(scales[2 * k] | (scales[2 * k + 1] << 16)) & MASK32 for k in range(3)]


def control(scales, v_im):
    """The post-E4 form: three uint16 reads through packed16 and a shift-or merge."""
    return ((scales[v_im + 2] << 16) | scales[v_im]) & MASK32, scales[v_im + 4]


def aligned_pair_mask_or(scales, v_im):
    """s1: the aligned word pair, halfwords selected by a hoisted shift and masked together."""
    low, high, _top = words(scales)
    shift = 16 * v_im
    complement = 16 - shift
    merged = ((low >> shift) & 0x0000FFFF) | ((high << complement) & 0xFFFF0000)
    return merged & MASK32, scales[v_im + 4]


def aligned_pair_byte_gather(scales, v_im):
    """s2: the aligned word pair, halfwords gathered by byte lane."""
    low, high, _top = words(scales)
    lane = (16 * v_im) >> 3
    low_bytes = [(low >> (8 * k)) & 0xFF for k in range(4)]
    high_bytes = [(high >> (8 * k)) & 0xFF for k in range(4)]
    merged = (low_bytes[lane] | (low_bytes[lane + 1] << 8)
              | (high_bytes[lane] << 16) | (high_bytes[lane + 1] << 24))
    return merged & MASK32, scales[v_im + 4]


def aligned_pair_bitfield_insert(scales, v_im):
    """s3: the aligned word pair, halfwords merged by bitfieldInsert."""
    low, high, _top = words(scales)
    shift = 16 * v_im
    merged = ((low >> shift) & 0x0000FFFF) | (((high >> shift) << 16) & 0xFFFF0000)
    return merged & MASK32, scales[v_im + 4]


def aligned_triple_mask_or(scales, v_im):
    """s4: all three aligned words, the eighth-scale halfword shifted out of the third."""
    low, high, top = words(scales)
    shift = 16 * v_im
    complement = 16 - shift
    merged = ((low >> shift) & 0x0000FFFF) | ((high << complement) & 0xFFFF0000)
    return merged & MASK32, (top >> shift) & 0x0000FFFF


def aligned_triple_byte_gather(scales, v_im):
    """s5, the shipped form: all three aligned words with the halfwords gathered by lane."""
    _low, _high, top = words(scales)
    merged, _scale8 = aligned_pair_byte_gather(scales, v_im)
    return merged, (top >> (16 * v_im)) & 0x0000FFFF


ARMS = {
    "s1-aligned-pair-mask-or": aligned_pair_mask_or,
    "s2-aligned-pair-byte-gather": aligned_pair_byte_gather,
    "s3-aligned-pair-bitfield-insert": aligned_pair_bitfield_insert,
    "s4-aligned-triple-mask-or": aligned_triple_mask_or,
    "s5-aligned-triple-byte-gather": aligned_triple_byte_gather,
}


def cases():
    for bit in range(96):
        scales = [0] * 6
        scales[bit // 16] |= 1 << (bit % 16)
        yield scales
    yield [0] * 6
    yield [0xFFFF] * 6
    generator = random.Random(20260903)
    for _ in range(200000):
        yield [generator.getrandbits(16) for _ in range(6)]


def main():
    mismatches = {name: 0 for name in ARMS}
    total = 0
    for scales in cases():
        for v_im in (0, 1):
            total += 1
            expected = control(scales, v_im)
            for name, arm in ARMS.items():
                if arm(scales, v_im) != expected:
                    mismatches[name] += 1
    print("arm\tcases\tmismatches")
    for name in sorted(ARMS):
        print("%s\t%d\t%d" % (name, total, mismatches[name]))
    return 1 if any(mismatches.values()) else 0


if __name__ == "__main__":
    sys.exit(main())
