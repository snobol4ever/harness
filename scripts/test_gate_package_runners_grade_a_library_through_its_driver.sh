#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: three package runners invoked on scratch packages as instrument fixtures, not boards (CEO-1269, CEO-523)"
# test_gate_package_runners_grade_a_library_through_its_driver.sh -- THE LIBRARY RULE, HELD BY THE RUNNERS (ceo CEO-1269, CEO-700
# applied; coo 2026-09-25, row instruments-the-arizona-jcon-and-gimpel-runners-grade-a-library-through-its-driver-...). A library is
# the program and NAME_driver is its grading vehicle, never a program in the shipped population. So a package runner (a) excludes
# every *_driver file from the shipped count by name, and (b) grades the library by its driver -- the library's verdict in each mode
# is the driver's, recorded under the LIBRARY's name in the progress database. A library with no driver stays in the denominator as
# owed, a non-pass, named.
#
# ONE SCRATCH PACKAGE PER RUNNER, three libraries each: one with a passing driver, one with a failing driver and one with none. Each
# must read shipped 3, graded 2, pass 1, with the failing library and the driverless one NAMED. Its inventory must sum (the
# driverless library declared UNGRADED NEEDS_DRIVER), and its progress rows must be keyed by the libraries and never by a driver.
#   arizona  test_icon_arizona_suite.sh  S4E_HOME=<scratch>, package at corpus/packages/icon/arizona_tests/general
#   jcon     test_icon_jcon_suite.sh     --corpus <scratch>
#   gimpel   test_snobol4_gimpel_suite.sh  CORPUS=<scratch>, package at packages/snobol4/gimpel
# THE REFS ARE CUT LIVE FROM THE ORACLE (icont/iconx for Icon, sbl -bf for SNOBOL4) for the passing drivers. The failing driver's ref is
# deliberately wrong: 5 where the oracle prints 4. The Icon runners grade against the ref alone, so that driver is a FAIL. gimpel's
# scorecard also compares against the LIVE oracle, and SCRIP agrees with it, so its failing driver also reads &VERSION. SPITBOL refuses
# that (ERROR 251), the scorecard grades the driver against its pin alone, and the wrong pin reads FAIL whatever SCRIP answers.
# NOTHING LIVE IS TOUCHED: S4E_PROGRESS_DB is a scratch table per runner, S4E_SCORE_NO_WRITE shuts the leaderboard write, every
# package lives under mktemp.
# ⛔ FAILED ONCE ON THE PARENT (measured at the landing, recorded in its commit): the runners before the rule count the drivers as
# shipped programs and record their names.
# EXIT 0 every arm holds; 1 an arm is red; 2 REFUSED (an oracle or the fixture could not be built -- nothing was measured).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSED(2): lib_oracle_flags.sh unloadable"; exit 2; }
ICONT="$(icont_bin 2>/dev/null)"; ICONX="$(iconx_bin 2>/dev/null)"; SBL="$(sbl_correctness_bin 2>/dev/null)"
for b in "$ICONT" "$ICONX" "$SBL"; do [ -n "$b" ] && [ -x "$b" ] || { echo "⛔ REFUSED(2): an oracle is missing (icont='$ICONT' iconx='$ICONX' sbl='$SBL') -- a ref cannot be cut, so nothing can be graded"; exit 2; }; done
SCRATCH="${S4E_SCRATCH:-$(cd "$ROOT/.." && pwd)/.scratch}"; mkdir -p "$SCRATCH" || { echo "⛔ REFUSED(2): cannot create $SCRATCH"; exit 2; }
T="$(mktemp -d "$SCRATCH/gate_libdrv_XXXXXX")" || { echo "⛔ REFUSED(2): mktemp failed"; exit 2; }; trap 'rm -rf "$T"' EXIT
export S4E_SCORE_NO_WRITE="gate fixture ${0##*/}: a scratch package, never a board"
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
has() { grep -qE -- "$2" "$1"; }

# ---- the Icon fixture (the semicolon dialect SCRIP reads, CEO-495), refs cut from iconx
I="$T/icn"; C="$T/cut"; mkdir -p "$I" "$C" || exit 2
printf 'procedure dbl(x);\n   return 2 * x;\nend\n' > "$I/alib.icn"
printf 'link alib\nprocedure main();\n   write("dbl(21) = ", dbl(21));\n   write("dbl(-4) = ", dbl(-4));\nend\n' > "$I/alib_driver.icn"
printf 'procedure half(x);\n   return x / 2;\nend\n' > "$I/blib.icn"
printf 'link blib\nprocedure main();\n   write("half(9) = ", half(9));\nend\n' > "$I/blib_driver.icn"
printf 'procedure triple(x);\n   return 3 * x;\nend\n' > "$I/clib.icn"
printf '# fixture\n# name<TAB>CLASS<TAB>reason\nclib.icn\tNEEDS_DRIVER\ta library with no clib_driver.icn (gate fixture)\n' > "$I/UNGRADED.tsv"
printf '# fixture\n# name<TAB>CLASS<TAB>reason\n' > "$I/UNGRADABLE.tsv"
cp "$I"/*.icn "$C/" && ( cd "$C" && "$ICONT" -s -c alib.icn blib.icn && "$ICONT" -s -o ad alib_driver.icn && "$ICONT" -s -o bd blib_driver.icn ) </dev/null >/dev/null 2>&1 \
  || { echo "⛔ REFUSED(2): icont could not build the fixture's drivers"; exit 2; }
( cd "$C" && "$ICONX" ./ad ) > "$I/alib_driver.ref" 2>&1 </dev/null
( cd "$C" && "$ICONX" ./bd ) > "$C/blib_oracle.txt" 2>&1 </dev/null
grep -qx 'dbl(21) = 42' "$I/alib_driver.ref" && grep -qx 'half(9) = 4' "$C/blib_oracle.txt" || { echo "⛔ REFUSED(2): iconx did not answer the fixture as expected -- $(tr '\n' '|' < "$I/alib_driver.ref")"; exit 2; }
echo 'half(9) = 5' > "$I/blib_driver.ref"

# ---- the SNOBOL4 fixture in gimpel's shape (-INCLUDE the library), the passing drivers' refs cut from sbl -bf. Catspaw's SPITBOL form
# under lower-case names (Lon 2026-09-27, CEO-1319; coo COO-204): libraries name.inc, programs name.spt, drivers name_driver.sno, and a
# stem the form ships twice -- the program dlib.spt and the library dlib.inc it includes -- driven by dlib_driver (the program) and
# dlib_lib_driver (the library). Every progress key is the library's own file. FAILED ONCE on the runner and writer before it: dlib_driver
# carried dlib.inc and dlib_lib_driver was refused as an orphan, and the keys read alib.sno.
G="$T/gp/corpus/packages/snobol4/gimpel"; mkdir -p "$G" || exit 2
printf "* alib.inc - double a number\n\tDEFINE('DBL(X)')\t\t\t:(DBL_END)\nDBL\tDBL = 2 * X\t\t\t:(RETURN)\nDBL_END\n" > "$G/alib.inc"
printf -- "-INCLUDE \"alib.inc\"\n\tOUTPUT = 'DBL(21) = ' DBL(21)\n\tOUTPUT = 'DBL(-4) = ' DBL(-4)\nEND\n" > "$G/alib_driver.sno"
printf "* blib.inc - halve a number\n\tDEFINE('HALF(X)')\t\t\t:(HALF_END)\nHALF\tHALF = X / 2\t\t\t:(RETURN)\nHALF_END\n" > "$G/blib.inc"
printf -- "-INCLUDE \"blib.inc\"\n\tOUTPUT = 'HALF(9) = ' HALF(9)\n\tOUTPUT = 'V=' &VERSION\nEND\n" > "$G/blib_driver.sno"
printf "* clib.inc - triple a number\n\tDEFINE('TRIPLE(X)')\t\t\t:(TRIPLE_END)\nTRIPLE\tTRIPLE = 3 * X\t\t\t:(RETURN)\nTRIPLE_END\n" > "$G/clib.inc"
printf "* dlib.inc - square a number\n\tDEFINE('SQ(X)')\t\t\t:(SQ_END)\nSQ\tSQ = X * X\t\t\t:(RETURN)\nSQ_END\n" > "$G/dlib.inc"
printf -- "* dlib.spt - the form's own exerciser of dlib.inc\n-INCLUDE \"dlib.inc\"\n\tOUTPUT = 'SQ(7) = ' SQ(7)\nEND\n" > "$G/dlib.spt"
printf -- "-INCLUDE \"dlib.spt\"\n" > "$G/dlib_driver.sno"
printf -- "-INCLUDE \"dlib.inc\"\n\tOUTPUT = 'SQ(-3) = ' SQ(-3)\nEND\n" > "$G/dlib_lib_driver.sno"
for d in alib_driver dlib_driver dlib_lib_driver; do ( cd "$G" && "$SBL" -bf $d.sno ) > "$G/$d.ref" 2>&1 </dev/null; done
grep -qx 'DBL(21) = 42' "$G/alib_driver.ref" && grep -qx 'SQ(7) = 49' "$G/dlib_driver.ref" && grep -qx 'SQ(-3) = 9' "$G/dlib_lib_driver.ref" \
  || { echo "⛔ REFUSED(2): sbl -bf did not answer the gimpel fixture's drivers as expected -- $(cat "$G"/*_driver.ref | tr '\n' '|')"; exit 2; }
echo 'HALF(9) = 5' > "$G/blib_driver.ref"
printf '# fixture\n# name<TAB>CLASS<TAB>reason\nclib.inc\tNEEDS_DRIVER\ta library with no clib_driver.sno (gate fixture)\n' > "$G/UNGRADED.tsv"
printf '# fixture\n# name<TAB>CLASS<TAB>reason\n' > "$G/UNGRADABLE.tsv"

# rows <db> -- "program mode outcome" per recorded row, the program's basename without its extension
rows() { [ -f "$1" ] && awk -F'\t' 'NR>1 {p=$8; sub(/.*\//, "", p); sub(/\.[A-Za-z0-9]+$/, "", p); print p, $9, $10}' "$1"; }
progress_arms() {   # progress_arms <label> <db> <pass-lib> <fail-lib>
  local r; r="$(rows "$2")"
  { grep -qx "$3 m3 PASS" <<<"$r" && grep -qx "$3 m4 PASS" <<<"$r" && grep -qx "$4 m3 FAIL" <<<"$r" && grep -qx "$4 m4 FAIL" <<<"$r"; } \
    && ck ok "$1: progress rows are keyed by the libraries ($3 PASS, $4 FAIL, both modes)" \
    || ck no "$1: progress rows want $3 m3/m4 PASS and $4 m3/m4 FAIL, got: $(tr '\n' ';' <<<"$r")"
  grep -q '_driver ' <<<"$r" && ck no "$1: a progress row names a DRIVER: $(grep '_driver ' <<<"$r" | tr '\n' ';')" || ck ok "$1: no progress row names a driver"
}

echo "=== gate: a package runner grades a library through its driver, never the driver as a program (CEO-1269) ==="
# ---- arizona
AZ="$T/az/corpus/packages/icon/arizona_tests"; mkdir -p "$AZ/general" "$AZ/special" && cp "$I"/*.icn "$I"/*.ref "$AZ/general/" && cp "$I"/*.tsv "$AZ/"
S4E_HOME="$T/az" S4E_PROGRESS_DB="$T/az.tsv" timeout -k 5 600 bash "$HERE/test_icon_arizona_suite.sh" > "$T/az.out" 2>&1; rc=$?
if [ "$rc" = 2 ] || ! has "$T/az.out" '^ARIZONA_SUITE_BOARD '; then echo "⛔ REFUSED(2): the arizona runner did not measure the fixture (rc=$rc):"; tail -8 "$T/az.out" | sed 's/^/    /'; exit 2; fi
has "$T/az.out" '^ARIZONA_SUITE_BOARD shipped=3 graded=2 gap=1 m3_pass=1 ' && ck ok "arizona: shipped 3, graded 2 through their drivers, m3 pass 1" || ck no "arizona: $(grep -m1 '^ARIZONA_SUITE_BOARD' "$T/az.out" | cut -c1-120)"
has "$T/az.out" '^ARIZONA_AND_PER_PROGRAM and_pass=1 of 2 ' && ck ok "arizona: the AND per program is 1" || ck no "arizona: $(grep -m1 'AND_PER_PROGRAM' "$T/az.out" | cut -c1-120)"
has "$T/az.out" '^m3 FAIL: blib$' && has "$T/az.out" 'NOT GRADED .*general/clib' && ck ok "arizona: the failing library blib and the driverless clib are named" || ck no "arizona: blib/clib not named as non-passes"
has "$T/az.out" '^PACKAGE_INVENTORY package=arizona shipped=3 graded=2 ungraded=1 ' && ck ok "arizona: the inventory sums (clib owed, NEEDS_DRIVER)" || ck no "arizona: $(grep -m1 'PACKAGE_INVENTORY\|INVENTORY REFUSES' "$T/az.out" | cut -c1-140)"
progress_arms arizona "$T/az.tsv" alib blib
# ---- jcon
JC="$T/jc"; mkdir -p "$JC" && cp "$I"/*.icn "$I"/*.ref "$I"/*.tsv "$JC/"
S4E_PROGRESS_DB="$T/jc.tsv" timeout -k 5 600 bash "$HERE/test_icon_jcon_suite.sh" --corpus "$JC" > "$T/jc.out" 2>&1; rc=$?
if [ "$rc" = 2 ] || ! has "$T/jc.out" '^JCON_SUITE_BOARD '; then echo "⛔ REFUSED(2): the jcon runner did not measure the fixture (rc=$rc):"; tail -8 "$T/jc.out" | sed 's/^/    /'; exit 2; fi
has "$T/jc.out" '^JCON_SUITE_BOARD shipped=3 graded=2 gap=1 total=2 m3_pass=1 m4_pass=1' && ck ok "jcon: shipped 3, graded 2 through their drivers, pass 1 in each mode" || ck no "jcon: $(grep -m1 '^JCON_SUITE_BOARD' "$T/jc.out" | cut -c1-120)"
has "$T/jc.out" 'FAIL \(wrong output\): blib$' && has "$T/jc.out" '^UNGRADED .*clib\(' && ck ok "jcon: the failing library blib and the driverless clib are named" || ck no "jcon: blib/clib not named as non-passes"
has "$T/jc.out" '^PACKAGE_INVENTORY package=jcon shipped=3 graded=2 ungraded=1 ' && ck ok "jcon: the inventory sums (clib owed, NEEDS_DRIVER)" || ck no "jcon: $(grep -m1 'PACKAGE_INVENTORY\|INVENTORY REFUSES' "$T/jc.out" | cut -c1-140)"
progress_arms jcon "$T/jc.tsv" alib blib
# ---- THE SHIPPED LIBRARY, NOT ITS IPL NAMESAKE (coo 2026-09-25, hq_icon's measurement): SCRIP's link search reads IPATH, ICONPATH and
# its bundled ipl/procs before the source's directory, so a library named like an IPL procedure (options, strings, datetime ...) was
# linked from IPL. The fixture's options.icn answers "shipped"; iconx, linking the local ucode, cuts that ref; IPL's options() does not.
O="$T/ipl_ns"; mkdir -p "$O/cut" && printf 'procedure options();\n   return "shipped";\nend\n' > "$O/options.icn" \
  && printf 'link options\nprocedure main();\n   write(options());\nend\n' > "$O/options_driver.icn" && cp "$O"/*.icn "$O/cut/" \
  && ( cd "$O/cut" && "$ICONT" -s -c options.icn && "$ICONT" -s -o od options_driver.icn && "$ICONX" ./od ) > "$O/options_driver.ref" 2>&1 </dev/null
grep -qx shipped "$O/options_driver.ref" || { echo "⛔ REFUSED(2): iconx did not answer the IPL-namesake fixture with the shipped library -- $(tr '\n' '|' < "$O/options_driver.ref")"; exit 2; }
# ---- AND A PROGRAM THAT IS NOT A DRIVER LINKS IPL, NOT THE SHIPPED NAMESAKE (coo 2026-09-25, hq_icon's bisect of 6850da706): Arizona
# ilib's ref was cut by icont against its INSTALLED IPL ucode -- icont cannot see an untranslated .icn beside the program -- so the suite
# first on IPATH for every run linked the older shipped options.icn and turned ilib red in both modes. usesopt's ref is cut the same way,
# in a directory holding the shipped options.icn and no ucode for it: IPL's options([], "a") is an empty table (0), the shipped one "shipped" (7).
mkdir -p "$O/cutu" && printf 'link options\nprocedure main();\n   write(*options([], "a"));\nend\n' > "$O/usesopt.icn" && cp "$O/options.icn" "$O/usesopt.icn" "$O/cutu/" \
  && ( cd "$O/cutu" && "$ICONT" -s -o uo usesopt.icn && "$ICONX" ./uo ) > "$O/usesopt.ref" 2>&1 </dev/null
grep -qx 0 "$O/usesopt.ref" || { echo "⛔ REFUSED(2): icont did not link IPL's options for the non-driver fixture -- $(tr '\n' '|' < "$O/usesopt.ref")"; exit 2; }
printf '# fixture\n# name<TAB>CLASS<TAB>reason\n' > "$O/UNGRADED.tsv"; printf '# fixture\n# name<TAB>CLASS<TAB>reason\n' > "$O/UNGRADABLE.tsv"
OZ="$T/oz/corpus/packages/icon/arizona_tests"; mkdir -p "$OZ/general" "$OZ/special" && cp "$O"/options.icn "$O"/options_driver.icn "$O"/options_driver.ref "$O"/usesopt.icn "$O"/usesopt.ref "$OZ/general/" && cp "$O"/*.tsv "$OZ/"
S4E_HOME="$T/oz" S4E_PROGRESS_DB="$T/oz.tsv" timeout -k 5 600 bash "$HERE/test_icon_arizona_suite.sh" > "$T/oz.out" 2>&1
has "$T/oz.out" '^ARIZONA_SUITE_BOARD shipped=2 graded=2 gap=0 m3_pass=2 .* m4_pass=2 ' && ck ok "arizona: a library named like an IPL procedure is linked from the suite by its driver, and a non-driver linking that name gets IPL's (m3 and m4 pass both)" || ck no "arizona: the IPL-namesake library or its non-driver user: $(grep -m1 '^ARIZONA_SUITE_BOARD' "$T/oz.out" | cut -c1-120) $(grep -m2 '^FAIL' "$T/oz.out" | tr '\n' ' ' | cut -c1-120)"
OJ="$T/oj"; mkdir -p "$OJ" && cp "$O"/options.icn "$O"/options_driver.icn "$O"/options_driver.ref "$O"/usesopt.icn "$O"/usesopt.ref "$O"/*.tsv "$OJ/"
S4E_PROGRESS_DB="$T/oj.tsv" timeout -k 5 600 bash "$HERE/test_icon_jcon_suite.sh" --corpus "$OJ" > "$T/oj.out" 2>&1
has "$T/oj.out" '^JCON_SUITE_BOARD shipped=2 graded=2 gap=0 total=2 m3_pass=2 m4_pass=2' && ck ok "jcon: a library named like an IPL procedure is linked from the package by its driver, and a non-driver linking that name gets IPL's (m3 and m4 pass both)" || ck no "jcon: the IPL-namesake library or its non-driver user: $(grep -m1 '^JCON_SUITE_BOARD' "$T/oj.out" | cut -c1-120) $(grep -m2 'FAIL' "$T/oj.out" | tr '\n' ' ' | cut -c1-120)"
# ---- EVERY NAME ON A link LINE, TRANSITIVELY (coo 2026-09-25, hq_icon's measurement landing the Jcon drivers): the Jcon m3 rundir
# took only the FIRST name of `link load2, load1` and none of a library's own links, so m3 could not open the rest while m4 passed.
# mlib_driver links "mlib, nlib" on one line and mlib links helper; the ref is iconx's, "hmn".
L="$T/lk"; mkdir -p "$L/cut" && printf 'link helper\nprocedure m();\n   return helper() || "m";\nend\n' > "$L/mlib.icn" \
  && printf 'procedure helper();\n   return "h";\nend\n' > "$L/helper.icn" && printf 'procedure n();\n   return "n";\nend\n' > "$L/nlib.icn" \
  && printf 'link mlib, nlib\nprocedure main();\n   write(m(), n());\nend\n' > "$L/mlib_driver.icn" && cp "$L"/*.icn "$L/cut/" \
  && ( cd "$L/cut" && "$ICONT" -s -c helper.icn nlib.icn mlib.icn && "$ICONT" -s -o md mlib_driver.icn && "$ICONX" ./md ) > "$L/mlib_driver.ref" 2>&1 </dev/null
grep -qx hmn "$L/mlib_driver.ref" || { echo "⛔ REFUSED(2): iconx did not answer the link-line fixture -- $(tr '\n' '|' < "$L/mlib_driver.ref")"; exit 2; }
rm -rf "$L/cut"; printf '# fixture\n# name<TAB>CLASS<TAB>reason\nhelper.icn\tNEEDS_DRIVER\tlinked by mlib, no driver (fixture)\nnlib.icn\tNEEDS_DRIVER\tlinked by the driver, no driver of its own (fixture)\n' > "$L/UNGRADED.tsv"
printf '# fixture\n# name<TAB>CLASS<TAB>reason\n' > "$L/UNGRADABLE.tsv"
S4E_PROGRESS_DB="$T/lk.tsv" timeout -k 5 600 bash "$HERE/test_icon_jcon_suite.sh" --corpus "$L" > "$T/lk.out" 2>&1
_lb="$(grep -m1 '^JCON_SUITE_BOARD ' "$T/lk.out")"; _lok=1; for _kv in shipped=3 graded=1 gap=2 m3_pass=1 m4_pass=1; do grep -qE "(^| )$_kv( |\$)" <<<"$_lb" || _lok=0; done   # each field on its own (CEO-839)
[ -n "$_lb" ] && [ "$_lok" = 1 ] && ck ok "jcon: a driver linking two libraries on one line, one of which links a third, passes in m3 as in m4" || ck no "jcon: the link-line fixture: $(grep -m1 '^JCON_SUITE_BOARD' "$T/lk.out" | cut -c1-120) $(grep -m1 'FAIL' "$T/lk.out" | cut -c1-100)"
# ---- ipl (coo 2026-09-25, hq_icon's ask: the 382 IPL libraries CEO-1272 made NEEDS_DRIVER are graded through NAME_driver like Arizona's
# and Jcon's). procs/alib is a library with a passing driver and procs/blib one whose driver's ref is deliberately wrong; procs/opt's
# driver must link procs/opt.icn, not the progs/opt.icn namesake that ICONPATH names first -- IPL ships four basenames twice over,
# so the driver run puts its own directory first on IPATH. Every ref is cut live from iconx in a directory holding only its closure.
IP="$T/ipl/corpus/packages/icon/ipl"; mkdir -p "$IP/progs" "$IP/procs" "$IP/gprogs" "$IP/gprocs" "$IP/incl" "$IP/gincl" "$T/ipl/cut"
cp "$I/alib.icn" "$I/alib_driver.icn" "$I/blib.icn" "$I/blib_driver.icn" "$IP/procs/"; cp "$I/alib_driver.ref" "$IP/procs/"; cp "$C/blib_oracle.txt" "$IP/procs/blib_driver.ref"; printf 'half(9) = 5\n' > "$IP/procs/blib_driver.ref"
printf 'procedure opt();\n   return "procs";\nend\n' > "$IP/procs/opt.icn"; printf 'link opt\nprocedure main();\n   write(opt());\nend\n' > "$IP/procs/opt_driver.icn"
printf 'procedure opt();\n   return "progs";\nend\nprocedure main();\n   write(opt());\nend\n' > "$IP/progs/opt.icn"
cp "$IP/procs/opt.icn" "$IP/procs/opt_driver.icn" "$T/ipl/cut/" && ( cd "$T/ipl/cut" && "$ICONT" -s -c opt.icn && "$ICONT" -s -o od opt_driver.icn && "$ICONX" ./od ) > "$IP/procs/opt_driver.ref" 2>&1 </dev/null
mkdir -p "$T/ipl/cut2" && cp "$IP/progs/opt.icn" "$T/ipl/cut2/" && ( cd "$T/ipl/cut2" && "$ICONT" -s -o op opt.icn && "$ICONX" ./op ) > "$IP/progs/opt.ref" 2>&1 </dev/null
grep -qx procs "$IP/procs/opt_driver.ref" && grep -qx progs "$IP/progs/opt.ref" || { echo "⛔ REFUSED(2): iconx did not answer the IPL namesake fixture -- $(cat "$IP/procs/opt_driver.ref" "$IP/progs/opt.ref" | tr '\n' '|')"; exit 2; }
printf '# fixture\n' > "$IP/UNGRADED.tsv"; printf '# fixture\n' > "$IP/UNGRADABLE.tsv"
S4E_HOME="$T/ipl" S4E_PROGRESS_DB="$T/ipl.tsv" timeout -k 5 900 bash "$HERE/test_icon_ipl_suite.sh" > "$T/ipl.out" 2>&1; rc=$?
if [ "$rc" = 2 ] || ! has "$T/ipl.out" '^IPL_RUN_BOARD '; then echo "⛔ REFUSED(2): the ipl runner did not measure the fixture (rc=$rc):"; grep -m3 'REFUS\|UNPROVEN' "$T/ipl.out" | sed 's/^/    /'; exit 2; fi
_ib="$(grep -m1 '^PACKAGE_INVENTORY package=ipl ' "$T/ipl.out")"; _iok=1; for _kv in shipped=4 graded=4 ungraded=0; do grep -qE "(^| )$_kv( |\$)" <<<"$_ib" || _iok=0; done
[ "$_iok" = 1 ] && has "$T/ipl.out" '^IPL_AND_PER_PROGRAM and_pass=3 of 4 ' && ck ok "ipl: 3 libraries graded through their drivers and 1 program, the drivers out of shipped (4 of 4 graded, AND 3 -- blib's ref is wrong)" \
  || ck no "ipl: the inventory or the AND: $(cut -c1-110 <<<"$_ib") :: $(grep -m1 '^IPL_AND_PER_PROGRAM' "$T/ipl.out" | cut -c1-90)"
progress_arms ipl "$T/ipl.tsv" alib blib
{ grep -qx 'opt m3 PASS' <<<"$(rows "$T/ipl.tsv")" && ! grep -q 'm3_RUN_FAIL=.*opt\|RUN_FAIL:.* opt' "$T/ipl.out" && has "$T/ipl.out" '^mode-3 \(--run\): +RUN_PASS=3 ' && has "$T/ipl.out" '^mode-4 \(--compile\): RUN_PASS=3 '; } \
  && ck ok "ipl: procs/opt's driver links procs/opt.icn, not the progs/opt.icn namesake ICONPATH names first (both modes pass)" \
  || ck no "ipl: the IPL-namesake driver: $(grep -E '^mode-[34]' "$T/ipl.out" | tr '\n' ' ' | cut -c1-200)"
# ---- gimpel
CORPUS="$T/gp/corpus" S4E_PROGRESS_DB="$T/gp.tsv" timeout -k 5 900 bash "$HERE/test_snobol4_gimpel_suite.sh" > "$T/gp.out" 2>&1; rc=$?
if has "$T/gp.out" 'whose library the package does not ship'; then ck no "gimpel: a library shipped as name.inc or name.spt (or a twice-shipped stem's x.inc, through x_lib_driver) reads as unshipped -- its driver refused as an orphan: $(grep -m1 -o 'does not ship:[^-]*' "$T/gp.out")"
elif [ "$rc" = 2 ] || ! has "$T/gp.out" '^GIMPEL_BOARD '; then echo "⛔ REFUSED(2): the gimpel runner did not measure the fixture (rc=$rc -- another SNOBOL4 board on this box is a refusal, not a red):"; tail -8 "$T/gp.out" | sed 's/^/    /'; exit 2; fi
has "$T/gp.out" '^GIMPEL_LIBRARIES shipped=5 graded_through_a_driver=4 no_driver=1 ' && ck ok "gimpel: shipped 5 (4 libraries and the program dlib.spt), 4 graded through their drivers, 1 with none" || ck no "gimpel: $(grep -m1 'GIMPEL_LIBRARIES' "$T/gp.out" | cut -c1-120)"
has "$T/gp.out" '^GIMPEL_BOARD total=4 .* m3_pass=3 m3_fail=1 m4_pass=3 m4_fail=1 ' && ck ok "gimpel: pass 3 in each mode (alib, dlib.spt, dlib.inc)" || ck no "gimpel: $(grep -m1 '^GIMPEL_BOARD' "$T/gp.out" | cut -c1-120)"
has "$T/gp.out" '^  RED    blib\.inc \(driver ' && has "$T/gp.out" '^NO DRIVER .*: clib$' && ck ok "gimpel: the failing library blib.inc and the driverless clib are named" || ck no "gimpel: blib/clib not named as non-passes"
has "$T/gp.out" '^PACKAGE_INVENTORY package=gimpel shipped=5 graded=4 ungraded=1 ' && ck ok "gimpel: the inventory sums (clib owed, NEEDS_DRIVER)" || ck no "gimpel: $(grep -m1 'PACKAGE_INVENTORY\|INVENTORY REFUSES' "$T/gp.out" | cut -c1-140)"
has "$T/gp.out" 'both_modes_pass=3/5 \(5 shipped libraries minus EXCLUDED=0 ' && ck ok "gimpel: the row it would publish is 3/5 over the shipped libraries" || ck no "gimpel: the row text is not 3/5 over the libraries: $(grep -m1 -o 'both_modes_pass=[^ ]*' "$T/gp.out")"
progress_arms gimpel "$T/gp.tsv" alib blib
_gk="$(awk -F'\t' 'NR>1 && $6=="gimpel" {p=$8; sub(/.*\//, "", p); print p}' "$T/gp.tsv" 2>/dev/null | sort -u | tr '\n' ' ')"
[ "$_gk" = "alib.inc blib.inc dlib.inc dlib.spt " ] && ck ok "gimpel: every progress key is the library's own file -- alib.inc, blib.inc, dlib.inc (through dlib_lib_driver), dlib.spt" \
  || ck no "gimpel: progress keys want 'alib.inc blib.inc dlib.inc dlib.spt', got '$_gk'"

echo "population: $checks arm(s) over 4 runners, 3 scratch packages of 3 libraries each plus one IPL-namesake library and one non-driver program linking its name per Icon runner, and one two-name link line for jcon; an ipl package with two drivers and a progs/ namesake; refs cut live from iconx and sbl -bf"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [package_runners_grade_a_library_through_its_driver]: $checks of $checks arms hold"; exit 0; fi
echo "⛔ GATE FAIL(1) [package_runners_grade_a_library_through_its_driver]: $fails of $checks arms red"; exit 1
