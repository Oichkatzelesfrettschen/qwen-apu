#!/usr/bin/env python3
"""Extract the registered quantities from a 0-2-2-0 probability sweep.

The sweep directory holds arm-1-c0, arm-2-c2, arm-3-c2, arm-4-c0, each with a
turn1.json carrying completion_probabilities from one greedy /completion at
n_probs 8. Token identity alone cannot distinguish a quantized-path-specific
perturbation from a general perturbation that meets no sufficiently thin tie
in the 32-token witness, so the extractor reports per-position log-probability
deltas between conditions whether or not the tokens diverge.

Quantities: common-prefix length; first-divergence index and ordinal; top-1
logprob delta over the common prefix (mean, maximum, signed distribution);
top-2 margins under each condition at the divergence point; the pairwise
margin swing; top-k candidate overlap at the divergence point; and repeat-arm
logprob equality within each condition.

The delta window is the causal comparison: positions before the first flipped
token, plus the candidate distribution at the flip itself, share one generated
history across conditions and measure the partition perturbation directly.
Positions after a flip condition on different histories and combine the
perturbation with ordinary autoregressive propagation, so the extractor stops
the delta scan at the divergence point. A sweep with token divergence absent
admits the direct comparison at every position.
"""
import json
import math
import sys

directory = sys.argv[1]
arms = {name: json.load(open(f"{directory}/{name}/turn1.json"))
        ["completion_probabilities"] for name in
        ("arm-1-c0", "arm-2-c2", "arm-3-c2", "arm-4-c0")}

c0, c0_repeat = arms["arm-1-c0"], arms["arm-4-c0"]
c2, c2_repeat = arms["arm-2-c2"], arms["arm-3-c2"]


def identical(a, b):
    return all(x["id"] == y["id"] and x["logprob"] == y["logprob"]
               for x, y in zip(a, b)) and len(a) == len(b)


print(f"repeat_arm_equal_c0={identical(c0, c0_repeat)}")
print(f"repeat_arm_equal_c2={identical(c2, c2_repeat)}")

divergence = next((i for i, (a, b) in enumerate(zip(c0, c2))
                   if a["id"] != b["id"]), None)
prefix = divergence if divergence is not None else min(len(c0), len(c2))
print(f"common_prefix_length={prefix}")
print("first_divergence_index=" +
      ("none" if divergence is None else
       f"{divergence} ordinal={divergence + 1}"))

deltas = [c2[i]["logprob"] - c0[i]["logprob"] for i in range(prefix)]
magnitudes = [abs(d) for d in deltas]
positive = sum(1 for d in deltas if d > 0)
negative = sum(1 for d in deltas if d < 0)
zero = sum(1 for d in deltas if d == 0)
print(f"top1_logprob_delta_mean_abs={sum(magnitudes) / len(magnitudes):.6f}")
print(f"top1_logprob_delta_max_abs={max(magnitudes):.6f}")
print(f"top1_logprob_delta_signs positive={positive} negative={negative} "
      f"zero={zero}")
print("top1_logprob_delta_signed=" +
      " ".join(f"{d:+.6f}" for d in deltas))

if divergence is not None:
    for label, doc in (("c0", c0), ("c2", c2)):
        top = doc[divergence]["top_logprobs"]
        margin = top[0]["logprob"] - top[1]["logprob"]
        print(f"top2_margin_{label}_nats={margin:.6f} "
              f"top1_id={top[0]['id']} top1_piece={top[0]['token']!r} "
              f"top2_id={top[1]['id']} top2_piece={top[1]['token']!r}")
    top_c0 = c0[divergence]["top_logprobs"]
    top_c2 = c2[divergence]["top_logprobs"]
    swing = ((top_c0[0]["logprob"] - top_c0[1]["logprob"])
             + (top_c2[0]["logprob"] - top_c2[1]["logprob"]))
    print(f"pairwise_margin_swing_nats={swing:.6f}")
    ids_c0 = [c["id"] for c in top_c0]
    ids_c2 = [c["id"] for c in top_c2]
    overlap = len(set(ids_c0) & set(ids_c2))
    print(f"topk_candidate_overlap={overlap}/{len(ids_c0)}")
    p = {c["id"]: math.exp(c["logprob"]) for c in top_c0}
    q = {c["id"]: math.exp(c["logprob"]) for c in top_c2}
    flipped = 0.5 * (abs(p[ids_c0[0]] - q[ids_c0[0]])
                     + abs(p[ids_c2[0]] - q[ids_c2[0]]))
    print(f"tv_contribution_flipped_pair_lower_bound={flipped:.6f}")
