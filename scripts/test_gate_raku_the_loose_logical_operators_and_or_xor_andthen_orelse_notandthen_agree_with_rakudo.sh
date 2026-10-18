#!/usr/bin/env bash
# test_gate_raku_the_loose_logical_operators_and_or_xor_andthen_orelse_notandthen_agree_with_rakudo.sh -- THE LOOSE LOGICAL OPERATORS and / or / xor / andthen / orelse / notandthen, AND A CONTROL STATEMENT AS THE RIGHT OPERAND OF and / or / && / ||
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found while measuring why S03-operators/andthen.t, orelse.t and notandthen.t do not compile, then widened to the whole family).
#
# THE DEFECT, measured against Rakudo: every one of these operators was DROPPED by x_elem in rk_syntax.c (the loop that consumes an infix operator the expression levels do not know, parses its right operand and discards both): `say (1 and 5)` printed 1 (Rakudo 5), `0 or 5` printed 0 (5),
# `1 and 2 and 3` printed 1 (3), `0 or 0 or 9` printed 0 (9), `5 andthen 6` printed 5 (6), `Nil orelse 6` printed Nil (6), `1 xor 1` printed False (Nil); worst, `$x > 0 or return "neg"`, `... or die` and `foo() or next` NEVER RAN THEIR RIGHT SIDE, so an `or die`
# guard guarded nothing. And where the right side was a control statement under && or || the lowering assigned it to a compiler temporary (`$?logic5`) and the native emitter refused the program.
# THE CURE: x_elem now builds the two loose precedence levels (and / andthen / notandthen bind tighter than or / xor / orelse, both looser than the comma and the assignment): rkb_loose maps and, or, xor onto the existing && || ^^ nodes and orelse onto the defined-or; andthen / notandthen assign the left side to a temporary, test it
# with __rk_defined, topicalize the right side ($_ is the left value; a block or pointy block on the right is CALLED with it) and answer the empty list on the other branch; a return / die / next / last as the right operand of and, or, && or || becomes `if A { ctrl }` / `unless A { ctrl }` (rk_ctrl_guard); __rk_xor answers Nil when both sides are true.
# TWO MORE DEFECTS FOUND ON THE WAY AND CURED HERE: (a) `//` (and therefore orelse) did NOT SHORT-CIRCUIT -- it was an ordinary call `__rk_dor(l, r)`, so its right operand ran before the test: `1 // die "x"` died, `1 // $t++` incremented, `1 // boom()` called boom, and `my $fh = open(...) orelse die` always died; the defined-or is now a conditional (rk_defined_op: a temporary,
# __rk_defined, a ternary, or the if/unless guard when the right side is a control statement; a right side that is a bare variable or literal keeps the call); (b) a FILE HANDLE (the DT_FH value open returns) in a boolean test SEGFAULTED in rt_is_truthy (`so $fh`, `open(...) or die`; the integration/say-crash.t signal): every truthiness entry now answers True for it, and for any object.
# AND (c) a variable name continues across a hyphen or apostrophe followed by a letter inside a string ("$rat-atts", "output: $readme-lines" were read as $rat followed by -atts: "variable 'rat' is read but never assigned"), and (d) a control statement on the LEFT of and / or (`return $x > 0 and $x < 5`) leaves the right side dead as Rakudo does.
# NOT HERE (own rows, measured): Empty is a distinct UNDEFINED value in Rakudo (Empty.defined, (Nil andthen 6).defined, and `(Nil andthen 2) andthen 3` is ()) while SCRIP shares one empty array with `()`; `@empty andthen 3` answers () in SCRIP (Rakudo 3); a chain of three or more xor; a sub that captures a file-scope `my @log` and pushes to it from inside an and / or operand
# (the outer-lexical gap); Nil.raku prints Any.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP d86c798d4 before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_loose_logical_operators_and_or_xor_andthen_orelse_notandthen_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_loose_logical_operators_and_or_xor_andthen_orelse_notandthen_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
say (1 and 5); say (0 and 5); say (0 or 5); say (3 or 5); say (1 xor 0); say (0 xor 1); say (1 xor 1); say (0 xor 0);
my $y = (0 or 7); say $y;
say (1 and 2 and 3); say (0 or 0 or 9); say (1 or 0 and 5); say (0 or 1 and 5); say (1 and 0 or 7); say (0 and 1 or 7);
say (5 andthen 6); say (Nil andthen 6); say (0 andthen 6); say ("" andthen 6); say (Nil notandthen 6);
say (Nil orelse 6); say (Any orelse 6); say (5 orelse 6); say (0 orelse 6); say (Nil orelse "x");
say (5 andthen $_ * 2); say ((1,2,3) andthen .elems); say (3 andthen { $_ * 2 }); say (3 andthen -> $x { $x + 1 });
say (1 andthen 2 andthen 3);
sub f($x) { $x > 0 or return "neg"; return "pos" }
say f(1); say f(-1);
my $r = 0; $r = 5 if 1 and 2; say $r;
say "a" if 1 and 0; say "b" if 0 or 2;
my $x = 5; ($x > 3 and say "big"); ($x > 9 or say "small");
my $t = 0; 1 or $t++; say $t; 0 or $t++; say $t;
sub note-it($s) { print $s; True }
(note-it("a") and note-it("b")); (0 or note-it("c")); (1 or note-it("d")); (note-it("e") andthen note-it("f")); print "\n";
my $e = Nil; my $v = $e // "dflt"; say $v; my $w = ($e orelse "alt"); say $w;
my $t2 = 0; my $d1 = 1 // $t2++; say $t2; my $d2 = Nil // $t2++; say $t2;
my $d3 = 1 // die "x"; say $d3;
my $x1 = 5 orelse die "no"; say $x1; my $x2 = 0 orelse die "no"; say $x2;
sub f7 { 7 }
my $v7 = f7() orelse die "no"; say $v7;
my %hh = a => 1; my $hv = %hh<b> // "none"; say $hv; say %hh<a> // "none";
my $nn; $nn //= 5; say $nn; $nn //= 9; say $nn;
say (Nil // Nil // 3);
my $tmpf = "/tmp/cc_loose_witness.tmp";
my $fh = open($tmpf, :w) orelse die "cannot";
say "opened"; say so $fh; say ?$fh; say !$fh;
$fh.close; unlink $tmpf;
open($tmpf, :w) or die "cannot2";
say "opened2"; unlink $tmpf;
my $it-s = 2; my $it = 1; say "$it-s and $it"; say "got $it-s.";
sub rb($x) { return $x > 0 and $x < 5 }
say rb(2); say rb(9);
EOF
cat > "$W/w.ref" <<'EOF'
5
0
5
3
1
1
Nil
0
7
3
9
1
5
7
7
6
()
6
6
6
6
6
5
0
x
10
3
6
4
3
pos
neg
5
b
big
small
0
1
abcef
dflt
alt
0
1
1
5
0
7
none
1
5
5
3
opened
True
True
False
opened2
2 and 1
got 2.
True
True
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a loose logical operator, short-circuit, file-handle truthiness or hyphenated-interpolation result that disagrees with Rakudo"
