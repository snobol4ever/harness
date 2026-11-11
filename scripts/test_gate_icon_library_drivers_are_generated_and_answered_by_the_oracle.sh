#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icon_library_drivers_are_generated_and_answered_by_the_oracle.sh -- util_icon_library_drivers.py writes a driver for every Icon or
# Unicon library file (no procedure main) that loads it and writes what it declares, so a suite of libraries is graded (the coo 2026-11-11,
# COO-516; Lon the same morning, verbatim: "Make drivers for library ones, and run the others. Let's get these GRADED."). The driver's answer is
# the oracle's run of it; SCRIP is graded against that.
#
# THE ARMS (a scratch folder: a library, a package file, a program, a file of globals alone):
#   1  a driver is written for the library and for the package file, naming each procedure, record and class once; the program and the file that
#      declares nothing are skipped by name; a declaration inside a comment is not named
#   2  the Unicon oracle answers both drivers with the kinds, names, images and arities (a package member under its package name)
#   3  SCRIP answers both drivers as the oracle does (mode 3)
#   4  --check reads rc 0 on the written folder and rc 1, naming the file, once a driver is removed
# EXIT: 0 all arms pass, 1 an arm failed, 2 REFUSED (no binary, no oracle, no scratch directory).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME=icon_library_drivers_are_generated_and_answered_by_the_oracle
. "$HERE/lib_oracle_flags.sh" 2>/dev/null
UN="$(unicon_bin 2>/dev/null)"; [ -n "$UN" ] && [ -x "$UN" ] || { echo "REFUSE(2) [$NAME]: no Unicon oracle (unicon_bin)"; exit 2; }
SCRIP="$HERE/../../SCRIP/scrip"; [ -x "$SCRIP" ] || { echo "REFUSE(2) [$NAME]: no scrip binary at $SCRIP"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/gate_icn_drivers.XXXXXX")" || { echo "REFUSE(2) [$NAME]: no scratch directory"; exit 2; }
trap 'rm -rf "$T"' EXIT
D="$T/lib"; mkdir -p "$D"
printf 'record point(x, y)\nprocedure dist(p, q)\n   return abs(p.x - q.x);\nend\nprocedure va(a[])\n   return *a;\nend\nclass Shape(name)\n   method area()\n      return 0;\n   end\nend\n# procedure hidden()\n' > "$D/geo.icn"
printf 'package pk\nprocedure inpk(a)\n   return a;\nend\nclass PC(v)\n   method m()\n      return v;\n   end\nend\n' > "$D/pkf.icn"
printf 'procedure main()\n   write("a program");\nend\n' > "$D/prog.icn"
printf 'global counter\n' > "$D/globals.icn"
pass=0; fail=0
ck() { if [ "$1" = ok ]; then pass=$((pass + 1)); echo "  ok   $2"; else fail=$((fail + 1)); echo "  FAIL $2"; fi; }
python3 "$HERE/util_icon_library_drivers.py" "$D" > "$T/1.log" 2>&1; r1=$?
want_geo='link geo
procedure main()
   write("record point ", image(point), " ", image(args(point)) | "no-args");
   write("procedure dist ", image(dist), " ", image(args(dist)) | "no-args");
   write("procedure va ", image(va), " ", image(args(va)) | "no-args");
   write("class Shape ", image(Shape), " ", image(args(Shape)) | "no-args");
end'
[ "$r1" = 0 ] && [ "$(sed 1d "$D/geo_driver.icn" 2>/dev/null)" = "$want_geo" ] && grep -q '^import pk$' "$D/pkf_driver.icn" 2>/dev/null && [ ! -e "$D/prog_driver.icn" ] && [ ! -e "$D/globals_driver.icn" ] \
  && grep -q "^SKIP	prog.icn	a program" "$T/1.log" && grep -q "^SKIP	globals.icn	declares no procedure, record or class" "$T/1.log" && ! grep -q hidden "$D/geo_driver.icn" \
  && ck ok "(1) a driver for the library and for the package file; the program and the globals file skipped by name; a commented declaration not named" \
  || ck no "(1) rc=$r1 $(tr '\n' ';' < "$T/1.log" | cut -c1-300)"
( cd "$D" && "$UN" -s -c geo.icn pkf.icn > "$T/cc.log" 2>&1 )
want_o='record point record constructor point 2
procedure dist procedure dist 2
procedure va procedure va -1
class Shape procedure Shape 1
procedure inpk procedure pk__inpk 1
class PC procedure pk__PC 1'
o="$( cd "$D" && for d in geo_driver pkf_driver; do timeout -k 5 120 bash "$HERE/unicon_oracle_run.sh" --here "$d.icn" < /dev/null 2> /dev/null; done )"
[ "$o" = "$want_o" ] && ck ok "(2) the Unicon oracle answers both drivers: kinds, names, images, arities, the package name on its members" || ck no "(2) the oracle answered [$(printf '%s' "$o" | tr '\n' ';')]"
s="$( cd "$D" && for d in geo_driver pkf_driver; do timeout -k 5 120 "$SCRIP" --dialect=unicon --run "$d.icn" < /dev/null 2> /dev/null; done )"
[ "$s" = "$o" ] && [ -n "$s" ] && ck ok "(3) SCRIP answers both drivers as the oracle does" || ck no "(3) SCRIP answered [$(printf '%s' "$s" | tr '\n' ';')]"
python3 "$HERE/util_icon_library_drivers.py" "$D" --check > "$T/4a.log" 2>&1; r4a=$?
rm -f "$D/pkf_driver.icn"; python3 "$HERE/util_icon_library_drivers.py" "$D" --check > "$T/4b.log" 2>&1; r4b=$?
[ "$r4a" = 0 ] && [ "$r4b" = 1 ] && grep -q "^DIFFERS	pkf.icn	no driver" "$T/4b.log" && [ ! -e "$D/pkf_driver.icn" ] && ck ok "(4) --check: rc 0 when current, rc 1 naming the file once a driver is gone, and it writes nothing" || ck no "(4) rc $r4a then $r4b :: $(tail -2 "$T/4b.log" | tr '\n' ';' | cut -c1-200)"
echo "ICON_LIBRARY_DRIVERS_GATE_BOARD arms=4 pass=$pass fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null))"
[ "$fail" = 0 ] && [ "$pass" = 4 ] && { echo "GATE OK [$NAME]: a library file gets a generated driver, answered by the oracle and by SCRIP alike"; exit 0; }
echo "GATE FAIL [$NAME]: $fail arm(s) failed"; exit 1
