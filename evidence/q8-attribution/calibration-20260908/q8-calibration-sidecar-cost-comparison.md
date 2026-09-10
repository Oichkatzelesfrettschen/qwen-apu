# Q8 calibration sidecar-cost comparison

## Result

The retained comparison localizes arm `09-P` as the only sidecar-bearing arm whose unchanged full-row admission mean exceeds 1,000,000 ns. Its mean is 1,038,085 ns over 748 rows. The other 21 arms have accepted means from 226,361 to 869,556 ns. The comparison does not resolve the cause: the same acquisition contains large stalls in accepted arms, and the retained rows lack per-read timing and scheduler attribution.

Every admission statement below uses every row in the arm's `clock-sidecar.tsv`. The pre-request, request, and post-request partitions are diagnostic subsets only. They do not replace the registered denominator, change a verdict, trim a stall, or admit any acquisition.

## Full denominator and diagnostic phase partitions

Each phase cell reports `sample count / integer-floor mean cost in ns`. Phase boundaries come from that arm's retained `request-window.tsv`.

| Arm | Full samples | Full mean ns | Verdict | Pre count / mean | Request count / mean | Post count / mean | Largest stall ns |
| --- | ---: | ---: | --- | ---: | ---: | ---: | ---: |
| 02-P | 859 | 637,139 | accepted | 582 / 642,829 | 222 / 620,659 | 55 / 643,445 | 44,576,091 |
| 03-P | 813 | 373,723 | accepted | 539 / 448,933 | 220 / 200,739 | 54 / 327,767 | 35,958,537 |
| 06-P | 870 | 687,021 | accepted | 571 / 765,142 | 237 / 430,141 | 62 / 949,498 | 46,848,006 |
| 07-P | 811 | 512,382 | accepted | 545 / 555,794 | 213 / 427,958 | 53 / 405,272 | 83,206,544 |
| 09-P | 748 | 1,038,085 | refused | 494 / 1,221,744 | 207 / 427,521 | 47 / 1,796,792 | 68,366,733 |
| 0a-W | 773 | 555,548 | accepted | 508 / 552,555 | 211 / 294,968 | 54 / 1,601,899 | 66,073,349 |
| 10-I0 | 802 | 641,092 | accepted | 532 / 578,556 | 219 / 834,102 | 51 / 464,622 | 51,111,111 |
| 11-I0 | 793 | 488,451 | accepted | 520 / 572,823 | 209 / 283,327 | 64 / 472,780 | 45,923,426 |
| 12-P | 783 | 392,769 | accepted | 526 / 405,039 | 205 / 240,599 | 52 / 868,549 | 27,995,058 |
| 13-P | 772 | 668,594 | accepted | 513 / 811,021 | 211 / 388,969 | 48 / 375,597 | 57,275,373 |
| 14-I0 | 760 | 869,556 | accepted | 505 / 1,105,020 | 205 / 396,842 | 50 / 429,492 | 57,099,764 |
| 15-I0 | 765 | 464,746 | accepted | 513 / 437,266 | 211 / 516,980 | 41 / 539,762 | 30,182,372 |
| 16-P | 765 | 567,919 | accepted | 496 / 633,214 | 209 / 288,876 | 60 / 1,000,141 | 54,345,772 |
| 17-I0 | 767 | 430,701 | accepted | 509 / 525,839 | 206 / 218,742 | 52 / 339,138 | 40,830,894 |
| 18-I1 | 738 | 526,395 | accepted | 485 / 628,617 | 206 / 338,233 | 47 / 296,249 | 55,848,349 |
| 19-I1 | 752 | 299,223 | accepted | 481 / 340,005 | 211 / 232,613 | 60 / 206,534 | 8,000,480 |
| 20-I0 | 744 | 471,223 | accepted | 487 / 527,318 | 211 / 367,654 | 46 / 352,412 | 32,057,016 |
| 21-I0 | 747 | 387,747 | accepted | 490 / 420,668 | 208 / 307,765 | 49 / 398,040 | 17,390,992 |
| 22-I1 | 757 | 295,264 | accepted | 483 / 315,164 | 216 / 253,219 | 58 / 286,128 | 15,988,503 |
| 23-I1 | 657 | 627,673 | accepted | 426 / 819,203 | 186 / 290,080 | 45 / 209,908 | 57,148,551 |
| 24-I0 | 601 | 237,699 | accepted | 371 / 251,705 | 183 / 217,415 | 47 / 206,121 | 17,264,539 |
| 25-S | 1217 | 226,361 | accepted | 389 / 214,916 | 779 / 232,062 | 49 / 226,588 | 6,881,415 |

Across these 22 arms, 19 have a pre-request mean above their request-window mean and 13 have a post-request mean above their request-window mean. The single largest stall lies before the request in 19 arms, inside the request in 2 arms, and after the request in 1 arm. Large stalls therefore occur in every acquisition phase. Arm `09-P` follows the common pre-request concentration pattern, while its post-request mean of 1,796,792 ns is also the largest phase mean in its own record.

Arm `09-P` has a request-window mean of 427,521 ns, below its full mean and below the registered bound. Its full verdict remains refused because admission covers all 748 retained rows. The neighboring compile-control arms do not reproduce the same aggregate: `10-I0` accepts at 641,092 ns, `11-I0` at 488,451 ns, `12-P` at 392,769 ns, `13-P` at 668,594 ns, `14-I0` at 869,556 ns, `15-I0` at 464,746 ns, and `16-P` at 567,919 ns. These values localize the refusal to the `09-P` acquisition record rather than to every arm in brick C1.

## Largest retained stalls across arms

The twenty largest individual rows across the bounded corpus are:

| Arm | Monotonic ns | Phase | Sample cost ns |
| --- | ---: | --- | ---: |
| 07-P | 910065299477910 | pre-request | 83,206,544 |
| 09-P | 910119990025889 | pre-request | 68,366,733 |
| 09-P | 910124124547829 | pre-request | 66,589,522 |
| 0a-W | 909865025944167 | pre-request | 66,073,349 |
| 13-P | 910219915504125 | pre-request | 57,275,373 |
| 23-I1 | 910477257028526 | pre-request | 57,148,551 |
| 14-I0 | 910244278796851 | pre-request | 57,099,764 |
| 09-P | 910124214756972 | pre-request | 56,771,191 |
| 09-P | 910116606850464 | pre-request | 56,597,404 |
| 0a-W | 909879875031513 | post-request | 56,079,750 |
| 18-I1 | 910347929783465 | pre-request | 55,848,349 |
| 16-P | 910293513700079 | pre-request | 54,345,772 |
| 10-I0 | 910148484528738 | request | 51,111,111 |
| 06-P | 910019716411323 | pre-request | 46,848,006 |
| 11-I0 | 910172540130721 | pre-request | 45,923,426 |
| 14-I0 | 910244012897692 | pre-request | 45,735,990 |
| 09-P | 910117424571057 | pre-request | 44,877,792 |
| 02-P | 909920547890331 | pre-request | 44,576,091 |
| 23-I1 | 910478755679959 | pre-request | 43,176,583 |
| 14-I0 | 910244395982747 | pre-request | 42,852,288 |

The corpus maximum is 83,206,544 ns in accepted arm `07-P`, before its request. Accepted arm `0a-W` reaches 66,073,349 ns before its request, accepted `13-P` reaches 57,275,373 ns before its request, and accepted `23-I1` reaches 57,148,551 ns before its request. These observations show that maximum cost alone does not determine admission. The registered mean over the complete arm does.

For `09-P`, the 68,366,733 ns maximum occurs before its request. Removing that row in a diagnostic leave-one-out calculation would reduce the remaining mean to 947,953.18 ns, but the retained row is part of the acquisition denominator. The comparison preserves the original 1,038,085 ns verdict and provides no basis for deletion, winsorization, phase exclusion, or threshold relaxation.

## Timing localization

The phase comparison provides three bounded observations:

- `09-P` accumulated 603,541,548 ns of sampler cost across 494 pre-request rows, 88,496,946 ns across 207 request rows, and 84,449,266 ns across 47 post-request rows.
- Its 26 pre-request rows above 1 ms include the six largest stalls in the arm; its nine request rows above 1 ms include a 30,915,103 ns stall; its seven post-request rows above 1 ms include a 19,702,625 ns stall.
- Accepted arms also place their maxima outside and inside request windows. `10-I0` has a 51,111,111 ns in-request maximum and still accepts at 641,092 ns. `12-P` has a 27,995,058 ns post-request maximum and accepts at 392,769 ns.

The broad occurrence of stalls across idle-looking pre/post rows and busy request rows is consistent with acquisition-side latency or host scheduling affecting the broker. The record does not distinguish those mechanisms. GPU busy, temperature, and selected clocks are contemporaneous sampled values rather than causal labels for the sampling cost.

## Input identity

This report reads 22 existing `clock-sidecar.tsv` files and their paired request windows and verdicts. The SHA-256 identities of the raw sidecar inputs are:

- `02-P`: `9d41048a78315f28c7d1c985400daeb1717853d318911599847114c8e4f179d6`
- `03-P`: `fa95fd721ca6ca441e7ef1e32a8b618d75b0b227fd909c6140969611ee05b274`
- `06-P`: `e5a9afe1eb04920ac918261d24bc9572f4ad3075781710913ad63c2ce08026cd`
- `07-P`: `534eeb15997174da7f962be0d62194441d602b0998cecafa93e31afbb5bff078`
- `09-P`: `7065204fce732625ef469ae9fa27bdc5ccb2f393af7a6258cba16b1fc63b2ad6`
- `0a-W`: `5df9a34fc00183d09159149b1014d2351012d6eeeb5382fba37fb227d0f837c1`
- `10-I0`: `538086f05a7fe23841c0e13e8cbe70fffc3de1fa766f4a5d6f81611c7b86f679`
- `11-I0`: `79c4f3abaa1f00c88ead001be08841fd8d355281dd5af64a05564c71289cea2f`
- `12-P`: `91ef9c37e6e345a1cd3e0b1d41465bff33c13c18aaf0ee9c63ed6a6ec1473e4e`
- `13-P`: `d4e3601b3827d5260bfbf30997c9add4488fd04db00aa0a4f0bca32780d721aa`
- `14-I0`: `66b77cc52052677055dac02b4069752386153be32f8c7ec4b7289e904a4952e2`
- `15-I0`: `973e33f82d2e9e83c9d2bb47fdcc7a7c8ad3f50ebdcee6b2bafc018d13fbb5f7`
- `16-P`: `6740ddb6feb767b286a00a25d21b575200589980fe2b21151ca3a13b38dbd131`
- `17-I0`: `74892cd5d4118b9c7258156d3ff100a5ba93bc980727c6dbb408d95bec2eb721`
- `18-I1`: `711f78a46cab7e4e8af632795c5276095c528c0fe6aadc21a3b6b3df6b5fb23a`
- `19-I1`: `b6c90ac5869319f4c38e0df488c2abed51e7191b30759edb7ebef1ae91ac1c0b`
- `20-I0`: `b9204783caabea51127b162228800b3fcaaf9e32815aa5468553efc7c2819c46`
- `21-I0`: `d18656153957f31e9523ebf7b1877b256e504220dc33f6098504c6fff9043dd3`
- `22-I1`: `7a2576e8d0ef22e127aad72e20515096f56ccd3231fc3ec508f8229fb7766674`
- `23-I1`: `04b1c5a951b0faf955c52f02cdc6a154e6b9291ae522cc9a8cbe0dcea8781713`
- `24-I0`: `1b184aeb580e7b9d22eacd75672f31c40260fc94b2fbd173690f5cc87a50ec07`
- `25-S`: `5046fa4c46a408d0266b04168700f13be6210241e036aadee1f50293b5e2b926`

The C0 through C3 brick receipts already retain hashes for their owned artifacts. This report creates a workstation-side derived comparison and changes none of those receipts or acquisition bytes.

## Cause assessment

The retained evidence resolves localization only:

- The refusal belongs to `09-P` under the registered full-row mean-cost contract.
- The request itself is not the dominant cost phase for `09-P`.
- Extreme individual stalls also occur in accepted arms and in all three timing phases.
- The retained acquisition does not identify a slow sysfs or procfs surface, CPU descheduling interval, interrupt source, run-queue event, or Vulkan kernel responsible for any stall.

A kernel-performance explanation remains unsupported. A specific acquisition/instrumentation root cause also remains unresolved. Further causal discrimination would require evidence absent from this acquisition, such as per-surface timestamps and scheduler traces; this bounded comparison neither requests nor substitutes that evidence.
