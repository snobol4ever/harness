#!/usr/bin/env bash
# test_gate_sno_pattern_position_expression.sh -- AN ARBITRARY EXPRESSION IN PATTERN POSITION LOWERS, and the
# gate that its acceptance is NOT decided by a per-op allowlist.
#
# THE CLASS. A SNOBOL4 statement `SUBJECT PATTERN` may carry, as its PATTERN, any expression whose VALUE is
# the pattern -- SNOBOL4 evaluates the pattern expression first, then matches. lower_snobol4.c has always had
# the correct general machinery for this (the runtime-pattern fallback at the sno_pat_supported() miss: stage
# the expression into SCP$n (a subject that is not a variable or literal first into SCS$n, as SPITBOL evaluates subject before pattern), match the subject against the deferred temp, omega wired to the statement's
# failure branch). Until 2026-09-06 that fallback was gated on a PER-OP ALLOWLIST --
# `ptt->t == TT_FNC || ptt->t == TT_INDIRECT || sno_is_pattern_rhs(ptt)` -- and every expression kind not
# enumerated there died at sno_fatal instead, WITH A MESSAGE BLAMING "Pattern matching, EVAL and CODE".
#
# ⛔ THAT SHAPE IS BANNED BY NAME (RULES.md, NO PER-OP FILTER): "no code path may admit or refuse family
# members by op identity, and no per-op exception list may exist anywhere. A defect reachable through one
# member is a class defect: fix the class or leave the class visibly red." The allowlist was deleted rather
# than extended; sx_lower now refuses on its own terms, with its own accurate message, for expression forms it
# genuinely cannot lower.
#
# ⭐ WHY THE CONTROL ARMS ARE THE POINT OF THIS GATE. pat_expr_fnc_control.sno (`subject SIZE(word)`) PASSED
# before the cure and passes after -- not because a function call is special, but because TT_FNC happened to
# be one of the three names on the list. pat_expr_arith.sno (`subject counter + 1`) is the same kind of thing
# and died. A gate that only swept the newly-cured forms could not tell "the class is cured" from "three more
# names were added to the list"; the control arm is what makes that distinguishable.
#
# WITNESSES (corpus/tests/snobol4, .ref cut from the oracle, never hand-typed):
#   pat_expr_interrogate         `subject ?side('one') ?side('two')`  -- unary ?, operands succeed, in order
#   pat_expr_interrogate_fail    `subject ?failer()`                  -- unary ?, operand FAILS => stmt fails
#   pat_expr_interrogate_mixed   `SPAN('abc') ?side('mid') SPAN('123') . digits` -- composes with real pattern
#                                                                       functions AND a capture. ⛔ CONTROL:
#                                                                       this one PASSED BEFORE the cure too --
#                                                                       sno_is_pattern_rhs(TT_SEQ) is true if
#                                                                       EITHER child qualifies, so the SPAN
#                                                                       dragged the whole pattern onto the
#                                                                       allowlist. `subject ?side('mid')` was
#                                                                       FATAL while `subject SPAN('abc')
#                                                                       ?side('mid')` worked -- the same
#                                                                       operator, decided by what stood next
#                                                                       to it. That accident is the argument
#                                                                       against per-op gating, and it is why
#                                                                       this witness is a control, not a cure.
#   pat_expr_negation            `subject ~failer()`                  -- unary ~, same manual section as ?
#   pat_expr_arith               `subject counter + 1`                -- an expression that is not an operator
#                                                                       of the pattern language at all
#   pat_expr_fnc_control         `subject SIZE(word)`                 -- CONTROL: passed before the cure too
#
# Row snobol4-code-and-eval-outside-the-lowering-subset-blocks-ais-sir-and-test (hq_P). FINDING-2026-09-06-
# hq_P-the-ais-code-and-eval-refusal-was-not-code-or-eval-but-a-per-op-allowlist-refusing-expressions-the-
# fallback-already-handled.md carries the measured trees and the argument that the edit is confined to the
# region that previously ended in sno_fatal, so it cannot regress a program that compiles today.
#
# rc=0 CLEAN (every witness matches its oracle-cut ref in BOTH modes), rc=1 VIOLATION, rc=2 UNPROVEN (no
# oracle, no fresh binary, a missing witness, or a zero denominator -- never printed as a pass).
# THE SIX PROGRAMS ARE MASTER ENTRIES (hq_snobol4 2026-10-17, row snobol4-absorb-every-owed-source-into-the-one-master-
# unabsorbed-census-reads-zero): each is extracted from tests/snobol4/ALL.{sno,ref} by its ORIGIN (its old loose basename,
# the durable key in ALL.csv), never by the entry name the builder assigns and may re-sort.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
S4E="$(cd "$ROOT/.." && pwd)"
GATE_NAME=sno_pattern_position_expression
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh"          || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
[ -f "$ROOT/out/libscrip_rt.so" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no $ROOT/out/libscrip_rt.so"; exit 2; }

W="$S4E/corpus/tests/snobol4"
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

PROGS="pat_expr_interrogate pat_expr_interrogate_fail pat_expr_interrogate_mixed pat_expr_negation pat_expr_arith pat_expr_fnc_control"
CONTROLS=" pat_expr_interrogate_mixed pat_expr_fnc_control "

n=0; bad=0; ctl_seen=0
for p in $PROGS; do
    python3 "$HERE/corpus_suite_harness.py" extract "$W/ALL.sno" "$W/ALL.ref" --origin "$p" "$T/w_$p.sno" --out-ref "$T/w_$p.ref" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the master entry of origin $p could not be extracted from $W/ALL.{sno,ref,csv}"; exit 2; }
    [ -f "$T/w_$p.sno" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: missing witness $T/w_$p.sno"; exit 2; }
    [ -f "$T/w_$p.ref" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: missing oracle-cut ref $T/w_$p.ref"; exit 2; }
done

for p in $PROGS; do
    n=$((n+1))
    case "$CONTROLS" in *" $p "*) ctl_seen=$((ctl_seen+1));; esac
    ( cd "$T" && timeout -k 5 30s "$ROOT/scrip" "$T/w_$p.sno" </dev/null >"$T/$p.m3" 2>&1 )
    if ! diff -q "$T/w_$p.ref" "$T/$p.m3" >/dev/null 2>&1; then
        bad=$((bad+1)); echo "⛔ $p: mode-3 DIVERGES from its oracle-cut ref"
        diff "$T/w_$p.ref" "$T/$p.m3" | head -6
        continue
    fi
    if ! ( cd "$T" && timeout -k 5 60s "$ROOT/scrip" --compile -o "$p.s" "$T/w_$p.sno" </dev/null >/dev/null 2>&1 ); then
        bad=$((bad+1)); echo "⛔ $p: mode-4 COMPILE failed"; continue
    fi
    if ! ( cd "$T" && gcc -no-pie "$p.s" -o "$p.bin" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ); then
        bad=$((bad+1)); echo "⛔ $p: mode-4 LINK failed"; continue
    fi
    ( cd "$T" && timeout -k 5 30s "./$p.bin" </dev/null >"$T/$p.m4" 2>&1 )
    if ! diff -q "$T/w_$p.ref" "$T/$p.m4" >/dev/null 2>&1; then
        bad=$((bad+1)); echo "⛔ $p: mode-4 DIVERGES from its oracle-cut ref"
        diff "$T/w_$p.ref" "$T/$p.m4" | head -6
    fi
done

[ "$n" -gt 0 ]        || { echo "GATE UNPROVEN(2) [$GATE_NAME]: zero witnesses graded -- an empty board is not a pass"; exit 2; }
[ "$ctl_seen" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the control arm did not run -- without it a pass cannot distinguish a cured class from a longer allowlist"; exit 2; }

if [ "$bad" -ne 0 ]; then
    echo "⛔ GATE VIOLATION [$GATE_NAME]: $bad of $n witnesses diverge (both modes graded, control arms included)"
    exit 1
fi
echo "✅ GATE OK [$GATE_NAME]: $n/$n witnesses match their oracle-cut refs in BOTH modes ($ctl_seen control arm(s) included)"
exit 0
