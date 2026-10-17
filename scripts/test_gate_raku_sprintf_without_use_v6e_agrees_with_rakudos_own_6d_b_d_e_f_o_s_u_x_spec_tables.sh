#!/usr/bin/env bash
# test_gate_raku_sprintf_without_use_v6e_agrees_with_rakudos_own_6d_b_d_e_f_o_s_u_x_spec_tables.sh -- `sprintf` OF A PROGRAM THAT DOES NOT SAY `use v6.e` ANSWERS EVERY ROW OF RAKUDO'S OWN 6.d sprintf-b / -d / -e / -f / -o / -s / -u / -x TABLES
# (row raku-every-suite-to-100-under-nonet-ceo-1266; the sibling of test_gate_raku_sprintf_under_use_v6e_agrees_with_rakudos_own_b_d_e_f_o_s_u_x_spec_tables.sh, which runs the ten 6.e tables of S32-str/).
#
# THE REFERENCE is RAKUDO'S OWN SPEC for the language version Rakudo 2022.12 itself implements: the roast files /home/resources/roast-master/6.d/S32-str/sprintf-{b,d,e,f,o,s,u,x}.t (each a table of flags, size and the expected strings for four values, expanded over every flag permutation), the LEGACY formatter of nqp's src/HLL/sprintf.nqp. This gate RUNS THEM, unmodified, in m3 (--run) and m4 (--compile + link), under their own `BEGIN %*ENV<RAKU_TEST_DIE_ON_FAIL> = True`; a run is green when its exit status is 0, it prints no `not ok`, its plan is at least 900 and its `ok` count equals its plan (a plan of 0 is the table EMPTY, which is what the control build cfcfaf46d prints for them, and a refusal or a crash prints no plan). Without the roast checkout the gate REFUSES rc=2.
# THE DIFFERENCES FROM 6.e that the tables pin: the sign flags `+` and space apply to %b too (6.e: only d and i); %o and %x put the `0` / `0x` prefix BEFORE the sign of a negative value; %s zero-pads only when it has no precision; `%0-8.2f` pads WITH the sign quirk of the legacy formatter (`0000.000`-style, the statement-level pad character); the precision of %d counts the sign; %e and %f are built from the shortest decimal representation of the number (stringify-to-precision), not the C conversion.
# THE CURE: (by_name_dispatch.c rk_rsprintf_legacy, reached as __rk_sprintf_d / __rk_printf_d) the legacy formatter; lower_raku.c rk_sprintf_names renames sprintf and printf to the 6.e or the legacy form by whether the program says `use v6.e` (rk_uses_v6e), when the program declares no routine of that name.
# NOT HERE (own rows, measured): 6.d/S32-str/sprintf-c.t (every row's first value is chr(0) and a string literal "\0" cannot hold a NUL), 6.d/S32-str/sprintf.t (`variable 'Free' is read but never assigned`: an enum with a pair-list `enum Str ( :Free<f>, :Inuse<n> )`), %g and %a exactness, big integers in %b / %o / %x.
#
# EXIT: 0 every run is green in both modes; 1 a failing row or a crash; 2 REFUSED (stale binary, no gcc, no roast checkout).
# Usage: bash ../harness/scripts/test_gate_raku_sprintf_without_use_v6e_agrees_with_rakudos_own_6d_b_d_e_f_o_s_u_x_spec_tables.sh   (~10s, needs /home/resources/roast-master)
# Usage: bash ../harness/scripts/test_gate_raku_sprintf_under_use_v6e_agrees_with_rakudos_own_b_d_e_f_o_s_u_x_spec_tables.sh   (~10s, needs /home/resources/roast-master)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_sprintf_without_use_v6e_agrees_with_rakudos_own_6d_b_d_e_f_o_s_u_x_spec_tables"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
R=/home/resources/roast-master/6.d/S32-str
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
