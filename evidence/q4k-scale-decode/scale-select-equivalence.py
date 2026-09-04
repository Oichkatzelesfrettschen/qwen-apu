#!/usr/bin/env python3
"""Every scale-decode formulation against the post-E4 control, over the whole input space.

`scale_0_4_l` and `scale8_u32` are functions of one superblock's twelve scale bytes and of
`v_im` alone, and every formulation reads those twelve bytes through a different view of the
same buffer, so the claim that an arm changes the instruction stream and not the value is a
question about two functions rather than one a device run answers.

The whole space is 2**96 per value of `v_im`, and the argument that closes it is a basis
argument resting on a linearity premise. At a fixed `v_im` every formulation below is written
from constant shifts, constant masks, byte gathers, and unions of disjoint bit fields, and
each of those is linear over GF(2): no operation takes the conjunction of two input bits and
none carries. That premise comes from reading the expressions, and it holds for exactly as
long as every formulation stays inside that vocabulary. A linear map is determined by its
image of a basis, so two linear maps that agree on the ninety-six single-bit inputs and send
zero to zero agree on all 2**96, and `check_basis` reads that image.

`check_superposition` is a check on the premise rather than its proof. It draws random pairs
and requires `f(0) == 0` and `f(a ^ b) == f(a) ^ f(b)`, which refutes a formulation that left
the vocabulary and certifies none that stayed inside it: a nonlinear map can agree with a
linear one on any finite sample and on every basis vector alike. A formulation added here
earns its linearity from its own source, and a failing superposition column says that source
was misread rather than that the draw was unlucky.

Exit 0 where every arm passes the superposition check and matches the control on every basis
case, 1 otherwise. An accepted run reports agreement over the whole space conditional on the
linearity premise the expressions carry, which is the strongest reading the method supports.

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


def basis():
    for bit in range(96):
        scales = [0] * 6
        scales[bit // 16] |= 1 << (bit % 16)
        yield scales


def samples(count):
    generator = random.Random(20260903)
    yield [0xFFFF] * 6
    for _ in range(count):
        yield [generator.getrandbits(16) for _ in range(6)]


def check_superposition(function, v_im, pairs=20000):
    """f(0) == 0 and f(a ^ b) == f(a) ^ f(b), the premise the basis argument rests on."""
    if function([0] * 6, v_im) != (0, 0):
        return False
    generator = random.Random(0x5CA1E)
    for _ in range(pairs):
        left = [generator.getrandbits(16) for _ in range(6)]
        right = [generator.getrandbits(16) for _ in range(6)]
        combined = [left[k] ^ right[k] for k in range(6)]
        expected = tuple(a ^ b for a, b in zip(function(left, v_im), function(right, v_im)))
        if function(combined, v_im) != expected:
            return False
    return True


def check_basis(function, v_im):
    """Agreement with the control on the ninety-six single-bit inputs."""
    return all(function(scales, v_im) == control(scales, v_im) for scales in basis())


def main():
    failures = 0
    print("arm\tv_im\tlinear\tbasis_agrees\tsample_mismatches")
    for name in ["control"] + sorted(ARMS):
        function = control if name == "control" else ARMS[name]
        for v_im in (0, 1):
            linear = check_superposition(function, v_im)
            agrees = name == "control" or check_basis(function, v_im)
            mismatches = sum(1 for scales in samples(200000)
                             if function(scales, v_im) != control(scales, v_im))
            if not linear or not agrees or mismatches:
                failures += 1
            print("%s\t%d\t%s\t%s\t%d"
                  % (name, v_im, "yes" if linear else "no",
                     "yes" if agrees else "no", mismatches))
    print("scale_select_equivalence=%s" % ("accepted" if failures == 0 else "refused"))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
