#!/usr/bin/env bash
# test_gate_sno_define_redefinition_per_binding_dispatch.sh -- a SNOBOL4 function that is DEFINE'd more than
# once dispatches EVERY call to a single baked body, so calls made BEFORE a later DEFINE run the later body.
# The oracle binds each call to the definition in force WHEN THE CALL RUNS. rc=0 on the wrong answer, in both
# modes, so no board flags it by exit code -- it is a silent-wrong-answer class.
#
# Row snobol4-define-redefinition-m3-binary-realization-the-dentry-consumer-for-mode-3 (hq_U's lane, minted by
# the ceo CEO-321). Sibling row define-redefinition-ordering (hq_S). This gate replaces that row's MINT
# PLACEHOLDER DONE-WHEN, which was un-runnable by construction and therefore could never close the row.
#
# ⭐ THE CLASS IS FOUR TERMS IN SERIES AND A FIX AT ANY ONE MEASURES AS NO CHANGE (hq_S's root cause, and the
# reason this gate exists before any cure):
#   0. lower_snobol4.c -- defs[] deduped BY NAME, last-DEFINE-wins overwrite            (hq_S, on main 0fc3302b9)
#   1. lower_snobol4.c -- the bind lowering passed entry_opt NULL                       (hq_S, on main 0fc3302b9)
#   2. src/driver/scrip.c -- each bind node resolved from proc_table BY FUNCTION NAME, first match wins (hq_S, BUILT AND WITHHELD)
#   3. x86_asm.h x86_jmp_via_cell -- per-MEDIUM semantic divergence                     (hq_U, this row)
# Terms 0+1 landed with behaviour deliberately unchanged. Term 2 alone was blind-graded by seat04 and turns
# three passing programs RED: with ONE baked dispatch per function NAME, giving each bind node its own correct
# entry cannot produce per-call correctness -- it only decides WHICH single answer gets baked, converting an
# accidentally-correct ALWAYS-LAST into an ALWAYS-FIRST. There is no intermediate green state, which is why
# terms 0-2 and 3 must land together and why this gate must be able to tell those two wrongs apart.
#
# ⛔ MEDIUM DIVERGENCE IS THE MODE-3 HALF, AND IT IS NOT THE bb_*.cpp RULE (hq_S, FINDING-2026-09-06-hq_S-x86-
# jmp-via-cell-emits-an-indirect-jump-in-binary-and-a-baked-direct-jump-in-text.md). x86_asm.h is the ENCODER
# and a MEDIUM_BINARY branch there is ordinary and correct. The defect is narrower: the two arms are not two
# encodings of ONE instruction, they are TWO INSTRUCTIONS WITH DIFFERENT SEMANTICS. BINARY does
# mov rax,<cell>; mov rax,[rax]; jmp rax -- it dereferences a cell at RUN TIME. TEXT does
# lea rax,[rip + LBL]; jmp rax -- a target baked at COMPILE TIME that cannot read a binding at all. So both
# modes are wrong FOR DIFFERENT REASONS: TEXT is statically bound, BINARY has the right machinery pointed at a
# cell nobody updates (the driver's dentry table is populated only inside the --compile branch, so mode 3
# never even enters it). Single-mode reasoning kept producing corrections on this row for exactly that reason.
#
# ⛔ WHY THIS GATE DOES NOT SWEEP BASENAME LENGTHS, unlike its neighbours in this directory
# (test_gate_sno_pos_rpos_dynamic_operand.sh, test_gate_sno_charset_dynamic_operand_null_alt.sh): that sweep
# exists because argv length shifts the initial stack and therefore every RSP-RELATIVE address, which is the
# axis those classes ride on. This class is a COMPILE-TIME BINDING choice and has no rsp-relative face at all.
# A sweep here would cost 20x and grade an axis the class provably does not depend on -- copying a neighbour's
# ritual is not the same as measuring. Both MODES are graded, because the two modes fail for different causes.
#
# ⭐⭐ define_redef_three_way IS THE LOAD-BEARING WITNESS AND IT IS WHY TWO WITNESSES ARE NOT ONE TOO MANY.
# The two-call witness (define_redef_alt_entry) cannot distinguish ALWAYS-FIRST from a real cure on its own
# second line alone, and term 2 by itself produces exactly ALWAYS-FIRST. The three-call witness reads
# one|two|three under the oracle, three|three|three today (always-last), and would read one|one|one under
# term 2 alone -- three distinguishable states, so this gate REJECTS the half-cure instead of certifying it.
# A gate whose witnesses can only confirm the intended cure will accept the wrong one.
#
# CONTROLS (define_redef_two_functions, define_single_no_redef) are GREEN TODAY and must stay green: two
# distinct functions each DEFINE'd once and called interleaved, and one function DEFINE'd once and called
# twice. They discriminate "per-binding dispatch is unbuilt" from "DEFINE dispatch is broken generally" --
# without them a cure that broke ordinary DEFINE while fixing redefinition would read as progress here.
#
# rc=0 CLEAN (every witness and control matches the oracle in BOTH modes), rc=1 VIOLATION (at least one does
# not), rc=2 UNPROVEN (no oracle, no fresh binary, a missing fixture, or a zero denominator -- never printed
# as a pass).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="$(cd "$ROOT/.." && pwd)"
GATE_NAME=sno_define_redefinition_per_binding_dispatch
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
O="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"

W="$S4E/corpus/tests/snobol4"
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

PROGS="define_redef_alt_entry define_redef_three_way define_redef_two_functions define_single_no_redef"
CONTROLS=" define_redef_two_functions define_single_no_redef "

m4_run() {   # $1 = source .sno (absolute), $2 = basename (no ext), $3 = outfile, $4 = rc varname
    local src="$1" name="$2" outfile="$3" __rcvar="$4" __rc
    ( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile -o "$name.s" "$src" </dev/null >/dev/null 2>&1 ) || { echo "M4-COMPILE-FAILED" > "$outfile"; printf -v "$__rcvar" '%d' 1; return; }
    ( cd "$T" && gcc -no-pie "$name.s" -o "$name.bin" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) || { echo "M4-LINK-FAILED" > "$outfile"; printf -v "$__rcvar" '%d' 1; return; }
    ( cd "$T" && timeout -k 5 10s "./$name.bin" </dev/null >"$outfile" 2>&1 ); __rc=$?
    printf -v "$__rcvar" '%d' "$__rc"
}

red=0; examined=0; RED_NAMES=''; GRADED_NAMES=''
for p in $PROGS; do
    src="$W/$p.sno"; ref="$W/$p.ref"
    if [ ! -f "$src" ] || [ ! -f "$ref" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: missing committed fixture $p (.sno/.ref)"; gate_stamp; exit 2
    fi
    timeout -k 5 20 "$O" -bf "$src" </dev/null >"$T/$p.oref" 2>/dev/null
    if ! cmp -s "$T/$p.oref" "$ref"; then
        echo "RED  $p: committed ref disagrees with the live oracle -- re-cut it (oracle/ref drift, not this class)"
        red=$((red+1)); examined=$((examined+1)); RED_NAMES="$RED_NAMES $p(ref-drift)"; GRADED_NAMES="$GRADED_NAMES $p"; continue
    fi
    is_control=0
    case "$CONTROLS" in *" $p "*) is_control=1;; esac
    cp "$src" "$T/$p.sno"
    ( cd "$T" && timeout -k 5 10s "$ROOT/scrip" "$p.sno" </dev/null >"$T/$p.m3" 2>&1 ); rc3=$?
    ok3=0; cmp -s "$T/$p.m3" "$ref" && ok3=1
    m4_run "$T/$p.sno" "$p" "$T/$p.m4" rc4
    ok4=0; cmp -s "$T/$p.m4" "$ref" && ok4=1
    examined=$((examined+1)); GRADED_NAMES="$GRADED_NAMES $p"
    tag="witness"; [ "$is_control" = 1 ] && tag="control"
    if [ "$ok3" = 1 ] && [ "$ok4" = 1 ]; then
        echo "PASS $p [$tag]: m3 and m4 both match the oracle"
    else
        got3="$(tr '\n' '|' < "$T/$p.m3")"; got4="$(tr '\n' '|' < "$T/$p.m4")"; want="$(tr '\n' '|' < "$ref")"
        echo "RED  $p [$tag]: m3=$ok3 (rc=$rc3, got <$got3>) m4=$ok4 (rc=$rc4, got <$got4>) -- oracle <$want>"
        red=$((red+1)); RED_NAMES="$RED_NAMES $p[$tag]"
    fi
    rm -f "$T/$p.sno" "$T/$p.m3" "$T/$p.m4" "$T/$p.s" "$T/$p.bin"
done
gate_floor "$examined" 4 "witness/control programs"
echo "GRADED[$examined]:$GRADED_NAMES"
[ "$red" -ne 0 ] && echo "RED[$red]:$RED_NAMES"
gate_verdict "$red" "program(s) whose per-call DEFINE binding diverges from the oracle in at least one mode --- RED:${RED_NAMES:- none} --- GRADED:$GRADED_NAMES ---"
