#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_a_nested_alternation_receded_into_resumes_its_own_arm_not_the_outer_beta.sh -- A NESTED ALTERNATION
# RECEDED INTO AFTER ITS INNER ARM SUCCEEDED MUST RESUME THAT ARM, NOT PING-PONG WITH THE OUTER BETA.
# Row snobol4-a-nested-alternation-receded-into-after-its-inner-arm-succeeded-ping-pongs-between-the-two-beta-ports-forever
# (cto, 2026-09-12; CEO-564's third mechanism, fuzz name arbno_fence_span_replace_branch_2 -- no ARBNO, no FENCE in it).
# bb_match_alternate's ALT-FLAT arm kept its record as a 32B rsp-carved cell addressed as [rsp+k] from every port; when
# alternative k is itself an alternation its record is still on the stack at the outer's gamma, so the outer's sigma
# stub wrote its beta target into the INNER's record and outer beta / inner beta read one cell and jumped to each other
# forever. The sigma stub now pushes a 16B cell holding the beta target at the alternative's own gamma-time stack top
# and beta pops it. Every expectation is PINNED from SPITBOL x64 (/home/resources/x64) measured 2026-09-12; the gate is
# hermetic (mktemp witnesses) and never consults the oracle at run time; it grades OUTPUT in both modes, never rc.
#
# ⛔ c1/c2/c3/w4 ARE THE LOAD-BEARING CONTROLS: c1 succeeds without ever receding, c2 is the FLAT form of the same
# three arms, c3 recedes into a plain literal arm, and w4 recedes into the inner alternation and then SUCCEEDS on
# its next arm -- a cure that merely stopped the loop by conceding would leave w4 red.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
. "$HERE/lib_gate.sh"
GATE_NAME="a_nested_alternation_receded_into_resumes_its_own_arm_not_the_outer_beta"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT:-$ROOT/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: scrip not built at $SCRIP"; exit 2; }
[ -f "$RT/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: $RT/libscrip_rt.so missing -- mode 4 cannot link"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not on PATH -- mode 4 cannot link"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_nestalt.XXXXXX")" || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
gate_bin_watch "$SCRIP" "$RT/libscrip_rt.so"

TAIL="OK        OUTPUT = 'match'                      :(END)
NO        OUTPUT = 'nomatch'
END"
probe() { printf '%s\n%s\n' "$3" "$TAIL" > "$W/$1.sno"; printf '%s' "$2" > "$W/$1.want"; }
probe w1_inline_nested   'nomatch' "          'bz' ('a' | ('b' | 'c')) 'y'                          :S(OK)F(NO)"
probe w2_corpus_shape    'nomatch' "          P             =  (SPAN(' ') | (NOTANY('abc') | NOTANY('+'))) TAB(0)
          'aaa' *P RPOS(0)                          :S(OK)F(NO)"
probe w3_deferred_nested 'nomatch' "          P             =  ('a' | ('b' | 'c')) 'y'
          'bz' *P                          :S(OK)F(NO)"
probe w4_recede_then_win 'match'   "          'bz' ('a' | ('b' | 'bz')) RPOS(0)                          :S(OK)F(NO)"
probe w5_three_levels    'nomatch' "          'bz' ('a' | ('b' | ('c' | 'd'))) 'y'                          :S(OK)F(NO)"
probe c1_inner_wins_ctl  'match'   "          'b' ('a' | ('b' | 'c'))                          :S(OK)F(NO)"
probe c2_flat_ctl        'nomatch' "          'x' ('a' | 'b' | 'c')                          :S(OK)F(NO)"
probe c3_plain_recede    'match'   "          'cz' ('a' | ('b' | 'c')) 'z'                          :S(OK)F(NO)"

red=0; n=0
for src in "$W"/[wc]*.sno; do
    b="$(basename "$src" .sno)"; want="$(cat "$W/$b.want")"; n=$((n+1))
    m3="$(cd "$W" && timeout -k 5 20 "$SCRIP" "$b.sno" </dev/null 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
    m4="(compile/link failed)"
    if (cd "$W" && "$SCRIP" --compile "$b.sno" </dev/null > "$b.s" 2>/dev/null && gcc -c "$b.s" -o "$b.o" 2>/dev/null \
        && gcc "$b.o" -L"$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" -o "$b.m4" 2>/dev/null); then
        m4="$(cd "$W" && timeout -k 5 20 "./$b.m4" </dev/null 2>/dev/null | tr '\n' '|' | sed 's/|$//')"
    fi
    v=GREEN; { [ "$m3" = "$want" ] && [ "$m4" = "$want" ]; } || { v=RED; red=$((red+1)); }
    printf '  %-20s want=%-9s m3=%-9s m4=%-9s %s\n' "$b" "[$want]" "[$m3]" "[$m4]" "$v"
done
gate_bin_unmoved
GATE_EXAMINED="$n arms (8 probes x m3+m4 output)"
gate_floor "$n" 8 "arms run"
gate_verdict "$red" "arm(s) disagree with the pinned SPITBOL output (a HANG reads as an empty answer)"
