#!/usr/bin/env bash
# test_gate_raku_a_subtest_body_is_called_from_emitted_code_and_its_tap_nests_as_rakudos_does.sh -- A SUBTEST BODY IS A BOX CALL, NOT A C ROAD INTO A BOX
# (row raku-every-suite-to-100-under-nonet-ceo-1266; CEO-1576, Lon 2026-10-09 verbatim: "Go fix everywhere a C function calls into a BB. That is forbidden, not allowed.").
#
# THE DEFECT: `subtest "x" => { ... }` ran the Test op __rk_test_subtest, a C function that saved the TAP counters, sent stdout to a temporary file, called the body block through
# rk_call_block -> rt_call_proc_descr, then printed the captured lines indented. CEO-1576 deleted that C road into a box, so EVERY subtest -- a closure body or a plain one -- died
# (rt_call_proc_descr: __blk_1 reached a C road into a box, DELETED; SIGSEGV), and with it every Roast file that uses one.
# THE CURE (lower_raku.c rk_subtest_walk, after the anonymous blocks are hoisted and closures are formed): a subtest whose body is a literal block or a capturing block (__blk_close)
# becomes __rk_test_subtest_open(name), a DIRECT call of the block's proc by name (its captured refs prepended, the shape the emitted map / grep / first / reduce / sort loops use),
# and __rk_test_subtest_close(state). The two C halves (by_name_dispatch.c rk_subtest_open / rk_subtest_close) keep the TAP bookkeeping; the state they share is a typed ten-slot
# array the open returns and the close takes, held in the emitted frame between them -- no C frame spans the body. The result is a Bool, as Rakudo's is.
# THE WITNESS, graded in m3 (--run) and m4 (--compile + link) against a ref cut by Rakudo (/usr/bin/raku, stdout), with SCRIP_C2BB_TRACE on every run and the entry count required to
# be 0, then under SCRIP_GC_STRESS 1 3 5 in both modes: a plain subtest, a closure body that reads a parameter and writes a local of its sub, nested subtests under a plan, an unnamed
# subtest, the comma form, a subtest's value, subtests in a loop body reading the loop variable, and a body that loops and sums into its sub's local.
# FAILED ONCE, measured on SCRIP 8f5f2f7ac before the cure: rc 139 at the first subtest in both modes.
#
# EXIT: 0 every witness matches in both modes with 0 entries; 1 a mismatch, a crash or an entry; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_a_subtest_body_is_called_from_emitted_code_and_its_tap_nests_as_rakudos_does.sh   (~10s, no oracle at run time, no network)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_a_subtest_body_is_called_from_emitted_code_and_its_tap_nests_as_rakudos_does"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/subtest.raku" <<'EOF'
use Test;
plan 12;
subtest "plain" => {
    ok 1, "a";
    is 2, 2, "b";
}
sub inner-closure(Int $n) {
    my $seen = 0;
    subtest "closure $n" => {
        ok $n > 0, "n is positive";
        $seen = $n * 2;
        is $seen, $n * 2, "wrote through";
    }
    return $seen;
}
is inner-closure(3), 6, "the write is seen after the subtest";
subtest "nested" => {
    plan 2;
    subtest "inner" => { ok 1, "deep"; }
    ok 1, "after inner";
}
subtest { ok 1, "unnamed"; }
subtest "comma form", { is 1 + 1, 2, "math"; }
my $r = subtest "value" => { ok 1, "one"; };
ok $r, "a passing subtest returns True";
say $r;
for 1..2 -> $i { subtest "loop $i" => { ok $i > 0, "i=$i"; } }
sub counted(@xs) { my $sum = 0; subtest "sum" => { for @xs -> $x { $sum += $x; ok $x > 0, "x=$x"; } }; $sum }
is counted([1, 2, 3]), 6, "a subtest body sums into its sub's local";
EOF
cat > "$W/subtest.ref" <<'EOF'
1..12
# Subtest: plain
    ok 1 - a
    ok 2 - b
    1..2
ok 1 - plain
# Subtest: closure 3
    ok 1 - n is positive
    ok 2 - wrote through
    1..2
ok 2 - closure 3
ok 3 - the write is seen after the subtest
# Subtest: nested
    1..2
    # Subtest: inner
        ok 1 - deep
        1..1
    ok 1 - inner
    ok 2 - after inner
ok 4 - nested
# Subtest
    ok 1 - unnamed
    1..1
ok 5 - 
# Subtest: comma form
    ok 1 - math
    1..1
ok 6 - comma form
# Subtest: value
    ok 1 - one
    1..1
ok 7 - value
ok 8 - a passing subtest returns True
True
# Subtest: loop 1
    ok 1 - i=1
    1..1
ok 9 - loop 1
# Subtest: loop 2
    ok 1 - i=2
    1..1
ok 10 - loop 2
# Subtest: sum
    ok 1 - x=1
    ok 2 - x=2
    ok 3 - x=3
    1..3
ok 11 - sum
ok 12 - a subtest body sums into its sub's local
EOF
fails=0; GATE_EXAMINED=0
ck() {
    local w="$1" m="$2" out rc ent
    GATE_EXAMINED=$((GATE_EXAMINED + 1))
    if [ "$m" = m3 ]; then out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?
    else
        if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
           || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
            printf '  FAIL %-7s %s: did not build (%s)\n' "$w" "$m" "$(head -1 "$W/$w.cerr" | cut -c1-110)"; fails=$((fails + 1)); return; fi
        out="$(env ${ST:+SCRIP_GC_STRESS=$ST} SCRIP_C2BB_TRACE="$W/$w.$m.tr" timeout -k 5 120 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?
    fi
    if [ "$rc" -ne 0 ]; then printf '  FAIL %-7s %s%s: died rc=%s\n' "$w" "$m" "${ST:+ stress=$ST}" "$rc"; fails=$((fails + 1)); return; fi
    ent=0; [ -s "$W/$w.$m.tr" ] && ent=$(grep -c . "$W/$w.$m.tr"); rm -f "$W/$w.$m.tr"
    if [ "$ent" != 0 ]; then printf '  FAIL %-7s %s: %s C-to-BB entries (want 0)\n' "$w" "$m" "$ent"; fails=$((fails + 1)); return; fi
    if [ "$out" = "$(cat "$W/$w.ref")" ]; then printf '  ok   %-7s %s%s\n' "$w" "$m" "${ST:+ stress=$ST}"
    else printf '  FAIL %-7s %s%s: got [%s] want [%s]\n' "$w" "$m" "${ST:+ stress=$ST}" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110)" "$(tr '\n' ' ' < "$W/$w.ref" | cut -c1-110)"; fails=$((fails + 1)); fi
}
ST=""; for w in subtest; do for m in m3 m4; do ck "$w" "$m"; done; done
for ST in 1 3 5; do for w in subtest; do for m in m3 m4; do ck "$w" "$m"; done; done; done
gate_verdict "$fails" "witness-mode pair(s) wrong: a subtest whose TAP disagrees with Rakudo, a crash, or a C-to-BB entry its body still makes"
