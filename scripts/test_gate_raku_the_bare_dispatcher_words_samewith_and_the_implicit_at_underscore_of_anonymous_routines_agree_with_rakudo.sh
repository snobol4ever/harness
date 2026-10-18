#!/usr/bin/env bash
# test_gate_raku_the_bare_dispatcher_words_samewith_and_the_implicit_at_underscore_of_anonymous_routines_agree_with_rakudo.sh -- callsame / nextsame / nextwith / samewith WITHOUT PARENTHESES, AND `@_` / `%_` IN AN ANONYMOUS SUB OR BLOCK (and `%_` in a named sub)
# (row raku-every-suite-to-100-under-nonet-ceo-1266; first refusals of the Roast files that do not compile: nextsame 9, callsame 5 (26 files use the family), @_ 10, %_ 4).
#
# THE DEFECTS, each measured against Rakudo: the bare words callsame, nextsame (no parentheses) were read as VARIABLES ("variable 'callsame' is read but never assigned"), though callsame() and callwith(...) worked; `nextsame` did not return from the method (Rakudo: it
# calls the next candidate and never comes back), so the statements after it ran; `nextwith(args)` was undefined; `samewith(args)` (call the enclosing routine again) was undefined ("error 22: undefined function called"); `@_` was bound in a NAMED sub without a signature but not in an anonymous sub or
# a bare block (`my $f = { @_.elems }` was refused by the native emitter); `%_` (the named arguments) was bound nowhere.
# THE CURE: rk_tree.c rkb_call reads callsame / samewith / callwith / nextcallee as calls without parentheses, `nextsame` as `return callsame()` and `nextwith(args)` as `return callwith(args)`; the block builder adds the slurpy `@_` and `%_` parameters to an anonymous routine whose body reads them (the same rule
# rkb_routine already had for a named sub's `@_`, now with `%_` too); lower_raku.c rewrites `samewith(args)` inside a plain sub to a call of that sub (cx->cur_proc_name).
# NOT HERE (own rows, measured): a sub that uses `@_` AND `%_` together, or an explicit `*@a, *%h` signature, loses the positionals after the first (pre-existing: the registration inspects only the first trailing parameter); named arguments to a CLOSURE call (`$f(:a(1))` does not reach `%_`); `callsame` inside a multi sub;
# `samewith` inside a method; `&?ROUTINE`; `nextcallee`.
#
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku), then under SCRIP_GC_STRESS 1 3 5 in both modes.
# FAILED ONCE, measured on SCRIP d86c798d4 before the cure: every witness-mode pair red.
#
# EXIT: 0 every witness matches in both modes; 1 a mismatch or a crash on a witness; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_bare_dispatcher_words_samewith_and_the_implicit_at_underscore_of_anonymous_routines_agree_with_rakudo.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_bare_dispatcher_words_samewith_and_the_implicit_at_underscore_of_anonymous_routines_agree_with_rakudo"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/w.raku" <<'EOF'
class A {
    method m { "A" }
    method n($x) { "A$x" }
}
class B is A {
    method m { "B>" ~ callsame }
    method n($x) { "B>" ~ callwith($x + 1) }
}
class C is B {
    method m { "C>" ~ callsame }
}
say B.new.m; say C.new.m; say B.new.n(1);
class D is A { method m { "D>" ~ callsame() } }
say D.new.m;
class E is A { method m { my $r = callsame; "E>$r" } }
say E.new.m;
class F is A {
    method m { nextsame; "never" }
    method n($x) { nextwith($x + 5); "never" }
}
say F.new.m; say F.new.n(1);
class G is A { method m { return "G>" ~ callwith() } }
say G.new.m;
sub fact($n) { $n < 2 ?? 1 !! $n * samewith($n - 1) }
say fact(5); say fact(1);
sub f1 { @_.elems }
say f1(1,2,3);
sub f2 { %_.elems }
say f2(:a(1), :b(2));
sub f3 { %_<a> + @_[0] }
say f3(5, :a(2));
my $g1 = sub { @_.elems }; say $g1(1,2);
my $g2 = { @_.elems }; say $g2(1,2,3);
my $g3 = { @_[0] + @_[1] }; say $g3(3,4);
my @r = (1,2,3).map({ @_.elems }); say @r;
my $g4 = sub { my ($a, $b) = @_; $a * $b }; say $g4(3,4);
EOF
cat > "$W/w.ref" <<'EOF'
B>A
C>B>A
B>A2
D>A
E>A
A
A6
G>A
120
1
3
2
7
2
3
7
[1 1 1]
12
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
gate_verdict "$fails" "witness-mode pair(s) wrong: a dispatcher-word or implicit-@_ result that disagrees with Rakudo"
