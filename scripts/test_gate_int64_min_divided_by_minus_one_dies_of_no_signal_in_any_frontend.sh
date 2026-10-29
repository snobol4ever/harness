#!/usr/bin/env bash
# test_gate_int64_min_divided_by_minus_one_dies_of_no_signal_in_any_frontend.sh -- row prolog-swi-test-arith-run-dies-with-sigfpe-
# under-the-runner-a-crash-never-a-fail (rank 0; routed to the cfo by CEO-1309, widened to every frontend by CEO-1315).
#
# THE DEFECT: the smallest 64-bit integer divided by -1 does not fit, and x86's idiv traps on it; any C '/' or '%' that reaches
# it unguarded kills scrip with SIGFPE (rc 136, a core dump) -- a CRASH, never a FAIL. Measured on a build at bc96cf1b2: every
# frontend below died of the signal. CEO-1304 landing 2 (the shared division node's rt_int_neg_div) cured SNOBOL4, Snocone,
# Rebus, Icon and Prolog's //; Prolog's / (pl_arith2's raw C division) and Raku's div, % and mod (__rk_intdiv and __rk_mod) still
# died, and Raku's / answered -9223372036854775808 (a raw -a). THE CURE: both hand a divisor of -1 to the shared node.
#
# EACH ARM runs one program per frontend in mode 3 and mode 4. None may die of a signal (rc >= 128), and each is graded against
# its own oracle:
#   Prolog  //, /, mod, rem and div against swipl. swipl ITSELF raises error(signal(fpe,8)) on /, so the ref line for / is cut
#           from // (the ceo's DONE-WHEN of 2026-09-27: the exact quotient is 9223372036854775808).
#   Icon    /, % and unary - against iconx, which prints the large integer (-m is the same quotient as m / -1; it wrapped
#           to itself until the cfo's negation landing, which also raises SNOBOL4's 011 -- that arm is in the SNOBOL4 runtime-error gate).
#   Raku    div, /, % and mod against Rakudo.
#   SNOBOL4, Snocone, Rebus  / raises error 14 (SPITBOL's 'division caused integer overflow') and terminates. sbl -bf itself
#           dies rc 136 there, so the number cannot be read from it; this is the landing-2 overflow class (CEO-1315).
#           REMDR(m, -1) answers 0.
#   Pascal  m div d never dies of a signal. fpc raises runtime error 200 there and scrip answers 9223372036854775808. That VALUE
#           is Pascal's own overflow question (hq_pascal); this gate grades only the crash.
# FAIL-ONCE, MEASURED: with SCRIP_BIN at a build of landing 2 without this cure, the Prolog arm and the Raku arm read RED in both
# modes (Prolog a signal death, Raku a signal death), and since the negation landing the Icon arm too (-m wrapped to itself):
# 10 of 16. At bc96cf1b2 (before landing 2) every arm is RED.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
RT_DIR="$(cd "$(dirname "$SCRIP")" && pwd)/out"
NAME=int64_min_divided_by_minus_one_dies_of_no_signal_in_any_frontend
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
. "$HERE/lib_oracle_flags.sh" || refuse "no lib_oracle_flags.sh"
SWIPL="$(swipl_bin)" && ICONT="$(icont_bin)" && RAKU="$(rakudo_bin)" || refuse "an oracle is missing (swipl, icont or rakudo)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
run() {
    local m=$1 f=$2 b; b="$T/$(basename "$f" | tr . _)"
    if [ "$m" = m3 ]; then (cd "$T" && timeout -k 5 30 "$SCRIP" "$f" < /dev/null > "$b.$m" 2>&1); echo $? > "$b.$m.rc"; return; fi
    rm -f "$b.bin" "$b.s"
    if "$SCRIP" --compile --out="$b.s" "$f" < /dev/null > /dev/null 2>&1 && gcc -o "$b.bin" "$b.s" -L "$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm 2> /dev/null
    then (cd "$T" && timeout -k 5 30 "$b.bin" < /dev/null > "$b.$m" 2>&1); echo $? > "$b.$m.rc"; else echo M4-BUILD-FAILED > "$b.$m"; echo 2 > "$b.$m.rc"; fi
}
RC=0; n=0; ok=0
red() { RC=1; echo "  RED $1 [$2]: $3"; }
same_as_ref() {
    local f=$1 ref=$2 m b; b="$T/$(basename "$f" | tr . _)"
    for m in m3 m4; do n=$((n+1)); run $m "$f"; r=$(cat "$b.$m.rc")
        if [ "$r" -ge 128 ]; then red $m "$(basename "$f")" "died of a signal (rc $r)"
        elif cmp -s "$ref" "$b.$m"; then ok=$((ok+1))
        else red $m "$(basename "$f")" "want [$(tr '\n' ' ' < "$ref")] got [$(tr '\n' ' ' < "$b.$m" | cut -c1-140)] rc $r"; fi
    done
}
raises14() {
    local f=$1 m b; b="$T/$(basename "$f" | tr . _)"
    for m in m3 m4; do n=$((n+1)); run $m "$f"; r=$(cat "$b.$m.rc")
        if [ "$r" -ge 128 ]; then red $m "$(basename "$f")" "died of a signal (rc $r)"
        elif grep -qx before "$b.$m" && ! grep -qx after "$b.$m" && grep -qi 'error 14\b' "$b.$m" && [ "$r" -ne 0 ]; then ok=$((ok+1))
        else red $m "$(basename "$f")" "want 'before', error 14 and termination; got [$(tr '\n' ' ' < "$b.$m" | cut -c1-140)] rc $r"; fi
    done
}
PLB=':- initialization(main).\nmain :- M is -9223372036854775807 - 1, X1 is M // -1, write(X1), nl, X2 is M %s -1, write(X2), nl, X3 is M mod -1, write(X3), nl, X4 is M rem -1, write(X4), nl, X5 is M div -1, write(X5), nl, halt.\n'
printf "$PLB" '/' > "$T/p.pl"; printf "$PLB" '//' > "$T/pref.pl"
timeout -k 5 30 "$SWIPL" -q "$T/pref.pl" < /dev/null > "$T/p.ref" 2> /dev/null
[ "$(head -1 "$T/p.ref")" = 9223372036854775808 ] || refuse "swipl did not print 9223372036854775808 for // -- the Prolog witness is wrong"
same_as_ref "$T/p.pl" "$T/p.ref"
printf 'procedure main()\n  local m;\n  m := -9223372036854775807 - 1;\n  write(m / -1);\n  write(m %% -1);\n  write(-m);\nend\n' > "$T/i.icn"
(cd "$T" && "$ICONT" -s -o iref i.icn > /dev/null 2>&1 && ./iref > i.ref 2> /dev/null) || refuse "icont/iconx could not run the Icon witness"
same_as_ref "$T/i.icn" "$T/i.ref"
printf 'my $m = -9223372036854775807 - 1;\nsay $m div -1;\nsay $m / -1;\nsay $m %% -1;\nsay $m mod -1;\n' > "$T/r.raku"
timeout -k 5 120 "$RAKU" "$T/r.raku" < /dev/null > "$T/r.ref" 2> /dev/null
[ "$(head -1 "$T/r.ref")" = 9223372036854775808 ] || refuse "Rakudo did not print 9223372036854775808 for div -- the Raku witness is wrong"
same_as_ref "$T/r.raku" "$T/r.ref"
printf "        i = 9223372036854775807\n        m = 0 - i - 1\n        OUTPUT = 'before'\n        OUTPUT = m / (0 - 1)\n        OUTPUT = 'after'\nEND\n" > "$T/s.sno"
raises14 "$T/s.sno"
printf "i = 9223372036854775807;\nm = 0 - i - 1;\nOUTPUT = 'before';\nOUTPUT = m / (0 - 1);\nOUTPUT = 'after';\n" > "$T/c.sc"
raises14 "$T/c.sc"
printf "function main()\ni := 9223372036854775807\nm := 0 - i - 1\nOUTPUT := 'before'\nOUTPUT := m / (0 - 1)\nOUTPUT := 'after'\nend\n" > "$T/b.reb"
raises14 "$T/b.reb"
printf "        i = 9223372036854775807\n        OUTPUT = REMDR(0 - i - 1, 0 - 1)\nEND\n" > "$T/q.sno"; printf '0\n' > "$T/q.ref"
same_as_ref "$T/q.sno" "$T/q.ref"
printf 'program p(output);\nvar m, d: int64;\nbegin\n  m := -9223372036854775807 - 1;\n  d := -1;\n  writeln(m div d)\nend.\n' > "$T/a.pas"
for m in m3 m4; do n=$((n+1)); run $m "$T/a.pas"; r=$(cat "$T/a_pas.$m.rc")
    if [ "$r" -ge 128 ]; then red $m a.pas "died of a signal (rc $r)"; else ok=$((ok+1)); fi
done
echo "  arms: $ok of $n (seven frontends, mode 3 and mode 4)"
[ $RC = 0 ] && echo "GATE PASS(0) [$NAME]: INT64_MIN divided by -1 dies of no signal in any frontend; Prolog, Icon and Raku answer as swipl, iconx and Rakudo do, and the SNOBOL4 family raises error 14 ($ok of $n)" \
             || echo "GATE FAIL(1) [$NAME]: INT64_MIN divided by -1 dies of a signal or answers wrong in some frontend"
exit $RC
