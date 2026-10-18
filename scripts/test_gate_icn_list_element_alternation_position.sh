#!/usr/bin/env bash
# test_gate_icn_list_element_alternation_position.sh -- an ALTERNATION in a NON-FIRST element of an Icon list
# constructor must evaluate to its FIRST alternative, exactly as it does in the first element position.
#
# THE CLASS (hq_I 2026-09-05, cured in src/lower/lower_icon.c, row icon-arizona-io-list-element-assign-
# alternation-swallows-open): lower_make_list chained sibling elements with the file-local helper gamma_to,
# which redirects an edge to the target's BETA port whenever icn_gen_wiring(target) is true. A forward sibling
# edge must always enter at ALPHA -- beta is the RESUME port, so the box was being resumed before it had ever
# run and handed back its SECOND alternative. Visible in the emitted asm as the preceding element ending
# "jmp nN_disjunction_beta". The sibling loop in lower_call already chained its arguments with lc_gamma_to,
# which is why call arguments were always correct and only list elements were wrong.
#
# ⛔ WHY THE POSITION IS THE WHOLE POINT, AND WHY THIS GATE IS POSITIONAL RATHER THAN A SINGLE WITNESS
# (hq_B's landing condition): [7|9, 1] was CORRECT while [1, 7|9] and [1, 2, 7|9] were WRONG -- element 1 has
# no predecessor, so there is no forward edge to mis-wire and the box is entered at alpha by falling into it.
# Any future refactor of that chaining reintroduces the defect INVISIBLY unless the first-position control and
# the later-position witnesses are graded together, which is what this gate exists to do.
#
# ⛔ ONLY IR_DISJUNCTION EVER TRIPPED IT, and the non-alternation control pins that: gamma_to tested the ENTRY
# node lower() returned, and for "to" and "!" that entry is a plain operand node (alpha). IR_DISJUNCTION is the
# one construct that is simultaneously its own entry AND a generator kind.
#
# ⛔ list_alt_resume IS A WITNESS, NOT A CONTROL, and it was filed as one for exactly one sitting before the
# fail-once run corrected it: it reads RED pre-cure (74 alone, where the oracle wants the full 2x2 cross
# product 73 74 83 84), so it discriminates nothing about the cure DIRECTION and a control that is red before
# the cure is just a witness with a misleading name. It is kept because it also guards the OVER-CORRECTION --
# a cure that alpha-wired every generator entry rather than only the forward sibling edge would break the
# resume chain and this is the arm that would catch it -- but that second role does not make it a control.
#
# ⛔ THE DEFECT WAS A SILENT WRONG ANSWER AT rc=0, NEVER A CRASH, so no exit-code or crash-count gate anywhere
# could see it: arizona general/io.icn printed "no /dev/null" and died at source line 9 of 218 because the
# wrong branch ran stop() -- while /dev/null had opened perfectly well. Grade by VALUE against the oracle here,
# never by rc; an rc check on any of these six programs reads clean in both directions.
#
# rc=0 CLEAN (every witness and control matches the icont-cut ref in both modes), rc=1 VIOLATION (at least one
# does not), rc=2 UNPROVEN (no oracle, no fresh binary, a missing fixture, or a zero denominator).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="$(cd "$ROOT/.." && pwd)"
GATE_NAME=icn_list_element_alternation_position
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
ICONT="$(icont_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"

W="$S4E/corpus/tests/icon"
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

PROGS="list_alt_elem1_control list_alt_elem2_witness list_alt_elem3_witness list_alt_elem2_fail_witness list_alt_resume_witness list_alt_nonalt_gen_control"
CONTROLS=" list_alt_elem1_control list_alt_nonalt_gen_control "

red=0; examined=0
for p in $PROGS; do
    # ⛔ THE FIXTURE LIVES IN THE ICON RUNGS, NOT BESIDE IT (coo 2026-09-25, on the ceo's triage of hq_icon's report): corpus
    # a80ca7617 (09-10) absorbed these witnesses into tests/icon/ALL.icn after measuring each three ways, and deleted the loose
    # pairs; the rungs renamed each entry by feature (list_alt_elem1_control is procedure_every_elemgen_replace_11), and
    # ALL.csv keeps the old name in its origin column. So the gate refused "missing committed fixture" on every run since. It
    # now extracts each entry BY ORIGIN through the harness (the durable provenance key), byte-identical to the loose pair.
    mkdir -p "$T/fx"; src="$T/fx/$p.icn"; ref="$T/fx/$p.ref"
    python3 "$HERE/corpus_suite_harness.py" extract "$W/ALL.icn" "$W/ALL.ref" "" "$src" --origin "$p" --out-ref "$ref" >"$T/fx/$p.extract.out" 2>&1
    if [ ! -s "$src" ] || [ ! -f "$ref" ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: $p is not extractable by origin from $W/ALL.icn ($(tail -1 "$T/fx/$p.extract.out" | cut -c1-120))"; gate_stamp; exit 2
    fi
    if ( cd "$T" && timeout -k 5 30s "$ICONT" -s -o "$p.oracle" "$src" >/dev/null 2>&1 ) && [ -x "$T/$p.oracle" ]; then
        ( cd "$T" && timeout -k 5 10s "./$p.oracle" </dev/null >"$T/$p.oref" 2>&1 )
        if ! cmp -s "$T/$p.oref" "$ref"; then
            echo "RED  $p: committed ref disagrees with the live icont oracle -- re-cut it (oracle/ref drift, not this class)"
            red=$((red+1)); examined=$((examined+1)); continue
        fi
    else
        echo "GATE UNPROVEN(2) [$GATE_NAME]: icont could not build $p, so its ref cannot be re-anchored"; gate_stamp; exit 2
    fi
    is_control=0
    case "$CONTROLS" in *" $p "*) is_control=1;; esac
    ( cd "$T" && timeout -k 5 10s "$ROOT/scrip" "$src" </dev/null >"$T/$p.m3" 2>&1 )
    ok3=0; cmp -s "$T/$p.m3" "$ref" && ok3=1
    ok4=0
    if ( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile -o "$p.s" "$src" </dev/null >/dev/null 2>&1 ) \
       && ( cd "$T" && gcc -no-pie "$p.s" -o "$p.bin" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ); then
        ( cd "$T" && timeout -k 5 10s "./$p.bin" </dev/null >"$T/$p.m4" 2>&1 )
        cmp -s "$T/$p.m4" "$ref" && ok4=1
    fi
    examined=$((examined+1))
    tag="witness"; [ "$is_control" = 1 ] && tag="control"
    if [ "$ok3" = 1 ] && [ "$ok4" = 1 ]; then
        echo "PASS $p [$tag]: m3 and m4 both byte-match the icont-cut ref"
    else
        echo "RED  $p [$tag]: m3=$ok3/1 m4=$ok4/1 byte-match the icont-cut ref"
        [ "$ok3" = 0 ] && { echo "     m3 got: $(tr '\n' ' ' < "$T/$p.m3" 2>/dev/null)"; echo "     want:   $(tr '\n' ' ' < "$ref")"; }
        red=$((red+1))
    fi
done
gate_floor "$examined" 6 "witness/control programs"
gate_verdict "$red" "program(s) diverging from the icont oracle in either mode"
