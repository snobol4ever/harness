#!/usr/bin/env bash
# test_gate_raku_the_infix_operators_the_front_end_names_have_a_runtime_as_rakudos_do.sh -- THE OPERATORS THE PARSER TURNS INTO __rk_ CALLS THE RUNTIME NEVER IMPLEMENTED
# (row raku-every-suite-to-100-under-nonet-ceo-1266; ceo CEO-1479). Measured with the sanctioned inventory plus a harvest of the name behind every error 22 across the
# Roast tree: 173 files abort with "undefined function called", and after is_run (Test::Util, 41) the next names are operators the front end generates and the runtime
# does not handle: __rk_not_smartmatch (15), __rk_range_xb and __rk_range_xl (5), __rk_bor, __rk_lbor, __rk_gcd, __rk_lcm and more. A cross-check of every __rk_ name the
# parser and lowerer generate against the names by_name_dispatch.c handles found 57 unhandled. This landing adds: !~~, ^.. and ^..^, +| +^ +&, ?| ?^, ~| ~&, gcd, lcm,
# =~= (relative tolerance 1e-15), before, after, ^^ (exactly one true), coll, unicmp, (elem) and (cont) over a list; +^ was not in the additive level's operator list (5 +^ 1
# printed 5) and is now. And the smartmatch itself: a type object on the right (5 ~~ Int) asks isa, and a block or WhateverCode on the right is called with the topic
# (5 ~~ (* > 3)), where both answered by comparing text and read False.
# NOT HERE, each its own row: the Set and Bag operators ((|) (&) (-) (^) (.) (+), the Unicode forms) which need Set and Bag types, the function composition operator o (needs closures,
# the M3 row), the gist of a Range value (say 1..^4 prints 1), and // over a type object.
# FAILED ONCE, measured on SCRIP b8a92c934: the witness dies at its first line (error 22) in both modes.
# EXIT: 0 the witness matches Rakudo in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_infix_operators_the_front_end_names_have_a_runtime_as_rakudos_do.sh   (~2s)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_infix_operators_the_front_end_names_have_a_runtime_as_rakudos_do"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/infixops.raku" <<'EOF'
say "abc" !~~ /z/;
say 5 !~~ Int;
say 5 ~~ (* > 3);
say 2 ~~ (* > 3);
say 4 ~~ { $_ %% 2 };
say 5 ~~ Int;
say "a" ~~ Int;
say (1^..4).list;
say (1^..^4).list;
say 5 +| 2;
say 5 +^ 3;
say 6 +& 3;
say 1 ?| 0;
say 0 ?| 0;
say 1 ?^ 1;
say 1 ?^ 0;
say "a" ~| "b";
say "ab" ~& "ac";
say 12 gcd 18;
say 4 lcm 6;
say -4 lcm 6;
say 1 =~= 1.0000000001;
say 1 =~= 1.0;
say 1 before 2;
say "b" before "a";
say 2 after 1;
say 1 ^^ 0;
say (0 ^^ 0);
say "a" coll "b";
say "b" unicmp "a";
say 1 (elem) (1, 2);
say 3 (elem) (1, 2);
say (1, 2) (cont) 2;
EOF
cat > "$W/infixops.ref" <<'EOF'
True
False
True
False
True
True
False
(2 3 4)
(2 3)
7
6
2
True
False
False
True
c
ab
6
12
12
False
True
True
False
True
1
0
Less
More
True
False
True
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
for w in infixops; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: an infix operator the front end generates that the runtime lacks or answers differently from Rakudo"
