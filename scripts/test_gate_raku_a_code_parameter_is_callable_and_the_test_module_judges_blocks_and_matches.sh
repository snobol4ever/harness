#!/usr/bin/env bash
# test_gate_raku_a_code_parameter_is_callable_and_the_test_module_judges_blocks_and_matches.sh -- THE HIGHER-ORDER SUB AND THE TEST FUNCTIONS THE ROAST SURVEY FOUND MISSING
# (row raku-every-suite-to-100-under-nonet-ceo-1266; ceo CEO-1479). Measured by the sanctioned non-publishing inventory (raku_roast_scoreboard.sh --inventory) plus a
# per-file TAP count: of 360 Roast files that run and fail, 190 hit a Test function SCRIP reported as PARSED BUT NOT IMPLEMENTED (throws_like 100, dies_ok 62,
# lives_ok 61, eval_lives_ok 21), and a call of a missing function (like, unlike, or a code parameter) is error 22 that ends the run.
# 1. A CODE PARAMETER IS CALLABLE. sub apply(&f) { f(3) } died "undefined function": only my &g declarations registered g as a code variable. rk_tree.c rkb_param now
#    registers an &-sigil parameter for the extent of its routine or pointy block (rk_pcv_release un-registers it, comparing by content, and keeps an outer &name
#    that was already declared), so f(3), &f(3) and f() invoke it and a named sub f declared elsewhere keeps its meaning outside. A reference to a known named sub,
#    &inc, lowers to its block value (lower_raku.c), so twice(&inc, 5) and my $r = &inc work.
# 2. lives-ok, dies-ok (the TAP of Rakudo's Test: the dash spellings Roast uses), like and unlike are built as trees by the parser (rk_testop_shape): lives-ok and
#    dies-ok run the block under try and judge the outcome through ok; like and unlike are ok and nok of a smartmatch (the match, a goal failure when it does not
#    match, is turned into a boolean by a ternary, which also cures ok "abc" ~~ /z/ losing its whole call). throws-like and the eval forms stay honestly unimplemented
#    (a throws-like with no exception types would be a false green).
# 3. @_ IN A SUB WITH NO SIGNATURE is its argument list: rkb_routine gives a sub that has no parameter list and reads @_ an implicit slurpy @_ (the argsunder witness; 18 Roast
#    files first-refused on the unresolved variable @_).
# FAILED ONCE, measured on SCRIP a24fe1546: hof dies "undefined function", testfns is refused or loses its failing-match lines.
#
# EXIT: 0 both witnesses match Rakudo in both modes; 1 a mismatch or a crash; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_code_parameter_is_callable_and_the_test_module_judges_blocks_and_matches.sh   (~2s)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_code_parameter_is_callable_and_the_test_module_judges_blocks_and_matches"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/hof.raku" <<'EOF'
sub apply(&f) { f(3) }
say apply({ $_ + 1 });
sub apply2(&f) { &f(3) }
say apply2({ $_ + 1 });
sub apply3(&f) { return &f(3) }
say apply3(-> $x { $x * 2 });
sub apply0(&f) { f() }
say apply0({ 7 });
sub inc($n) { $n + 1 }
sub twice(&f, $x) { f(f($x)) }
say twice(&inc, 5);
say twice(-> $v { $v * 2 }, 5);
my $r = &inc;
say $r(5);
say (1, 2, 3).map(&inc);
sub f($x) { $x * 10 }
sub g(&f) { f(2) }
say f(1);
say g({ $_ + 100 });
say f(3);
my &h = { $_ * 3 };
sub k(&h) { h(1) }
say k({ 9 });
say h(4);
sub lives(&c, $d = "") {
    my $ok = True;
    try { c(); CATCH { default { $ok = False } } }
    say "$d: $ok";
}
lives({ 1 }, "a");
lives({ die "x" }, "b");
EOF
cat > "$W/hof.ref" <<'EOF'
4
4
6
7
7
20
6
(2 3 4)
10
102
30
9
12
a: True
b: False
EOF
cat > "$W/testfns.raku" <<'EOF'
use Test;
plan 17;
like "abc", /b/, "like matches";
like "abc", /z/, "like should fail";
unlike "abc", /z/, "unlike matches";
unlike "abc", /b/, "unlike should fail";
lives-ok { 1 }, "lives";
lives-ok { die "x" }, "lives should fail";
dies-ok { die "x" }, "dies";
dies-ok { 1 }, "dies should fail";
lives-ok { my $x = 5; $x + 1 }, "lives 2";
dies-ok { (1, 2).map({ die "q" }) }, "dies in map";
lives-ok { 1 };
dies-ok { die };
ok "abc" ~~ /b/, "match ok";
ok "abc" ~~ /z/, "no match should fail";
nok "abc" ~~ /z/, "nok no match";
ok "abc".contains("z"), "contains should fail";
ok "abc".contains("b"), "contains";
EOF
cat > "$W/testfns.ref" <<'EOF'
1..17
ok 1 - like matches
not ok 2 - like should fail
ok 3 - unlike matches
not ok 4 - unlike should fail
ok 5 - lives
not ok 6 - lives should fail
ok 7 - dies
not ok 8 - dies should fail
ok 9 - lives 2
ok 10 - dies in map
ok 11 - 
ok 12 - 
ok 13 - match ok
not ok 14 - no match should fail
ok 15 - nok no match
not ok 16 - contains should fail
ok 17 - contains
EOF
cat > "$W/argsunder.raku" <<'EOF'
sub f { @_.elems }
say f(1, 2, 3);
sub g { say @_; }
g(4, 5);
sub h { my $n = 0; for @_ -> $x { $n += $x }; $n }
say h(1, 2, 3);
say h();
sub k($a) { $a }
say k(7);
EOF
cat > "$W/argsunder.ref" <<'EOF'
3
[4 5]
6
0
7
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
for w in hof testfns argsunder; do for m in m3 m4; do ck "$w" "$m"; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a code parameter that is not callable, @_ that is not the argument list, or a Test function that does not judge as Rakudo's does"
