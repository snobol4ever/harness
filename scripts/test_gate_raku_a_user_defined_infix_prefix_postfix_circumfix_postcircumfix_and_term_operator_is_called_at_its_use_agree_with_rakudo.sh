#!/usr/bin/env bash
# test_gate_raku_a_user_defined_infix_prefix_postfix_circumfix_postcircumfix_and_term_operator_is_called_at_its_use_agree_with_rakudo.sh -- `sub infix:<plus>`, `sub prefix:<±>`, `sub postfix:<!>`, `sub circumfix:<⌊ ⌋>`, `sub postcircumfix:<⟨ ⟩>`, `sub term:<answer>` ARE CALLED WHERE THEY ARE USED, AS `infix:<plus>(..)`, `&infix:<plus>` AND `[plus]` TOO
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by classifying the nearly-passing sampled Roast files: integration/advent2009-day22.t `sub postfix:<!>` failed 1 of 4, advent2012-day19.t `postfix:<(k)>`, and a probe of every operator category showed the same silence in all of them).
#
# THE DEFECT, measured against Rakudo: the recognizer already registers a declared operator (RkUserOp, add_user_op) and a declaration already compiles to a routine named Rinfix_<hex of the symbol> (rk_opname.h), but THE TREE BUILDER IGNORED EVERY USE: `sub postfix:<!>($n) {..}; say 5!` printed 5, `sub infix:<plus>..; say 1 plus 2` printed 1 (x_elem's swallow loop read the operator and dropped it), `sub prefix:<±>; say ±(-3)` printed -3 (rkb_prefix_raw answered its operand), `say ⟦5⟧` was read as a variable named ⟦5⟧ ("variable is read but never assigned"), `$v⟨7⟩` answered $v, `answer` was an unassigned variable, `infix:<plus>(4, 5)` and `&infix:<plus>` were "undefined function called", and `[plus] 1, 2, 3, 4` silently computed a MAX (rk_reduce_general's fallback).
# THE CURE (one scheme, every category at once): (rk_tree.c) the builder keeps a table of the declared symbols per category (infix, prefix, postfix, circumfix, postcircumfix, term; a symbol the built-in table already owns is not entered, so `multi infix:<+>(Foo, Foo)` keeps going through the operator-overload dispatch) with the symbol's precedence; a use builds a call of the routine the declaration made, named through rk_op_canon_base
# (infix and the swallowed case in x_elem, prefix in rkb_prefix_raw, postfix and postcircumfix in rkb_postfix, circumfix and term as terms, the reduce metaoperator, the explicit call `infix:<plus>(..)` and the code reference `&infix:<plus>` through one rk_op_name_canon shared with the declaration); (rk_syntax.c) x_in answers a user sentinel at the level of the symbol's precedence (the default is additive and left associative, which Rakudo's own `2 plus 3 * 4` = 14 and `10 plus 2 plus 3` = 15 confirm), r_user_term and r_postfixish_at hand the parsed argument list to the builder.
# NOT HERE (own rows, measured): the precedence and associativity traits (`is equiv(&infix:<+>)`, `is tighter`, `is looser`, `is assoc<right>`, `is assoc<chain>`; 15 Roast files), a symbol that is also a built-in one (`multi infix:<+>(Str, Str)`, `prefix:<!>`: 20 files), the hyper form `»plus»`, `.assuming` on the reference, `[[plus]]`, a user operator declared in a role or class body, `postcircumfix` with a list assignment.
# THE WITNESS (41 lines of output cut by the INSTALLED Rakudo), graded in m3 (--run) and m4 (--compile + link), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on the sitting's control build cfcfaf46d (nothing landed since touches operators): the witness program is REFUSED outright (rc 1, "variable 'answer' is read but never assigned"), so every one of its 41 output lines is missing.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_user_defined_infix_prefix_postfix_circumfix_postcircumfix_and_term_operator_is_called_at_its_use_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_user_defined_infix_prefix_postfix_circumfix_postcircumfix_and_term_operator_is_called_at_its_use_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
sub infix:<plus>($a, $b) { $a + $b }
sub infix:<⊕>($a, $b) { "($a⊕$b)" }
sub infix:<pw>($a, $b) { $a ** $b }
multi sub infix:<cat2>(Int $a, Int $b) { "int:$a$b" }
multi sub infix:<cat2>(Str $a, Str $b) { "str:$a$b" }
sub prefix:<±>($n) { $n.abs }
sub prefix:<√>($x) { sqrt $x }
sub postfix:<!>($n) { [*] 1..$n }
sub postfix:<²>($n) { $n * $n }
sub postfix:<k>($n) { $n * 1000 }
sub circumfix:<⌊ ⌋>($x) { $x.floor }
sub circumfix:<⟦ ⟧>(*@a) { "[" ~ @a.join('|') ~ "]" }
say 1 plus 2;
say 2 plus 3 * 4;
say 2 * 3 plus 4;
say 10 plus 2 plus 3;
say 1 + 2 plus 3;
say 1 plus 2 + 3;
say 2 pw 3 pw 2;
say 1 ⊕ 2 ⊕ 3;
say 3 cat2 4;
say "a" cat2 "b";
my $x = 7;
my $y = $x plus 1;
say $y;
say ±(-3);
say ± -4;
say √16;
say √16 plus 1;
say 5!;
say 3² plus 1;
say 4k;
say 2k + 1;
my $n = 3;
say $n!;
say $n²;
say $n² * 2;
say ⌊ 3.7 ⌋;
say ⌊ 3.7 ⌋ plus 1;
say ⟦1, 2, 3⟧;
say ⟦5⟧;
say infix:<plus>(4, 5);
say prefix:<±>(-9);
say postfix:<!>(4);
my @l = 1, 2, 3;
say @l.map({ $_ plus 10 });
say (1 plus 2, 3 plus 4);
say "r: {1 plus 2}";
my &f = &infix:<plus>;
say f(1, 2);
say &infix:<plus>(5, 6);
say [plus] 1, 2, 3, 4;
sub term:<answer> { 42 }
say answer + 1;
say answer plus answer;
sub postcircumfix:<⟨ ⟩>($c, $x) { "pc($c,$x)" }
say $n⟨7⟩;
my %h = a => 1;
say %h<a> plus 2;
say 1 plus 2 == 3 ?? "y" !! "n";
say (answer, 1).elems;
EOF
cat > "$W/w.ref" <<'EOF'
3
14
10
15
6
6
64
((1⊕2)⊕3)
int:34
str:ab
8
3
4
4
5
120
10
4000
2001
6
9
18
3
4
[1|2|3]
[5]
9
9
24
(11 12 13)
(3 7)
r: 3
3
11
10
43
84
pc(3,7)
3
y
2
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile --out="$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a user-defined operator use that disagrees with Rakudo"
