#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
# test_gate_no_bench_kernel_qualifies_for_gva_demotion.sh -- ⭐ THE GVA-DEMOTION CLIFF, ASSERTED INSTEAD OF
# LEFT AS A COINCIDENCE (hq_P 2026-09-13; SPEED lane, CONCERN 2 under NONET. Route ruled by cfo, who owns
# the trigger -- see THE OBSERVABLE below; their canary is SCRIP 5a6aa3461, the cure bbb77e2a1).
#
# ⛔ WHAT THIS GUARDS, AND WHY NOTHING ELSE CAN. rung22 made an ACCESS trace fire on a plain global read by
# DEMOTING the GVA fast path at compile time: a SNOBOL4 program holding a TRACE call whose type argument is
# not a literal provably non-ACCESS has its eligible-global count set to zero, and every global read in it
# goes the slow way. Measured cost on this box: 1.82x-2.15x. ⛔⛔ A DEMOTED PROGRAM IS STILL *CORRECT*, so
# no board, ref, oracle diff or correctness gate in this tree can ever report that it got slower. A
# benchmark grid would report it as an honest reading of a program that had quietly fallen down a hole.
#
# ⭐ THIS GATE AND cfo's CANARY POINT IN OPPOSITE DIRECTIONS AND THAT IS THE DESIGN. Their four witnesses
# fail if the demotion ever stops FIRING. They cannot detect A NEW PROGRAM FALLING ONTO THE CLIFF -- their
# green stays green, correctly, on the day it happens. That second absence is this gate's only job.
# Measured when the cure landed: the qualifying set is EMPTY across the benchmark tree -- every TRACE call
# there is one of cfo's own non-qualifying controls. THE REASON NOBODY PAYS IS THE REASON NOBODY WOULD
# NOTICE, so the empty set is asserted here rather than left to hold by luck.
#
# ⭐⭐ THE OBSERVABLE IS THE EMITTED ISLAND, NOT A COPY OF THE PREDICATE (cfo's ruling, 2026-09-13, and it
# is a better design than the one this gate was first written with). A first cut mirrored
# gva_trace_type_provably_non_access()'s two spellings and tripwired them. That is still TWO independent
# implementations of one rule -- it only makes the drift loud. Instead this gate compiles the kernel and
# asserts `__gva_names` is PRESENT in the .s (emitted at src/driver/scrip.c:1530, gated on n_gva > 0). That
# reads THE TRIGGER'S OUTPUT, so it cannot disagree with the trigger by construction: if the predicate ever
# widens to a spelling this gate does not know, the island vanishes and this gate goes RED on that kernel,
# which is exactly the alarm wanted. Both guards then share ONE ground truth and ask opposite questions.
#
# ⛔ THE FALSE-GREEN TRAP, cfo's, in this gate's direction: a PRESENCE check passes on a kernel that has no
# eligible globals at all and so never had an island to lose. Absence is therefore never a silent pass --
# it is resolved against a TWIN (the same source with its TRACE calls removed). Twin has an island and the
# original does not => DEMOTED, rc=1. Neither has one => the kernel has no eligible globals, the arm is
# VACUOUS, rc=2. A gate that cannot measure must never print what a clean one prints.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=no_bench_kernel_qualifies_for_gva_demotion
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure (this is NOT a pass; run make)"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
# ⭐ GVA_BENCH_DIR -- the PROBE root, same precedent and same reason as lib_gate.sh's SCRIP_STALE_PROBE_SRC:
# a fail-once proof must not edit the tree it grades, because that is how a green gate and a dirty checkout
# come to coexist. ⛔ It CANNOT smuggle a false green: every source found under it is graded by the identical
# code path below, and a root with no TRACE-bearing source trips the vacuity guard and REFUSES rc=2. Pointing
# it somewhere empty makes this gate say "I could not measure", never "clean".
BENCH="$(cd "${GVA_BENCH_DIR:-$ROOT/../corpus/benchmarks}" 2>/dev/null && pwd)" || BENCH=""
[ -n "$BENCH" ] && [ -d "$BENCH" ] || refuse "no corpus/benchmarks tree -- this gate proves nothing without the sources it censuses"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
# island <src> -- compile and COUNT __gva_names in the emitted asm. Prints "-1" when the compile fails, so
# "did not compile" can never be read as "no island".
island() {
    local src="$1" out="$TD/isl.s"
    rm -f "$out"
    if ! timeout -k 5 120s "$SCRIP" --compile --out="$out" "$src" </dev/null >"$TD/isl.log" 2>&1; then echo -1; return; fi
    [ -r "$out" ] || { echo -1; return; }
    # ⛔ `grep -c` PRINTS 0 *and* exits 1 when it matches nothing, so `grep -c ... || echo 0` emits TWO
    # lines ("0\n0") and every downstream [ -eq ] dies with "integer expression expected". Caught by arm A
    # on this gate's first run -- which is the arm doing its job: it FAILED rather than passing quietly.
    local n=0
    n="$(grep -c '__gva_names' "$out" 2>/dev/null | head -1)" || n=0
    [ -n "$n" ] || n=0
    echo "$n"
}
#-----------------------------------------------------------------------------------------------------
# A. THE OBSERVABLE DISCRIMINATES. ⭐ An accounting that explains everything explains nothing: before its
# verdict on real kernels is worth reading, the island has to SEPARATE the forms that must demote from the
# controls that must not. Five forms over one synthetic program holding two eligible globals.
echo "A. the island separates qualifying TRACE forms from non-qualifying ones"
cat > "$TD/base.sno" <<'SNO'
         counter = 0
         total = 0
loop     counter = counter + 1
         total = total + counter
         LT(counter,5)                                        :S(loop)
         OUTPUT = total
END
SNO
probe() {  # probe <expect-island: yes|no> <label> <trace-line-or-empty>
    local want="$1" label="$2" line="$3" n
    { [ -n "$line" ] && printf '%s\n' "$line"; cat "$TD/base.sno"; } > "$TD/probe.sno"
    n="$(island "$TD/probe.sno")"
    if [ "$n" -eq -1 ]; then bad "$label: probe did not compile -- the observable cannot be established"; return; fi
    if [ "$want" = yes ] && [ "$n" -gt 0 ]; then ok "$label keeps its island ($n)"
    elif [ "$want" = no ] && [ "$n" -eq 0 ]; then ok "$label loses its island (demoted, as it must)"
    else bad "$label: island=$n but expected $([ "$want" = yes ] && echo '>0' || echo '0')"; fi
}
probe yes "no TRACE at all"                ""
probe yes "TRACE with an omitted type"     "         TRACE(.counter)"
probe yes "TRACE of a literal non-ACCESS"  "         TRACE(.counter,'KEYWORD')"
probe no  "TRACE of literal ACCESS"        "         TRACE(.counter,'ACCESS')"
probe no  "TRACE of the short form A"      "         TRACE(.counter,'A')"
probe no  "TRACE of a CONCATENATED type"   "         TRACE(.counter,'ACC' 'ESS')"
#-----------------------------------------------------------------------------------------------------
# B. THE POPULATION. Every SNOBOL4-family benchmark source that CALLS TRACE. ⛔ Sources that do not
# compile are NOT silently dropped -- they are named and counted as NOT-GRADED inventory beside the
# verdict (THE POPULATION LAW: a shipped program moves from the denominator to the inventory line, never
# out of sight). Extensions: .sno and .spt are the driver's SNOBOL4 default branch (scrip.c:1143 sends
# .sc/.icn/.pl/.raku/.reb/.pas elsewhere); .sc is scanned too because including it can only make this
# gate STRICTER, and a false red is loud where a false green is silent.
echo "B. no benchmark source that calls TRACE is GVA-demoted"
pop=0; graded=0; ungraded=0; ungraded_names=""
while IFS= read -r f; do
    grep -qE '(^|[^A-Za-z0-9_])TRACE[[:space:]]*\(' "$f" || continue
    pop=$((pop + 1))
    n="$(island "$f")"
    rel="${f#$BENCH/}"
    if [ "$n" -eq -1 ]; then
        ungraded=$((ungraded + 1)); ungraded_names="$ungraded_names $rel"
        printf '    NOT-GRADED  %s -- does not compile: %s\n' "$rel" "$(head -1 "$TD/isl.log" 2>/dev/null | cut -c1-90)"
        continue
    fi
    graded=$((graded + 1))
    if [ "$n" -gt 0 ]; then ok "$rel: island present ($n) -- not demoted"; continue; fi
    # island absent: resolve DEMOTED vs NO-ELIGIBLE-GLOBALS against the twin, never guess.
    sed -E '/(^|[^A-Za-z0-9_])TRACE[[:space:]]*\(/d' "$f" > "$TD/twin.sno"
    tn="$(island "$TD/twin.sno")"
    if [ "$tn" -gt 0 ]; then
        bad "$rel: island ABSENT but its TRACE-free twin emits one ($tn) -- THIS KERNEL IS GVA-DEMOTED and takes 1.82x-2.15x with no other instrument in the tree reporting it. Rewrite the TRACE type argument as a literal that is provably non-ACCESS, or move the program out of the benchmark tree and say so in the row."
    else
        rm -rf "$TD"; trap - EXIT
        refuse "$rel emits no island and neither does its TRACE-free twin, so this kernel has NO ELIGIBLE GLOBALS and the arm is VACUOUS over it -- it would pass whether or not the demotion fired. Give the gate a kernel with globals or re-cut the population; do not read this as clean."
    fi
done < <(find "$BENCH" -type f \( -name '*.sno' -o -name '*.spt' -o -name '*.sc' \) | sort)
# ⛔ THE VACUITY GUARD: a census whose pattern has rotted matches NOTHING and reports zero demoted kernels,
# which is byte-identical to a clean census.
[ "$pop" -ge 1 ] || refuse "ZERO benchmark sources call TRACE. Either the scanner is broken or every TRACE call left the tree -- both make this gate's green meaningless. Check by hand (grep -rn TRACE \"$BENCH\") before trusting any result here."
printf '  POPULATION: %s source(s) call TRACE -- %s graded, %s not graded (do not compile):%s\n' "$pop" "$graded" "$ungraded" "${ungraded_names:- none}"
[ "$graded" -ge 1 ] || refuse "all $pop TRACE-bearing source(s) failed to compile, so NOTHING was graded. The inventory above is the finding; this gate proves nothing about demotion today."
#-----------------------------------------------------------------------------------------------------
printf '\nGATE %s -- pass=%s fail=%s (graded %s of %s TRACE-bearing benchmark sources)\n' \
       "$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)" "$PASS" "$FAIL" "$graded" "$pop"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
