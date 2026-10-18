#!/usr/bin/env bash
# test_gate_raku_the_math_and_list_routines_answer_in_function_form_as_rakudos_do.sh -- THE ROUTINES RAKU OFFERS BOTH AS A FUNCTION AND AS A METHOD
# (row raku-every-suite-to-100-under-nonet-ceo-1266; ceo CEO-1479). The harvest of the name behind every error 22 across the Roast tree (173 files abort with "undefined function
# called") and an oracle probe of the builtin surface found the function forms of the standard math and list routines unresolved: floor(2.5), ceiling, round, truncate, sign, log2,
# log10, sinh, cosh, tanh, asinh, acosh, atanh, sec, cosec, cotan, atan2, keys(%h), values, kv, pairs, elems(@a), end(@a), shift(@a), pop(@a), unshift(@a, x), ords, map and
# grep and first with a leading block in parentheses (map({ $_ * 2 }, 1, 2) iterated only its first item); and several of the method forms did not exist (asin acos atan sinh
# cosh tanh asinh acosh atanh log2 log10 sec cosec cotan atan2 sign Num is-prime base parse-base ords). lower_raku.c rewrites the function form of the names in rk_is_str_subform
# (now including the math and list names) to the method form when no user sub of that name exists, rewrites shift, pop and unshift of an array variable to the method (which
# assigns back), and gives map, grep and first with a leading block a list of the remaining arguments; by_name_dispatch.c adds the methods. Rakudo does not flatten array
# arguments of map (map({ $_ + 1 }, @a, @b) takes the two arrays as items); a multi-argument map here keeps them items too.
# NOT HERE, each its own row: sleep, hash(), splice, chrs, minmax, repeated, squish, rotor, batch, combinations, permutations, zip and roundrobin as functions, comb(n), indent, samecase,
# expmod, Rat, roots.
# FAILED ONCE, measured on SCRIP 98fbc5031: the witness aborts at floor(2.5) with error 22 in both modes.
# EXIT: 0 the witness matches Rakudo in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_math_and_list_routines_answer_in_function_form_as_rakudos_do.sh   (~2s)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_math_and_list_routines_answer_in_function_form_as_rakudos_do"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/libfns.raku" <<'EOF'
say floor(2.5); say ceiling(2.5); say round(2.5); say truncate(2.5); say sign(2.5); say sign(-3); say sign(0);
say log2(1.5); say log10(1.5);
say sinh(1.5); say cosh(1.5); say tanh(1.5); say asinh(1.5); say acosh(1.5); say atanh(0.5);
say (0.5).asin; say (0.5).acos; say (0.5).atan; say (1.5).sec; say (1.5).cosec; say (1.5).cotan;
say atan2(1, 2); say 1.atan2(2);
my %h = a => 1;
say keys(%h); say values(%h);
my @a = 1, 2, 3;
say elems(@a); say end(@a);
say shift(@a); say @a;
unshift(@a, 0); say @a;
say pop(@a); say @a;
say ords("ab"); say "é".ords;
say map({ $_ * 2 }, 1, 2); say grep({ $_ > 1 }, 1, 2, 3); say first({ $_ > 1 }, 1, 2, 3);
say 7.is-prime; say 8.is-prime; say 255.base(16); say "ff".parse-base(16); say "5".Int; say 5.Num;
EOF
cat > "$W/libfns.ref" <<'EOF'
2
3
3
2
1
-1
0
0.5849625007211562
0.17609125905568124
2.1292794550948173
2.352409615243247
0.9051482536448664
1.1947632172871094
0.9624236501192069
0.5493061443340549
0.5235987755982989
1.0471975511965979
0.4636476090008061
14.136832902969903
1.0025113042467249
0.07091484430265245
0.4636476090008061
0.4636476090008061
(a)
(1)
3
2
1
[2 3]
[0 2 3]
3
[0 2]
(97 98)
(233)
(2 4)
(2 3)
2
True
False
FF
255
5
5
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(timeout -k 5 20 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(timeout -k 5 20 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s\n' "$w" "$m"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
for w in libfns; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a math or list routine whose function form is unresolved or answers differently from Rakudo"
