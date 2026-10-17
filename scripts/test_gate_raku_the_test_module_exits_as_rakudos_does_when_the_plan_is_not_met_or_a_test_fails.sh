#!/usr/bin/env bash
# test_gate_raku_the_test_module_exits_as_rakudos_does_when_the_plan_is_not_met_or_a_test_fails.sh -- A TAP FILE THAT RAN FEWER TESTS THAN IT PLANNED IS NOT A PASS
# (row raku-every-suite-to-100-under-nonet-ceo-1266; ceo CEO-1479). FOUND by the sanctioned Roast inventory plus a per-file TAP count: of the 199 files the
# scoreboard classified PASS, only 41 had run every planned test. The Test emulation (by_name_dispatch.c __rk_test_*) printed the plan and left the exit status 0
# however few tests ran, so a file whose assertions were lost (a failing match as an argument killed the whole call, an unimplemented function ended the run)
# read as a green file; classify() in lib_raku_roast_bucket.sh grades PASS on no not-ok line and rc 0 with a plan. Rakudo's Test sets the status in its END phase:
# the number of failed tests when any failed (capped at 254), else 255 when the planned count differs from the run count, else 0, and prints
# "# You planned N tests, but ran M" and "# You failed K tests of M" on stderr. rk_tap_exit (by_name_dispatch.c, registered at the plan and the first test, run at exit
# with the stack re-aligned because the emitted program's exit call enters libc at 8 mod 16) does the same.
# NINE PROGRAMS, each run in m3 and m4, stdout and the exit status compared with Rakudo's (cut by Rakudo at generation):
# under-run, over-run, an over-run with a failure, all green, a failure within the plan, done-testing without a plan, done-testing with a failure, an over-run with no
# failure, an under-run with a failure.
# EXPECTED to move: the Roast SUITE TABLE reading falls to the true count when the coo's next pass runs (the 158 files that never ran their tests leave PASS).
# EXIT: 0 all nine agree in both modes; 1 a stdout or status mismatch; 2 REFUSED (stale binary, no gcc).
# Usage: bash ../harness/scripts/test_gate_raku_the_test_module_exits_as_rakudos_does_when_the_plan_is_not_met_or_a_test_fails.sh   (~5s)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
cd "$ROOT"
. "$HERE/lib_gate.sh"
GATE_NAME="raku_the_test_module_exits_as_rakudos_does_when_the_plan_is_not_met_or_a_test_fails"
gate_parse_args "$@"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
command -v gcc >/dev/null 2>&1 || { echo "⛔ REFUSE(rc=2) [$GATE_NAME]: gcc not found -- mode 4 cannot be linked, so half the population is unmeasured"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
cat > "$W/p1.raku" <<'EOF'
use Test;
plan 3;
ok 1, "a";
EOF
printf '%s' '1..3
ok 1 - a
' > "$W/p1.ref"
echo 255 > "$W/p1.rc"
cat > "$W/p2.raku" <<'EOF'
use Test;
plan 2;
ok 1, "a";
ok (1 ~~ 2) , "b";
sub f { fail "x" }
ok f(), "c";
EOF
printf '%s' '1..2
ok 1 - a
not ok 2 - b
not ok 3 - c
' > "$W/p2.ref"
echo 2 > "$W/p2.rc"
cat > "$W/p3.raku" <<'EOF'
use Test;
plan 2;
ok 1, "a";
ok 0, "b";
ok 1, "c";
EOF
printf '%s' '1..2
ok 1 - a
not ok 2 - b
ok 3 - c
' > "$W/p3.ref"
echo 1 > "$W/p3.rc"
cat > "$W/p4.raku" <<'EOF'
use Test;
plan 2;
ok 1, "a";
nok 0, "b";
EOF
printf '%s' '1..2
ok 1 - a
ok 2 - b
' > "$W/p4.ref"
echo 0 > "$W/p4.rc"
cat > "$W/p5.raku" <<'EOF'
use Test;
plan 3;
ok 1, "a";
ok 0, "b";
ok 0, "c";
EOF
printf '%s' '1..3
ok 1 - a
not ok 2 - b
not ok 3 - c
' > "$W/p5.ref"
echo 2 > "$W/p5.rc"
cat > "$W/p6.raku" <<'EOF'
use Test;
ok 1, "a";
done-testing;
EOF
printf '%s' 'ok 1 - a
1..1
' > "$W/p6.ref"
echo 0 > "$W/p6.rc"
cat > "$W/p7.raku" <<'EOF'
use Test;
plan 2;
ok 1, "a";
ok 0, "b";
done-testing;
EOF
printf '%s' '1..2
ok 1 - a
not ok 2 - b
' > "$W/p7.ref"
echo 1 > "$W/p7.rc"
cat > "$W/p8.raku" <<'EOF'
use Test;
plan 1;
ok 1, "a";
ok 1, "b";
EOF
printf '%s' '1..1
ok 1 - a
ok 2 - b
' > "$W/p8.ref"
echo 255 > "$W/p8.rc"
cat > "$W/p9.raku" <<'EOF'
use Test;
plan 3;
ok 0, "a";
EOF
printf '%s' '1..3
not ok 1 - a
' > "$W/p9.ref"
echo 1 > "$W/p9.rc"
fails=0; GATE_EXAMINED=0
for w in p1 p2 p3 p4 p5 p6 p7 p8 p9; do
    if ! timeout -k 5 60 "$ROOT/scrip" --compile -o "$W/$w.s" "$W/$w.raku" </dev/null >"$W/$w.cerr" 2>&1 \
       || ! gcc -o "$W/$w.bin" "$W/$w.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread >>"$W/$w.cerr" 2>&1; then
        printf '  FAIL %-3s m4: did not build\n' "$w"; fails=$((fails + 1)); continue; fi
    for m in m3 m4; do
        GATE_EXAMINED=$((GATE_EXAMINED + 1))
        if [ "$m" = m3 ]; then out="$(timeout -k 5 20 "$ROOT/scrip" --run "$W/$w.raku" 2>/dev/null </dev/null)"; rc=$?; else out="$(timeout -k 5 20 "$W/$w.bin" 2>/dev/null </dev/null)"; rc=$?; fi
        if [ "$out" = "$(cat "$W/$w.ref")" ] && [ "$rc" = "$(cat "$W/$w.rc")" ]; then printf '  ok   %-3s %s rc=%s\n' "$w" "$m" "$rc"
        else printf '  FAIL %-3s %s: rc got %s want %s, out [%s]\n' "$w" "$m" "$rc" "$(cat "$W/$w.rc")" "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-80)"; fails=$((fails + 1)); fi
    done
done
gate_verdict "$fails" "program-mode pair(s) wrong: a TAP file whose plan is not met, or whose tests fail, that does not exit as Rakudo's Test does"
