#!/bin/bash
# test_gate_oracle_bf_capable.sh -- ⭐ AN ORACLE IS NOT A PATH, IT IS A BINARY THAT ACCEPTS `-bf`.
#
# WHY (hq_P s259, measured). Three SPITBOL binaries on this box are byte-identical and DO NOT SUPPORT `-f`.
# Handed the MANDATORY `-bf` (s189) they answer "No END statement found in source file(s)." to EVERY program.
# A harness pointed at one prints a full, plausible, ENTIRELY FALSE all-FAIL table.
# ⭐ STRUCTURAL, so it WILL come back: a SPITBOL tree ships `bin/sbl` as BASEBOL, the BOOTSTRAP; `make spitbol`
# writes the product to the TOP LEVEL as `./sbl`. In our `x64/` fork `bin/sbl` IS the product. The layouts
# disagree, so the natural guess "<root>/bin/sbl" lands on the trap. This gate makes that unfalsifiable-by-hand.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh"; gate_parse_args "$@"
gate_require "$HERE/lib_oracle_flags.sh" "the oracle authority lib_oracle_flags.sh"
. "$HERE/lib_oracle_flags.sh"
N=0; BAD=0
chk() { # $1 path, $2 label, $3 must_be_capable(1/0)
    N=$((N+1))
    if [ ! -e "$1" ]; then
        if [ "$3" = 1 ]; then echo "  ⛔ $2: ABSENT at $1"; BAD=$((BAD+1)); else echo "  ·  $2: absent (not required)"; fi; return; fi
    if sbl_bf_capable "$1"; then echo "  ✅ $2: accepts -bf"
    elif [ "$3" = 1 ]; then echo "  ⛔ $2: PRESENT but REJECTS -bf -- any run against it is a FALSE all-FAIL ($1)"; BAD=$((BAD+1))
    else echo "  ⚠  $2: rejects -bf (reference clone, never an oracle) -- $1"; fi
}
echo "=== the two authority faces ==="
c="$(sbl_clean_bin 2>/dev/null)";       [ -n "$c" ] && chk "$c" "sbl_clean_bin (BENCHMARK)" 1 || { echo "  ⛔ sbl_clean_bin REFUSED or empty"; N=$((N+1)); BAD=$((BAD+1)); }
k="$(sbl_correctness_bin 2>/dev/null)"; [ -n "$k" ] && chk "$k" "sbl_correctness_bin (CORRECTNESS)" 1 || { echo "  ⛔ sbl_correctness_bin REFUSED or empty"; N=$((N+1)); BAD=$((BAD+1)); }
# ⭐ CORRECTED s259 (Lon: no symlinks, no per-seat clones, seats carry ONLY .github/SCRIP/corpus).
# There is exactly ONE clone, at the ASSET ROOT, reached through S4E_ASSETS -- so check the RESOLVED
# oracle once, and separately assert that no seat home directory has grown a stale private copy back.
echo "=== the ONE shared clone, resolved the way every script resolves it (S4A) ==="
_S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
_S4A="${S4E_ASSETS:-$([ -d "$_S4E/x64" ] && echo "$_S4E" || echo /home/resources)}"
chk "$_S4A/x64/bin/sbl" "asset-root oracle (S4A=$_S4A)" 1
echo "=== no seat home directory may carry a private x64 copy (D-17b: seats carry .github/SCRIP/corpus) ==="
_stray=0
for d in /home/claude0*[0-9] /home/claude1[0-6]; do
    [ -e "$d/x64" ] && { echo "  ⛔ STRAY private clone: $d/x64 -- delete it, the asset root is the one copy"; _stray=$((_stray+1)); }
done
N=$((N+1)); [ "$_stray" -eq 0 ] && echo "  ✅ no stray per-seat clones" || BAD=$((BAD+_stray))
echo "=== every other sbl under /home/resources (reference clones may legitimately reject -bf) ==="
for b in /home/resources/*/sbl /home/resources/*/bin/sbl; do
    [ -e "$b" ] || continue
    case "$b" in *spitbol-clean*|*/x64/*) continue ;; esac   # already covered as authority faces
    chk "$b" "$(echo "$b" | sed 's|/home/resources/||')" 0
done
echo ""
echo "examined $N binary path(s): bad=$BAD"
gate_floor "$N" 5 "oracle binary paths"
gate_verdict "$BAD" "oracle path(s) that must accept -bf and do not"
