#!/usr/bin/env bash
# test_gate_prolog_a_cell_reference_spares_an_attributed_variable.sh -- THE ATTRIBUTED VARIABLE IS A TWO-CELL BLOCK (ARCH-PROLOG-ACTIVATION-LIFETIME.md section 6.4 R2; the cfo's review of 78fa7c46d, 2026-10-28).
#
# MEASURED, which is why this is a gate: R2 makes a DT_PLVAR reference into an HB_DVEC block mark ONE cell and null the block's unreached cells at the sweep.  An attributed
# variable is a 2-cell HB_DVEC block, word 0 the self-referencing DT_PLVAR with slen PL_ATTV_SLEN and word 1 the attribute (rt_pl_attv_set_cell, unification.c's two copy
# sites), and every reader of the attribute steps from word 0 to word 1.  The first cut of R2 (SCRIP 78fa7c46d) marked only word 0 and nulled the attribute word: under
# SCRIP_GC_STRESS 1 or 3 freeze, put_attr and restore-on-backtracking hung inside the collector (rc 124) and dif and when exited rc 0 with the constraint silently gone.  The
# cure keeps the whole-block mark for a reference whose target cell is an attributed-variable head (pl_attv_is, and the transient PL_ATTV_SEEN of the residue pass).
#
# THE WITNESSES are gc_witnesses/pl_attvar_*.pl, each with a churn of compound terms in the middle so a collection runs while the attributed variable is live; every .ref is cut
# from swipl 9.0.4 (its toplevel's trailing blank line removed).  THE CONTROL: each witness without stress must print its ref in both modes, or the instrument cannot read green and
# nothing is graded.  THE GRADE: the same witness under SCRIP_GC_STRESS=3, both modes, must print the same ref.  RED on the commit before the cure (78fa7c46d: freeze, attr,
# restore and frozen hang, dif and when print the wrong answer), green on the cure.  natural_collections (the cfo's churn of 20,000 under put_attr and freeze) is graded with NO stress:
# it hung on 78fa7c46d from natural collections alone, and stress 3 over it costs about 80 s.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP"; exit 2; }
G="$(basename "${BASH_SOURCE[0]}" .sh)"
WITS="freeze1 dif1 when1 attr1 restore1 frozen1"
NAT="natural_collections"
[ -x "$ROOT/scrip" ] || { echo "⛔ REFUSE(2) [$G]: no ./scrip to measure"; exit 2; }
for w in $WITS $NAT; do
    [ -f "$HERE/gc_witnesses/pl_attvar_$w.pl" ] && [ -f "$HERE/gc_witnesses/pl_attvar_$w.ref" ] || { echo "⛔ REFUSE(2) [$G]: the witness or its ref pl_attvar_$w is absent"; exit 2; }
done
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
SW="-d131072k -s4096k"
run_m3() { ( cd "$ROOT" && SCRIP_GC_STRESS="$3" timeout 60 ./scrip $SW "$1" < /dev/null > "$2.out" 2> "$2.err" ); echo $?; }
run_m4() {
    local b="$T/$(basename "$1" .pl).bin"
    if [ ! -x "$b" ]; then
        ( cd "$ROOT" && timeout 60 ./scrip --compile -o "$b.s" "$1" < /dev/null > /dev/null 2> "$b.cerr" ) || { echo 2; return; }
        gcc "$b.s" -o "$b" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" 2> "$b.lerr" || { echo 2; return; }
    fi
    ( SCRIP_GC_STRESS="$3" timeout 60 "$b" $SW < /dev/null > "$2.out" 2> "$2.err" ); echo $?; }
red=0; graded=0
for w in $WITS; do
    src="$HERE/gc_witnesses/pl_attvar_$w.pl"; ref="$HERE/gc_witnesses/pl_attvar_$w.ref"
    for mode in m3 m4; do
        rc=$(run_$mode "$src" "$T/$w.$mode.ctl" 0)
        if [ "$rc" != 0 ] || ! cmp -s "$T/$w.$mode.ctl.out" "$ref"; then echo "⛔ REFUSE(2) [$G]: control $w $mode rc=$rc -- without stress the witness does not print its swipl ref, so the instrument cannot read green and nothing is graded"; exit 2; fi
        rc=$(run_$mode "$src" "$T/$w.$mode.st" 3)
        graded=$((graded + 1))
        if [ "$rc" != 0 ] || ! cmp -s "$T/$w.$mode.st.out" "$ref"; then echo "⛔ RED [$G]: $w $mode under SCRIP_GC_STRESS=3 rc=$rc -- the attributed variable lost its attribute word to the collector (section 6.4 R2)"; red=1; else echo "[$G] $w $mode stress 3 prints its ref"; fi
    done
done
for mode in m3 m4; do
    src="$HERE/gc_witnesses/pl_attvar_$NAT.pl"; ref="$HERE/gc_witnesses/pl_attvar_$NAT.ref"
    rc=$(run_$mode "$src" "$T/$NAT.$mode" 0)
    graded=$((graded + 1))
    if [ "$rc" != 0 ] || ! cmp -s "$T/$NAT.$mode.out" "$ref"; then echo "⛔ RED [$G]: $NAT $mode with no stress rc=$rc -- a natural collection under churn cost the attributed variable its attribute word (section 6.4 R2)"; red=1; else echo "[$G] $NAT $mode natural collections print the ref"; fi
done
[ $red = 0 ] && echo "PASS [$G]: $graded stress readings print the swipl ref, an attributed variable keeps its attribute word through a collection in both modes"
exit $red
