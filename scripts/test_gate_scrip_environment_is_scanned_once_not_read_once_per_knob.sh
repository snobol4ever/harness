#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 1
../harness/scripts/util_require_fresh.sh --gate "$(basename "$0" .sh)" || exit $?
# test_gate_scrip_environment_is_scanned_once_not_read_once_per_knob.sh -- A PROCESS WITH NO SCRIP_ VARIABLE IN ITS ENVIRONMENT MAKES NO getenv CALL FOR A SCRIP_ NAME AT START-UP; THE ANSWER IS ONE
# SCAN OF environ, CACHED IN ONE STATE INT, AND EVERY PLACE THAT CHANGES THE ENVIRONMENT RESETS IT (row icon-speed-the-empty-icon-program-starts-in-at-most-400000-user-instructions-ceo-2035;
# CTO-501: a global that holds state and is not a value stack is granted; STATE-GLOBAL = g_runtime.scrip_env, a three-valued int: 0 not scanned, 1 no SCRIP_ variable, 2 some exists).
# ⛔ THE MEASURED DEFECT: the empty Icon program in mode 4 made 23 getenv("SCRIP_...") calls at start-up (SCRIP_STACK x2, ALLOC_HIST, EVAL_RET in a library constructor, the nine of gc_knobs_hoist, NOHUGE,
# GC_STRESS, GC_BUDGET_MB, EXPR_STORE_DBG, NV_TRACE, MON_SYNTH, B1C_PARITY, GC_MAPS_DUMP and three at exit), each a linear walk of environ (about 840 user instructions at 73 variables) that answers NULL.
# FIVE ARMS. STARTUP: the empty Icon, SNOBOL4 and Prolog programs in mode 4, run by gdb under `env -i PATH=...`, make ZERO getenv calls whose name begins SCRIP_ (the shared runtime serves all
# three). PRESENT: with SCRIP_GC_STRESS=1 and SCRIP_GC_EXERCISE=1 in the environment the same Icon program's exit report still says stress=1 (the cache must not hide a variable that exists).
# RESET (behavioural): a Prolog program that calls setenv('SCRIP_GC_EXERCISE','1') at run time, started from an environment with no SCRIP_ variable, still gets the exit report, in BOTH modes, and
# the control program that does not call setenv gets none (so the arm cannot pass vacuously). STRUCTURE: every setenv, putenv and unsetenv call in src (tests and generated parsers aside) is
# followed within two lines by `g_runtime.scrip_env = 0`, and no getenv("SCRIP_ call is left in the runtime files that serve start-up.
# FAIL-ONCE: STARTUP and STRUCTURE are red on SCRIP 297096759 (23 calls; 0 of 9 resets). No plant anywhere in src/.
# Board line: SCRIP_ENV_BOARD startup_icon=<n> startup_sno=<n> startup_pl=<n> present=<ok|bad> reset_m3=<ok|bad> reset_m4=<ok|bad> control=<ok|bad> structure=<ok|bad> (tree <hash>)
# rc 0 all arms green · rc 1 an arm red, named · rc 2 cannot measure (no gdb, a program did not build, the control already reports).
NAME=scrip_environment_is_scanned_once_not_read_once_per_knob
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(pwd)"
refuse() { echo "⛔ GATE REFUSE(2) [$NAME]: $*"; exit 2; }
command -v gdb >/dev/null 2>&1 || refuse "no gdb -- the STARTUP arm counts getenv calls"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so missing -- run make"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
bad=0
build4() { ( cd "$W" && timeout -k 5 120 "$ROOT/scrip" --compile --out="$1.s" "$2" < /dev/null >/dev/null 2>&1 && gcc "$1.s" -o "$1" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ); }
printf 'procedure main();\nend\n' > "$W/e.icn"
printf '*\tan empty program\nEND\n' > "$W/e.sno"
printf ':- initialization(main).\nmain.\n' > "$W/e.pl"
printf ':- initialization(main).\nmain :- setenv(%s, %s), write(done), nl.\n' "'SCRIP_GC_EXERCISE'" "'1'" > "$W/s.pl"
printf ':- initialization(main).\nmain :- write(done), nl.\n' > "$W/c.pl"
for p in "e_icn e.icn" "e_sno e.sno" "e_pl e.pl" "s_pl s.pl" "c_pl c.pl"; do set -- $p; build4 "$1" "$2" || refuse "$2 did not build in mode 4"; done
cat > "$W/g.gdb" <<'EOS'
set pagination off
set confirm off
set breakpoint pending on
break getenv
commands
silent
printf "GETENV %s\n", (char *)$rdi
continue
end
run < /dev/null > /dev/null 2>&1
EOS
cnt() { ( cd "$W" && env -i PATH="$PATH" HOME="${HOME:-/tmp}" timeout -k 5 200 gdb -q -batch -x g.gdb "./$1" 2>&1 | grep -c '^GETENV SCRIP_' ); }
names() { ( cd "$W" && env -i PATH="$PATH" HOME="${HOME:-/tmp}" timeout -k 5 200 gdb -q -batch -x g.gdb "./$1" 2>&1 | grep '^GETENV SCRIP_' | sed 's/^GETENV //' | sort | uniq -c | sort -rn | head -6 | tr '\n' ' ' ); }
ci=$(cnt e_icn); cs=$(cnt e_sno); cp=$(cnt e_pl)
for x in "Icon:$ci:e_icn" "SNOBOL4:$cs:e_sno" "Prolog:$cp:e_pl"; do IFS=: read -r lang n prog <<<"$x"; if [ "$n" != 0 ]; then bad=1; echo "  STARTUP RED: the empty $lang program made $n getenv(\"SCRIP_...\") call(s) at start-up under an environment with no SCRIP_ variable: $(names "$prog")"; fi; done
present=ok
pr=$( cd "$W" && env -i PATH="$PATH" SCRIP_GC_STRESS=1 SCRIP_GC_EXERCISE=1 timeout -k 5 60 ./e_icn < /dev/null 2>&1 >/dev/null | grep -c 'stress=1' )
[ "$pr" -ge 1 ] || { present=bad; bad=1; echo "  PRESENT RED: with SCRIP_GC_STRESS=1 SCRIP_GC_EXERCISE=1 in the environment the exit report does not say stress=1 -- the cached answer hides a variable that exists"; }
control=ok
cr=$( cd "$W" && env -i PATH="$PATH" timeout -k 5 60 ./c_pl < /dev/null 2>&1 >/dev/null | grep -c 'GC-EXERCISE' )
[ "$cr" = 0 ] || { control=bad; refuse "the control Prolog program reports without any SCRIP_ variable -- the RESET arm would pass vacuously"; }
reset3=ok; reset4=ok
r3=$( cd "$W" && env -i PATH="$PATH" timeout -k 5 120 "$ROOT/scrip" s.pl < /dev/null 2>&1 >/dev/null | grep -c 'GC-EXERCISE' )
r4=$( cd "$W" && env -i PATH="$PATH" timeout -k 5 60 ./s_pl < /dev/null 2>&1 >/dev/null | grep -c 'GC-EXERCISE' )
[ "$r3" -ge 1 ] || { reset3=bad; bad=1; echo "  RESET RED (mode 3): setenv('SCRIP_GC_EXERCISE','1') at run time did not reach the exit report -- the cached no-SCRIP_ answer was not reset"; }
[ "$r4" -ge 1 ] || { reset4=bad; bad=1; echo "  RESET RED (mode 4): setenv('SCRIP_GC_EXERCISE','1') at run time did not reach the exit report -- the cached no-SCRIP_ answer was not reset"; }
structure=ok; nsite=0; nreset=0
while IFS=: read -r f ln rest; do
    nsite=$((nsite + 1))
    if sed -n "${ln},$((ln + 2))p" "$ROOT/$f" | grep -q 'g_runtime\.scrip_env = 0'; then nreset=$((nreset + 1)); else structure=bad; bad=1; echo "  STRUCTURE RED: $f:$ln changes the environment and is not followed by g_runtime.scrip_env = 0"; fi
done < <(cd "$ROOT" && grep -rn -E '\b(setenv|putenv|unsetenv|clearenv)\(' src --include=*.c --include=*.cpp | grep -v -E '_test\.c:|\.tab\.c:|\.lex\.c:' | grep -v -E '^\S+:[0-9]+:\s*(static )?(int|void) ')
[ "$nsite" -ge 9 ] || refuse "found only $nsite environment-changing call(s) in src -- the census expects the 9 the row recorded; the arm would be vacuous"
left=$(cd "$ROOT" && grep -c -P '(?<!rt_scrip_)getenv\("SCRIP_' src/runtime/rt/gc_heap.c src/runtime/core/core.c src/runtime/runtime_eval.c src/runtime/rt/rt_stack_overflow.c src/runtime/rt/rt.c | awk -F: '{s+=$2} END{print s+0}')
if [ "$left" != 0 ]; then structure=bad; bad=1; echo "  STRUCTURE RED: $left getenv(\"SCRIP_ call(s) remain in the start-up runtime files (they read through rt_scrip_getenv)"; fi
echo "SCRIP_ENV_BOARD startup_icon=$ci startup_sno=$cs startup_pl=$cp present=$present reset_m3=$reset3 reset_m4=$reset4 control=$control structure=$structure resets=$nreset/$nsite (tree $(git rev-parse --short HEAD))"
[ "$bad" = 0 ] && { echo "GATE OK [$NAME]: no SCRIP_ getenv at start-up in three languages, a present variable is still seen, run-time setenv is seen in both modes, and all $nsite environment changes reset the cache"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
