#!/usr/bin/env bash
# test_gate_raku_placeholders_in_a_sub_and_a_for_body_a_comma_list_as_the_last_statement_or_return_value_and_sort_with_a_leading_block_agree_with_rakudo.sh -- `$^a` IN A NAMED SUB AND IN A for BODY, A COMMA LIST (`1, 2` / `return 1, 2` / `$a, $b`) AS A ROUTINE'S VALUE, AND `sort { $^a <=> $^b }, @list`
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by classifying the Roast files that do not compile: the placeholder `^a` is the second most common unassigned-variable refusal, 11 files, e.g. integration/advent2013-day23.t, S32-list/reduce.t, S06-signature/multi-invocant.t, S32-array/splice.t).
#
# THE DEFECTS, each measured against Rakudo: (1) a caret placeholder worked in an anonymous block (`{ $^a + 1 }`) and in `.map: { $^a }` but NOT in a named sub or `my sub` whose body has no signature: `sub meow { $^a }; say meow(5)`, `sub cat2 { $^b ~ $^a }` were refused by the native emitter
# ("variable '^a' is read but never assigned"); (2) nor in a `for` body (`for 1, 2 { say $^a }`, `for 1, 2, 3, 4 { say $^a + $^b }` must step two at a time); (3) a COMMA LIST WITHOUT PARENTHESES as a routine's last statement or as the operand of return kept only its FIRST ITEM: `sub g { 1, 2 }; say g()` printed 1 (Rakudo (1 2)),
# `sub g { return 1, 2 }` printed 1, `sub g($a) { $a, $a + 1 }; say g(3)` printed 3 ((3 4)), `my $f = { 1, 2 }; $f()` printed 1, `sub pair { $^a, $^b }` returned $^a; the same loss hit every plain statement `a(), b();` (the second call never ran);
# (4) the function form of sort with a LEADING BLOCK was broken for every comparator: `sort { $^a <=> $^b }, @v` was refused, `sort { $_ }, @v` died "error 22: undefined function called" (the block was lowered as a bare comparator expression), though `@v.sort: { ... }` worked.
# THE CURE: (lower_raku.c rk_sub_placeholders, a pass before rk_ph_alias) a sub with no parameters whose body reads `$^x` placeholders gets them as its parameters in alphabetical order, a later plain `$a` naming the placeholder is renamed, and rk_scan_implicit_params stops at a nested sub as it already stopped at a nested block;
# (rk_tree.c rkb_for) a for body with no signature that reads placeholders takes them as the loop parameters (rk_collect_ph, rk_ph_ren), so the existing multi-variable loop steps through the list; (rk_tree.c rkb_call return, stmt_tail, stmt_plain) a statement or return whose list has more than one item builds the whole list (rkb_paren), as `take` already did;
# (rk_tree.c rkb_call sort) `sort BLOCK, LIST` is built as `LIST.sort(BLOCK)`, the method form that works, for a plain or pointy block.
# NOT HERE (own rows, measured): an n-ary reduce block (`@a.reduce: { $^a + $^b * $^c }` takes three at a time in Rakudo: 7, SCRIP answers 1); `fail "msg"` and `die "a", "b"` still keep nothing / only the first argument; a placeholder in an `if` block or a method body; Rakudo REFUSES `$^a` in a statement-modifier `for` (SCRIP does not); `sort { $a <=> $b }` with the undeclared sort globals (Rakudo refuses it too).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 560a2bf11 before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_placeholders_in_a_sub_and_a_for_body_a_comma_list_as_the_last_statement_or_return_value_and_sort_with_a_leading_block_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_placeholders_in_a_sub_and_a_for_body_a_comma_list_as_the_last_statement_or_return_value_and_sort_with_a_leading_block_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
sub meow { $^a };
say meow(5);
sub plus1 { $^a + 1 }
say plus1(5);
sub cat2 { $^b ~ $^a }
say cat2("x", "y");
sub sq { $^x * $^x }
say sq(7);
my sub minus1 { $^a - 1 }
say minus1(8);
sub three { $^c ~ $^a ~ $^b }
say three("a", "b", "c");
sub both { $^a + $a }
say both(4);
sub outer { my $f = { $^a * 2 }; $f($^a) }
say outer(6);
sub pair { $^a, $^b }
say pair(3, 4);
say pair(3, 4).elems;
sub g1 { 1, 2 }
say g1();
sub g2 { return 1, 2 }
say g2();
sub g3($a) { $a, $a + 1 }
say g3(3);
my @r = g3(3);
say @r.elems;
sub g4 { my $x = 5; $x, 7 }
say g4();
sub g5 { (1, 2) }
say g5();
sub g6 { return 7 }
say g6();
sub g7 { return (1, 2), 3 }
say g7().elems;
my $f1 = { 1, 2 };
say $f1();
my $f2 = -> $a { $a, 2 };
say $f2(5);
for 1, 2 { say $^a }
for 1, 2, 3, 4 { say $^a + $^b }
for 1, 2, 3, 4 { say $^b - $^a }
for 1 .. 3 { my $y = $^a * 2; say $y }
my $t;
for 1, 2 { $t = $^a }
say $t;
my @acc;
for 1, 2 { @acc.push($^a * 3) }
say @acc;
for 1, 2 { for 5, 6 { say $^a } }
my @v = 3, 1, 2;
my @s = sort { $^a <=> $^b }, @v;
say @s;
say sort({ $^b <=> $^a }, @v);
say sort -> $x, $y { $y <=> $x }, @v;
say sort { -$_ }, @v;
my @w = <b a c>;
say sort { $^a cmp $^b }, @w;
say sort { $^b cmp $^a }, @w;
EOF
cat > "$W/w.ref" <<'EOF'
5
6
yx
49
7
cab
8
12
(3 4)
2
(1 2)
(1 2)
(3 4)
2
(5 7)
(1 2)
7
2
(1 2)
(5 2)
1
2
3
7
1
1
2
4
6
2
[3 6]
5
6
5
6
[1 2 3]
(3 2 1)
(3 2 1)
(3 2 1)
(a b c)
(c b a)
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ge 124 ]; then printf '  FAIL %-7s %s: died rc=%s\n' "$w" "$m" "$rc"; fails=$((fails + 1)); return; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s: got [%s] want [%s]\n' "$w" "$m" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in w; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a placeholder, comma-list-value or function-form-sort result that disagrees with Rakudo"
