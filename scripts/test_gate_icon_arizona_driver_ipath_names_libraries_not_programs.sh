#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the Arizona runner invoked as an instrument fixture over a scratch package outside corpus, not a board (CEO-547)"
# test_gate_icon_arizona_driver_ipath_names_libraries_not_programs.sh -- A DRIVER RUN'S IPATH NAMES THE SUITE'S LIBRARIES, NEVER ITS
# PROGRAMS (hq_icon 2026-09-28, ruled by the coo on hq_icon's ask; Arizona general/cfunc under CEO-1336).
#
# general/ ships io.icn, an Arizona TEST PROGRAM, and the library cfunc.icn says `link io` meaning the IPL library that defines pathload.
# icont links ucode only and the suite holds no io.u, so iconx falls through to the installed io; SCRIP's link search reads source, so
# with the whole suite directory on IPATH the driver linked the test program and every cfunc wrapper died with error 106. The runner
# now puts a mirror of the suite minus every .icn that declares procedure main on a driver's IPATH.
#   L  the runner, over a scratch package (outside corpus, so never a board; scratch progress table, no score write): general/ holds a
#      library lib.icn that links helper, a TEST PROGRAM helper.icn with a main, and lib_driver.icn; the real helper library sits in a
#      second directory on IPATH. lib, graded through lib_driver, reads PASS in m3 and m4 against the ref iconx cut over ucode.
#   F  FAIL-ONCE: the same driver with the whole general/ directory first on IPATH -- the old runner's line -- reads error 106 at the
#      library's call of helper, m3, so L's PASS is the mirror's doing and not a fixture that cannot fail.
#   S  the runner's driver IPATH names LIBPATH, and LIBPATH skips an .icn that declares procedure main.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
G=test_gate_icon_arizona_driver_ipath_names_libraries_not_programs
SCRIP="$ROOT/scrip"; R="$HERE/test_icon_arizona_suite.sh"
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: lib_gate.sh unloadable"; exit 2; }
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
[ -f "$R" ] || { echo "⛔ GATE REFUSE(2) [$G]: $R absent"; exit 2; }
. "$HERE/lib_oracle_flags.sh"
ICONT="$(icont_bin)"; ICONX="$(iconx_bin)"
[ -x "$ICONT" ] && [ -x "$ICONX" ] || { echo "⛔ GATE REFUSE(2) [$G]: the Icon oracle (icont, iconx) is absent"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_azlib.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
RC=0
A="$W/az/corpus/packages/icon/arizona_tests"; S="$A/general"; X="$W/real"; mkdir -p "$S" "$A/special" "$X"
printf 'link helper\nprocedure run();\n   write("helper(3) = ", helper(3));\n   return;\nend\n' > "$S/lib.icn"
printf 'procedure main();\n   write("i am a test program");\nend\n' > "$S/helper.icn"
printf 'link lib\nprocedure main();\n   run();\nend\n' > "$S/lib_driver.icn"
printf 'procedure helper(x);\n   return x * 7;\nend\n' > "$X/helper.icn"
printf '%s\n1,general/lib,arizona_tests__general/lib,arizona_tests,3,0,0,131072,4096,,\n2,general/helper,arizona_tests__general/helper,arizona_tests,3,0,0,131072,4096,,\n' \
    'rank,entry,origin,package,n_lines,stdin,want_rc,heap_kb,stack_kb,compile_args,run_args' > "$A/ALL.csv"
# the refs are iconx's: icont links ucode, so the library and the real helper are translated first and their ucode leaves after the cut
( cd "$X" && "$ICONT" -s -c helper.icn < /dev/null > /dev/null 2>&1 ) \
  && ( cd "$S" && "$ICONT" -s -c lib.icn < /dev/null > /dev/null 2>&1 && IPATH="$X" "$ICONT" -s lib_driver.icn < /dev/null > /dev/null 2>&1 \
       && "$ICONX" ./lib_driver < /dev/null > lib_driver.ref 2>&1 && "$ICONT" -s helper.icn < /dev/null > /dev/null 2>&1 \
       && "$ICONX" ./helper < /dev/null > helper.ref 2>&1 ) \
  || { echo "⛔ GATE REFUSE(2) [$G]: the oracle could not cut the fixture's refs"; exit 2; }
rm -f "$S"/*.u1 "$S"/*.u2 "$X"/*.u1 "$X"/*.u2 "$S/lib_driver" "$S/helper"
[ "$(cat "$S/lib_driver.ref")" = "helper(3) = 21" ] || { echo "⛔ GATE REFUSE(2) [$G]: iconx cut an unexpected lib_driver.ref: $(head -2 "$S/lib_driver.ref" | tr '\n' ' ')"; exit 2; }
echo "  HOLDS: a driver run links the suite's libraries through IPATH and never a shipped program that shares a library's name"
out="$(cd "$ROOT" && env S4E_HOME="$W/az" IPATH="$X" S4E_PROGRESS_DB="$W/p.tsv" S4E_SCORE_NO_WRITE="gate $G" timeout -k 5 300 bash "$R" 2>&1)"; r=$?
oc() { awk -F'\t' -v p="$1" -v m="$2" 'NR>1 && $8==p && $9==m {print $10}' "$W/p.tsv" 2>/dev/null | tail -1; }
l3="$(oc general/lib m3)"; l4="$(oc general/lib m4)"   # the board keys a program by its path key <subdir>/<stem>, as its container does (CEO-1366 (b))
if [ "$r" = 2 ] || [ "$r" = 124 ]; then echo "  arm L FAIL: the runner could not measure its fixture (rc=$r): $(printf '%s\n' "$out" | grep -E 'REFUSE|⛔' | head -2 | tr '\n' ' ')"; RC=1
elif [ "$l3" = PASS ] && [ "$l4" = PASS ]; then echo "  arm L PASS: lib, graded through lib_driver with a same-named test program in the suite, reads PASS/PASS"
else echo "  arm L FAIL: general/lib reads ${l3:-none}/${l4:-none} (want PASS/PASS -- a FAIL means the driver linked the suite's test program)"; RC=1; fi
f="$(cd "$S" && IPATH="$S:$X" timeout -k 5 30 "$SCRIP" --run lib_driver.icn < /dev/null 2>&1)"
if printf '%s\n' "$f" | grep -q 'error 106' && ! printf '%s\n' "$f" | grep -q 'helper(3) = 21'; then echo "  arm F PASS: with the whole suite first on IPATH the driver reads error 106 at the library's call (red once)"
else echo "  arm F FAIL: the whole-suite IPATH no longer reds -- the fixture cannot tell the mirror from the directory: $(printf '%s\n' "$f" | head -2 | tr '\n' ' ')"; RC=1; fi
if grep -q '_ipath=(env "IPATH=$LIBPATH' "$R" && grep -q "procedure\[\[:space:\]\]+main" "$R"; then echo "  arm S PASS: the runner's driver IPATH names LIBPATH, which skips an .icn declaring procedure main"
else echo "  arm S FAIL: the runner's driver IPATH does not name the library mirror"; RC=1; fi
[ "$RC" = 0 ] && echo "✅ GATE PASS [$G]: 3 of 3 arms hold" || echo "⛔ GATE FAIL [$G]"
exit "$RC"
