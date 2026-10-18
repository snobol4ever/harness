#!/usr/bin/env bash
# test_gate_raku_sprintf_under_use_v6e_agrees_with_rakudos_own_b_d_e_f_o_s_u_x_spec_tables.sh -- `sprintf` OF A FILE THAT SAYS `use v6.e.PREVIEW` ANSWERS EVERY ROW OF RAKUDO'S OWN sprintf-b / -d / -e / -f / -o / -s / -u / -x SPEC FILES, AS DOES EACH THING THOSE FILES NEED OF THE REST OF THE LANGUAGE
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by running S32-str/sprintf-*.t, whose 20 files (ten in S32-str/ for 6.e, ten in 6.d/S32-str/) make 2282 to 9128 sub-tests each and all failed or crashed).
#
# THE REFERENCE is not an installed Rakudo (2022.12 predates the 6.e formatter: its `use v6.e.PREVIEW` sprintf answers the 6.d results) but RAKUDO'S OWN SPEC: the roast files /home/resources/roast-master/S32-str/sprintf-{b,d,e,f,o,s,u,x}.t, each a table of (flags, size, expected string for four values) expanded over every flag permutation. This gate RUNS THEM, unmodified, in m3 (--run) and m4 (--compile + link), under their own `BEGIN %*ENV<RAKU_TEST_DIE_ON_FAIL> = True` (a failing row aborts the run, rc != 0); a run is green when its exit status is 0, it prints no `not ok`, its plan is at least 900 (every table makes 978 to 4564 sub-tests; a plan of 0 is the table EMPTY, which is what the control build prints) and its `ok` count equals its plan. Without the roast checkout the gate REFUSES rc=2 (it cannot measure).
# THE CONTROL: on the sitting's control build cfcfaf46d every one of the eight files is VACUOUS (`1..0`, rc 0: the tables are built with `.permutations`, which quietly failed, so no sub-test ran); once the list methods exist the files run and the defects below show (`ok=0 nok=N` and a SIGSEGV in five of the eight files).
# THE DEFECTS: (1) the harness's `sprintf($format, |.value)` passed the slip as ONE argument (the builtin did not flatten a Slip; Rakudo also takes a single List argument as the argument list); (2) a numeric-looking STRING that became an item of a list or the key or value of a Pair became an Int (rk_spill_scalar ran every string through elem_to_descr), so `("0" => 1).key.WHAT` was Int and `is-deeply sprintf(..), "0"` failed on `expected: 0  got: 0`; (3) `@flat.append(7, '%d', (pairs))` flattened the third argument (Rakudo's append flattens only a SINGLE argument); (4) `subtest` held its description as a pointer into a heap string across the block, so with thousands of sub-tests the collector moved it and rk_tap_proclaim read a stale address (SIGSEGV, ZGC-STALE); (5) the C-library formatting under the name `sprintf` is not Rakudo's: %b %B %o %x %X print two's complement for a negative number where Rakudo prints a sign and the digits, ignore the precision of a zero, mishandle `#` and the `0` flag, `%u` honours `+` and space, `%s` ignores `0`, `%c` is wrong, `%.0g`; `%0-8.2f` left-justifies where Rakudo zero-pads.
# THE CURE: (by_name_dispatch.c rk_rsprintf, reached as __rk_sprintf / __rk_printf) a formatter written to the spec tables: sign, then the 0b / 0B / 0 / 0x / 0X prefix of a nonzero value under `#`, then precision-padded digits (an empty digit string for precision 0 of zero), width padding on the left, on the right under `-`, or zeros between the prefix and the digits under `0` when no precision is given; `+` and space only for d and i; floats through the C conversion with the `0` flag taking precedence over `-`; %s truncates by characters and zero-pads; %c from a code point; explicit argument indexes (`%2$s`); a `*` for width or precision. The lowerer routes sprintf and printf to it ONLY in a program that says `use v6.e` (rk_uses_v6e / rk_sprintf_names), because the 6.d files expect the older results, which the sibling gate test_gate_raku_sprintf_without_use_v6e_agrees_with_rakudos_own_6d_b_d_e_f_o_s_u_x_spec_tables.sh grades (rk_rsprintf_legacy). The four general changes above are on for every program.
# NOT HERE (own rows, measured): S32-str/sprintf-c.t (every row's first value is chr(0) and a string literal "\0" cannot hold a NUL: the literal, chr(0).chars and "a\0b" are all wrong), S32-str/sprintf.t (`variable 'Free' is read but never assigned`), %g, %a, big integers in %b / %o / %x.
#
# EXIT: 0 every run is green in both modes; 1 a failing row or a crash; 2 REFUSED (stale binary, no gcc, no roast checkout).
# Usage: bash ../harness/scripts/test_gate_raku_sprintf_under_use_v6e_agrees_with_rakudos_own_b_d_e_f_o_s_u_x_spec_tables.sh   (~10s, needs /home/resources/roast-master)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_sprintf_under_use_v6e_agrees_with_rakudos_own_b_d_e_f_o_s_u_x_spec_tables"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
R=/home/resources/roast-master/S32-str
[ -f "$R/sprintf-b.t" ] || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: the roast checkout is missing ($R/sprintf-b.t) -- the spec tables are the reference, so nothing can be measured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
fails=0; GATE_EXAMINED=0
ck() {
    local f="$1" m="$2" out rc plan okn nok
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    cp "$R/sprintf-$f.t" "$W/sp_$f.raku"
    if [ "$m" = m3 ]; then out="$(cd "$R" && timeout -k 5 300 "$ROOT/scrip" --run "$W/sp_$f.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! (cd "$R" && timeout -k 5 120 "$ROOT/scrip" --compile -o "$W/sp_$f.s" "$W/sp_$f.raku" </dev/null >"$W/sp_$f.cerr" 2>&1) \
           || ! gcc -o "$W/sp_$f.bin" "$W/sp_$f.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/sp_$f.cerr" 2>&1; then
            printf '  FAIL %-9s %s: did not build (%s)\n' "sprintf-$f" "$m" "$(head -1 "$W/sp_$f.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(cd "$R" && timeout -k 5 300 "$W/sp_$f.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    plan="$(printf '%s\n' "$out" | grep -m1 -oE '^1\.\.[0-9]+' | cut -c4-)"
    okn="$(printf '%s\n' "$out" | grep -c '^ok ')"; nok="$(printf '%s\n' "$out" | grep -c '^not ok')"
    if [ "$rc" -eq 0 ] && [ "$nok" -eq 0 ] && [ -n "$plan" ] && [ "$plan" -ge 900 ] && [ "$okn" -eq "$plan" ]; then printf '  ok   %-9s %s (%s of %s)\n' "sprintf-$f" "$m" "$okn" "$plan"
    else printf '  FAIL %-9s %s: rc=%s ok=%s not-ok=%s plan=%s\n' "sprintf-$f" "$m" "$rc" "$okn" "$nok" "${plan:-none}"; fails=$((fails + 1)); fi
}
for f in b d e f o s u x; do for m in m3 m4; do ck "$f" "$m"; done; done
gate_verdict "$fails" "run(s) of Rakudo's own sprintf spec tables failed"
