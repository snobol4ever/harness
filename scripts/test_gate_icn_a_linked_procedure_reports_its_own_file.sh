#!/usr/bin/env bash
# test_gate_icn_a_linked_procedure_reports_its_own_file.sh -- A PROCEDURE FROM A LINKED FILE NAMES THAT FILE, IN BOTH MODES, AS ICONX DOES
# (hq_icon 2026-09-27, crawl work under CEO-1270: IPL iftrace, whose &trace lines name iftrace.icn for the linked set_trace).
#
# icon_driver.c appended a linked file's declarations to the program with no file identity, and the lowerer stamped every
# statement mark and &file with the main source, so everything that names a file named the wrong one for a linked procedure:
# &file read m.icn, a &trace line printed "m.icn : 3 | p returned 2", and a run-time error in a linked procedure reported
# "File m.icn; Line 6" and "{2 + "abc"} from line 6 in m.icn". The link loop now tags each linked statement with a :file attribute
# and the lowerer carries it per procedure into &file and the statement marks (a program that links nothing pays nothing).
# The rungs cannot grade this -- its entries are single files and it discards stderr -- so it is graded here: a two-file
# witness under icont/iconx, m3 and m4 with stdout and stderr merged into one file and read through the error-voice renderer
# the suite runners use, twice -- once under --stlimit with &trace on (the trace hooks' statement marks) and once with neither
# (the plain marks). On lower_icon.c before the cure every run differs (red).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_a_linked_procedure_reports_its_own_file
S="$HERE/../../SCRIP/scrip"; O="$HERE/../../SCRIP/out"
[ -x "$S" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
IC=/home/resources/icon-master/bin/icont
[ -x "$IC" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont not found at $IC -- the oracle is required"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/linkfile_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
cat > "$T/lib1.icn" <<'ICN'
procedure p(x)
   write("in p ", &file, " ", &line);
   return x + 1;
end
procedure q(x)
   return x + "abc";
end
ICN
cat > "$T/traced.icn" <<'ICN'
link lib1
procedure main()
   &trace := -1;
   write(p(1));
   write(&file, " ", &line);
   &trace := 0;
   write(q(2));
end
ICN
cat > "$T/plain.icn" <<'ICN'
link lib1
procedure main()
   write(p(1));
   write(&file, " ", &line);
   write(q(2));
end
ICN
( cd "$T" && "$IC" -s -c lib1.icn >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: icont did not translate the linked file"; exit 2; }
red=0
for w in traced plain; do
    sw=(); [ "$w" = traced ] && sw=(--stlimit)
    ( cd "$T" && "$IC" -s -o "$w.ox" "$w.icn" >/dev/null 2>&1 && ./"$w.ox" > "$w.oracle.txt" 2>&1 ); [ -s "$T/$w.oracle.txt" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont/iconx did not run $w"; exit 2; }
    ( cd "$T" && "$S" "${sw[@]}" "$w.icn" < /dev/null 2>&1 | python3 "$HERE/util_render_error_voice.py" icon > "$w.m3.txt" )
    ( cd "$T" && "$S" --compile "${sw[@]}" --out="$w.s" "$w.icn" < /dev/null >/dev/null 2>&1 ) && gcc -no-pie -o "$T/$w.x" "$T/$w.s" -Wl,-rpath,"$O" -L"$O" -lscrip_rt -lm -lpthread 2>/dev/null \
        || { echo "⛔ GATE REFUSE(2) [$G]: m4 did not build $w"; exit 2; }
    ( cd "$T" && ./"$w.x" < /dev/null 2>&1 | python3 "$HERE/util_render_error_voice.py" icon > "$w.m4.txt" )
    grep -q 'lib1.icn' "$T/$w.oracle.txt" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's $w run names no linked file -- the witness no longer measures this"; exit 2; }
    cmp -s "$T/$w.oracle.txt" "$T/$w.m3.txt" || { echo "  $w: m3 differs from iconx:"; diff "$T/$w.oracle.txt" "$T/$w.m3.txt" | head -8; red=1; }
    cmp -s "$T/$w.oracle.txt" "$T/$w.m4.txt" || { echo "  $w: m4 differs from iconx:"; diff "$T/$w.oracle.txt" "$T/$w.m4.txt" | head -8; red=1; }
done
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: &file, &trace lines and run-time error reports name the linked file in m3 and m4, traced and plain, as iconx"; exit 0; }
echo "⛔ GATE FAIL [$G]: a linked procedure is reported under the wrong file"; exit 1
