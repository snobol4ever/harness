#!/usr/bin/env bash
# test_gate_raku_the_hyper_operators_binary_and_prefix_agree_with_rakudo.sh -- THE BINARY AND PREFIX HYPER OPERATORS: @a >>+<< @b, @a <<+>> @b, @a >>*>> 2, 10 <<-<< @a, @a »+« @a, -<< @a, !<< @a, with Rakudo's dwim arrows, nesting and result type
# (row raku-every-suite-to-100-under-nonet-ceo-1266; found by a 120-file mode-3 Roast sample: integration/advent2009-day05 and day06 fail 8 of 15 assertions each on hyper operators; 46 Roast files use one).
#
# THE DEFECT, measured against Rakudo: the recognizer accepted the hyper forms and the tree builder THREW THEM AWAY: x_elem in rk_syntax.c consumed any infix operator the expression levels did not know, parsed its right operand and discarded both, so
# `@a >>+<< @b` was the tree of `@a` alone (say printed [1 2 3 4], not [4 3 6 5]); `10 <<-<< @a` printed 10; `-<< @a` printed @a. Only the method form `>>.meth` existed.
# THE CURE: x_in strips the arrows (rkb_hyper_index) to find the inner operator at its own precedence level and records which side is dwimmy (the side whose arrow points outward: `<<` on the left, `>>` on the right); x_level, x_cmp and the ** level hand the
# operands to rkb_hyper, which builds the inner operator through the existing operator tables over `$_[0]` and `$_[1]` and maps it over __rk_hyper_zip, the runtime's pairing of the two operands (a scalar is a one-element list, a nested list recurses, a dwimmy side is cycled
# or cut to the other's length, a non-dwimmy length mismatch dies); __rk_hyper_shape rebuilds the nesting and the result type (the left operand's if it is a List or Array, else the right's -- measured: @a>>+<<@b Array, $l>>+<<$r List, 5<<+<<@a Array). Prefix `-<<`, `!<<`, `~<<`, `?<<`,
# `+<<` take the same road with one operand. A range operand becomes a list.
# NOT HERE (own rows): `@a>>++` and `@a>>=` (postfix hyper that stores); hash operands; the X / Z metaoperators with an operator (`Z~`, `X*`) and the nested pairs plain Z / X return; [<] and the other relational reduces (they answer the last operand);
# the error text of a length mismatch (Rakudo names the operator and X::HyperOp::NonDWIM); every other infix operator the expression levels still swallow without a node (x_elem's loop is the place to make them an error).
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP 668bb752d before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_hyper_operators_binary_and_prefix_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_hyper_operators_binary_and_prefix_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
my @a = 1,2,3,4; my @b = 3,1,3,1; my $l = (1,2); my $r = (3,4);
say @a >>+<< @b; say @a >>*>> 2; say 10 <<-<< @a; say @a »+« @a; say @a >>+>> 1; say -<< @a;
say (1,2,3) >>+<< (4,5,6); say (1,2,3,4) <<+>> (10,20); say [1,2] >>~<< [3,4]; say (1,2) >>==<< (1,3);
say (1,2,3,4) >>+>> (10,20); say (1,2) >>+>> (10,20,30); say (1,2) <<+<< (10,20,30); say (1,2,3) <<+<< (10,20);
say (1,2) <<+>> (10,20,30); say (1,2,3) <<+>> (10,20);
say (1,(2,3)) >>+>> 1; say ((1,2),(3,4)) >>+<< ((10,20),(30,40));
say () >>+<< (); say (1,2) <<+>> ();
my @c = 1,2; my @d = 3,4;
say (@c >>+<< @d).WHAT; say ($l >>+<< $r).WHAT; say (@c >>+<< $r).WHAT; say ($l >>+<< @d).WHAT; say (5 <<+<< @c).WHAT; say (@c >>+>> 5).WHAT; say (5 <<+<< $l).WHAT;
say -<< (1,2); say !<< (0,1); say ~<< (1,2); say ?<< (0,5); say +<< ("1","2");
say <a b> >>~<< <x y>; say <a b c> >>~>> "x"; say <a b c> <<~>> "!";
say @c >>cmp<< @d; say @c >>max<< @d; say @c >>**<< @d; say (1,2) >>%<< (2,2); say (7,8) >>div<< (2,3);
say [+] @a >>*<< @b; my @e = @a >>+<< @b; say @e; say @e.sum;
say (1..4) >>*>> 2; say (1..3) >>+<< (4..6); say -<< (1..3); say @c >>+<< (1..2);
say 1 >>+<< 2;
say (1,2,3)>>.succ;
EOF
cat > "$W/w.ref" <<'EOF'
[4 3 6 5]
[2 4 6 8]
[9 8 7 6]
[2 4 6 8]
[2 3 4 5]
[-1 -2 -3 -4]
(5 7 9)
(11 22 13 24)
[13 24]
(True False)
(11 22 13 24)
(11 22)
(11 22 31)
(11 22)
(11 22 31)
(11 22 13)
(2 (3 4))
((11 22) (33 44))
()
()
(Array)
(List)
(Array)
(List)
(Array)
(Array)
(List)
(-1 -2)
(True False)
(1 2)
(False True)
(1 2)
(ax by)
(ax bx cx)
(a! b! c!)
[Less Less]
[3 4]
[1 16]
(1 0)
(3 2)
18
[4 3 6 5]
18
(2 4 6 8)
(5 7 9)
(-1 -2 -3)
[2 4]
3
(2 3 4)
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a binary or prefix hyper-operator result that disagrees with Rakudo"
