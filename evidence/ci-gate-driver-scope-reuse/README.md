# Gate-cell driver-scope reuse

## Observed cost

GitHub Actions run `34446916028` tested pull request 240 at merge-test tree
`3fb5c728d17833b1d07bf7ffc9fe6ac334c4193e`, whose pull-request head was
`ec977dfc31ae711619f1907e6882ea74f41ed0ce` over base
`c585f4e6cc7055197efad22768d0c971eeff7144`. The clone-local job completed
successfully in 31 minutes 32 seconds. The gate restored the main-ref cache
from run `34416461888` and then reported 152 executed cells and zero reused
cells.

The retained gate log attributes 70.756435272 seconds to key derivation and
1791.269594007 seconds to cell execution. `slow-cells.tsv` records the ten
largest execution costs. The two largest cells consumed 256.916 and 244.910
seconds. The evidence identifies failed reuse, rather than workflow setup or
hardware access, as the dominant mechanism.

The private downloaded copies of `gate.log` and `result.tsv` remain outside the
repository. `source-artifacts.tsv` binds their SHA-256 identities and the
public run identity. The evidence publishes no credentials, runner paths from
outside the already public result, or appliance data.

## Correction

Every bounded cell key already hashes its command, tool identities, mode,
read-set class, and every file in its derived read set. The previous key also
hashed the complete repository gate driver and key reader. Adding one cell to
`repository-quality-gates.sh` therefore moved all existing keys even when each
existing cell's result-bearing manifest remained unchanged.

`gate-cell-key.sh` now permits a driver-independent cell to reuse an older
accepted record only when the current reader substitutes that record's old
driver digest into the current manifest and reproduces the record filename's
SHA-256 exactly. The equality proves that every other manifest field remains
identical. The helper then validates unique status, name, key, tools, driver,
read-set, and numeric execution-cost fields before migrating the record to the
current key.

The four cells that execute functions defined inside
`repository-quality-gates.sh` declare `exact-driver`. A driver or reader edit
reruns those cells. A new `gate_*` command without that declaration refuses
before execution. Universal and unbounded cells continue to run on every full
gate, and any command, tool, mode, read-set, or input change continues to move
the reconstructed key and run the affected cell.

## Focused proof and boundary

`remote/test-repository-gate-cells.sh` proves fresh execution, ordinary reuse,
input and mode invalidation, compatible-driver migration, exact-driver
invalidation, malformed scope refusal, and cache-record field validation over
a disposable fixture tree. ShellCheck grades the changed shell files at
warning severity.

The next CI run falsifies the operational prediction if an unchanged
driver-independent cell executes solely because the driver or reader digest
moved. The correction claims neither an exact future job duration nor hardware
behavior. The preparation runs no model, browser, remote command, or appliance
mutation.
