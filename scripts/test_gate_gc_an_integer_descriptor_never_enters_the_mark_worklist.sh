#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_an_integer_descriptor_never_enters_the_mark_worklist.sh -- THE MARK WORKLIST USED TO CARRY EVERY DESCRIPTOR IT WAS
# HANDED: an integer or real or null cell was pushed, popped and switched on (~100 Ir at -O0) to find there was nothing to mark.
# On table_access at the shipped 128 KB arena that was 766 pushes per collection for a table of integers, 92 K of the 851 K Ir a
# collection cost (ceo 2026-09-25, CEO-1256). Since this landing gc_wl_push and rt_gc_visit_descr test the tag first
# (gc_tag_bears_ptr: the thirteen tags that can hold a heap pointer) and a descriptor of any other tag never enters the worklist.
# THE OBSERVABLE is the collector's own telemetry: [ZGC] regeneration lines carry wl_depth_max, the deepest the worklist ever got.
# The witness keeps a 6,000-element integer ARRAY (created with an integer initial value, so no element is ever the null
# string, whose tag DOES bear a pointer) live across collections; pre-cure the array visitor pushed all 6,000 elements
# (wl_depth_max >= 6000), cured it pushes none of them (wl_depth_max stays under 2,000: the strings and the aggregate cells).
# ARMS: (1) the witness prints the oracle's answer at 128 KB; (2) collections >= 20 (population); (3) wl_depth_max < 2000.
# FAIL_ONCE (recorded): the pre-cure runtime at 0f560a28e read wl_depth_max=6000 on this witness; this tree reads under 100.
# EXIT 0 all arms; 1 a red (named); 2 REFUSED (oracle or build missing, no telemetry line, or too few collections).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)"; [ -x "$SBL" ] || { echo "REFUSED(2): correctness oracle missing ($SBL)"; exit 2; }
[ -x "$ROOT/scrip" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSED(2): $ROOT/scrip or out/libscrip_rt.so not built"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/ints.sno" <<'SNO'
        &TRIM = 1
        a = ARRAY(6000, 0)
        i = 1
fill    a[i] = i * 3
        i = LT(i, 6000) i + 1                           :S(fill)
        k = 0
loop    s = DUPL('x', 40) k
        t = TABLE(64)
        t[k] = s
        k = LT(k, 3000) k + 1                           :S(loop)
        OUTPUT = a[1] ' ' a[6000] ' ' SIZE(s) ' ' k
END
SNO
"$SBL" $(sbl_lang_flags) "$W/ints.sno" < /dev/null > "$W/ints.ref" 2>&1 || true
[ -s "$W/ints.ref" ] || { echo "REFUSED(2): the oracle printed nothing for the witness"; exit 2; }
red=0
unset SCRIP_HEAP_MB; export SCRIP_HEAP_KB=128
( cd "$W" && SCRIP_ZETA_TELEM=1 timeout -k 5 60 "$ROOT/scrip" ints.sno < /dev/null > "$W/ints.out" 2> "$W/ints.err" )
cmp -s "$W/ints.out" "$W/ints.ref" && echo "ok  (1) m3 prints the oracle's answer at SCRIP_HEAP_KB=128: $(cat "$W/ints.ref")" || { echo "RED (1) m3 differs from the oracle:"; diff "$W/ints.ref" "$W/ints.out" | head -4; red=1; }
coll=$(grep -c '^\[ZGC\] regeneration' "$W/ints.err"); [ "$coll" -ge 20 ] || { echo "REFUSED(2): only $coll collections at 128 KB -- the population cannot grade the mark worklist"; exit 2; }
echo "ok  (2) collections=$coll (population)"
depth=$(grep -o 'wl_depth_max=[0-9]*' "$W/ints.err" | tail -1 | cut -d= -f2); [ -n "$depth" ] || { echo "REFUSED(2): no wl_depth_max token in the [ZGC] telemetry"; exit 2; }
if [ "$depth" -lt 2000 ]; then echo "ok  (3) wl_depth_max=$depth < 2000 with a 6,000-integer array live: integer descriptors never enter the worklist"
else echo "RED (3) wl_depth_max=$depth >= 2000: the 6,000 integer array elements are being pushed onto the mark worklist again"; red=1; fi
[ "$red" -eq 0 ] && { echo "GATE OK: a descriptor whose tag cannot hold a heap pointer never enters the mark worklist"; exit 0; }
echo "GATE FAILED: see the RED lines above"; exit 1
