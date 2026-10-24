#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_coupling.sh — PL-GZ-1 coupling gate (GOAL-PROLOG-BB, Prolog Ground Zero rung 1).
# Counts CONTROL-coupling call sites emitted by Prolog BB templates and in a representative emitted .s.
# The control-symbol set is NORMATIVE per the GOAL PL-GZ-1 text:
#     resolve_cp_current  rt_last_ok  rt_get_cut_flag  resolve_bb_env_*  rt_env_current
#     rt_choice_cut_*     rt_cp_save_caller_env
# VALUE calls (rt_unify_terms / rt_pl_arith / write helpers / trail ops — the strchr class) are SANCTIONED
# and not counted.  A call site == one comment-stripped `SYM@PLT` occurrence (the emitted-call form; extern
# declarations and C++ template-side helper code do not count).
# RESET BASELINE measured 2026-06-04 at SCRIP 3edcffa under the normative set:
#     bb_choice.cpp 19 (resolve_cp_current x10 + cut protocol x6 + env x1 + flag x2)
#     bb_goal.cpp   10 (env install/save/pop x5 + cp_current x2 + last_ok x2 + cp_save_caller_env x1)
#     ALL OTHER TEMPLATES 0  ·  rung05_backtrack emitted .s 39
# (The reset handoff's 24/14/4 figures counted a wider set incl. CP-push/trail/unify sites; bb_unify's 4
# were rt_unify_* VALUE calls == sanctioned == 0 here.  The normative set above is the gate.)
# RATCHET: counts only go DOWN — when a session reduces coupling it ALSO lowers the ceiling here; a NEW
# template starts and stays at ceiling 0 (PL-GZ new-path boxes emit ZERO control calls).
# Optional arg 1: alternate BB_templates dir (negative-test hook).  Exit 0 iff every count <= its ceiling.
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet  DATE: 2026-06-04
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
TPL="${1:-$ROOT/src/templates}"
SCRIP="${SCRIP:-$ROOT/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/prolog}"
SYMS='resolve_cp_current|rt_last_ok|rt_get_cut_flag|resolve_bb_env_[a-z_]*|rt_env_current|rt_choice_cut_[a-z_]*|rt_cp_save_caller_env'
ceiling() {
    case "$1" in
        bb_choice.cpp) echo 19 ;;
        bb_goal.cpp)   echo 10 ;;
        *)             echo 0  ;;
    esac
}
S_CEIL=39
FAIL=0
printf "%-34s %6s %8s\n" "template" "count" "ceiling"
for f in "$TPL"/*.cpp; do
    b="$(basename "$f")"
    n=$(gcc -fpreprocessed -dD -E -P "$f" 2>/dev/null | grep -oE "($SYMS)@PLT" | wc -l)
    c=$(ceiling "$b")
    if [ "$n" -gt 0 ] || [ "$c" -gt 0 ]; then printf "%-34s %6d %8d\n" "$b" "$n" "$c"; fi
    if [ "$n" -gt "$c" ]; then
        echo "FAIL: $b emits $n control-coupling call sites (ceiling $c) — the count ratchets DOWN, never up"
        FAIL=1
    fi
done
RUNG="$CORPUS/rung05_backtrack_backtrack.pl"
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_floor "$(ls "$(dirname "$0")"/../src/emitter/*.cpp "$(dirname "$0")"/../src/templates/{bb,xa}/*.cpp 2>/dev/null | wc -l)" 100 "emitter/template source files"
if [ -x "$SCRIP" ] && [ -f "$RUNG" ]; then
    W="$(mktemp -d /tmp/plcoup_XXXXXX)"
    trap 'rm -rf "$W"' EXIT INT TERM
    cp "$RUNG" "$W/prog.pl"
    ( cd "$W" && timeout -k 5 8 "$SCRIP" --compile --target=x86 prog.pl > prog.s 2>/dev/null < /dev/null )
    sn=$(grep -oE "($SYMS)@PLT" "$W/prog.s" 2>/dev/null | wc -l)
    printf "%-34s %6d %8d\n" "rung05_backtrack emitted .s" "$sn" "$S_CEIL"
    if [ "$sn" -gt "$S_CEIL" ]; then
        echo "FAIL: rung05 .s emits $sn control-coupling call sites (ceiling $S_CEIL)"
        FAIL=1
    fi
    rm -rf "$W"
else
    echo "NOTE: emitted-.s leg skipped (scrip binary or corpus rung05 not found)"
fi
[ "$FAIL" -eq 0 ] && echo "PASS: Prolog control-coupling at/below the PL-GZ reset baseline (choice 19 · goal 10 · others 0 · rung05 .s 39)."
exit $FAIL
