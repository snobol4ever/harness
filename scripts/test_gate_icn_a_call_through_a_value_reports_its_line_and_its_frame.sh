#!/usr/bin/env bash
# test_gate_icn_a_call_through_a_value_reports_its_line_and_its_frame.sh -- A CALL THROUGH A VALUE THAT IS NOT INVOCABLE RAISES 106 AT
# THE LINE ICONX NAMES, AND ITS TRACEBACK ENDS WITH THE ATTEMPTED CALL, IN BOTH MODES (hq_icon 2026-09-27, crawl work under CEO-1270:
# IPL progs/strpsgml, whose every run ends in error 106 from a local that shadows a linked procedure).
#
# Two defects, one report. (1) THE LINE: icont stamps a location on every operation just before it runs it (tcode.c setloc), and iconx
# reports the location in effect at the instruction AFTER the failing invoke -- the invocation's own line, or its parent operation's
# when the invoke is that operation's last operand. SCRIP stamped a call through a value with no line at all, so an error in a do,
# then, else, case or conjunction body reported the line its statement began on. A value call now marks its own line, and keeps no mark
# when it is the last operand of a parent on another line (a mark there would be right for a procedure's frame and wrong for the 106,
# so it stays as it was). (2) THE FRAME: iconx's traceback ends with the attempted call and its arguments undereferenced --
# "&null((variable = "a")) from line 4" -- and SCRIP printed no such frame; rt_call_value_spine_prep also dereferenced the arguments
# before it declined a callee with no name. The error now pushes a builtin frame record that carries the callee, and the decline
# comes first. The rungs cannot grade this -- it discards stderr -- so it is graded here: six witnesses under icont/iconx, m3 and m4,
# stdout and stderr merged and read through the error-voice renderer the suite runners use. On the tree before the cure, w_do, w_then,
# w_case and w_conj differ in the line and every witness differs in the frame (red).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
G=test_gate_icn_a_call_through_a_value_reports_its_line_and_its_frame
S="$HERE/../../SCRIP/scrip"; O="$HERE/../../SCRIP/out"
[ -x "$S" ] || { echo "⛔ GATE REFUSE(2) [$G]: scrip not built"; exit 2; }
IC=/home/resources/icon-master/bin/icont
[ -x "$IC" ] || { echo "⛔ GATE REFUSE(2) [$G]: icont not found at $IC -- the oracle is required"; exit 2; }
T="$(mktemp -d "${TMPDIR:-/tmp}/callvalue_gate.XXXXXX")" || { echo "⛔ GATE REFUSE(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
printf 'procedure main()\n   local f, line;\n   every line := !["a"] do\n\twrite(f(line));\nend\n' > "$T/w_do.icn"
printf 'procedure main()\n   local f;\n   if 1 then\n\tf(1, "b");\nend\n' > "$T/w_then.icn"
printf 'procedure main()\n   local f;\n   case 1 of {\n1:\n\tf(1)};\nend\n' > "$T/w_case.icn"
printf 'procedure main()\n   local f;\n   1 &\n\tf(1);\nend\n' > "$T/w_conj.icn"
printf 'procedure main()\n   local f;\n   {write(1);\n\tf([])};\nend\n' > "$T/w_compound.icn"
printf 'procedure main()\n   local f;\n   write(1,\n\tf(1));\nend\n' > "$T/w_lastarg.icn"
red=0; n=0
for w in w_do w_then w_case w_conj w_compound w_lastarg; do
    n=$((n+1))
    ( cd "$T" && "$IC" -s -o "$w.ox" "$w.icn" >/dev/null 2>&1 && ./"$w.ox" > "$w.oracle.txt" 2>&1 )
    grep -q 'Run-time error 106' "$T/$w.oracle.txt" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's $w run raised no error 106 -- the witness no longer measures this"; exit 2; }
    ( cd "$T" && "$S" "$w.icn" < /dev/null 2>&1 | python3 "$HERE/util_render_error_voice.py" icon > "$w.m3.txt" )
    ( cd "$T" && "$S" --compile --out="$w.s" "$w.icn" < /dev/null >/dev/null 2>&1 ) && gcc -no-pie -o "$T/$w.x" "$T/$w.s" -Wl,-rpath,"$O" -L"$O" -lscrip_rt -lm -lpthread 2>/dev/null \
        || { echo "⛔ GATE REFUSE(2) [$G]: m4 did not build $w"; exit 2; }
    ( cd "$T" && ./"$w.x" < /dev/null 2>&1 | python3 "$HERE/util_render_error_voice.py" icon > "$w.m4.txt" )
    cmp -s "$T/$w.oracle.txt" "$T/$w.m3.txt" || { echo "  $w: m3 differs from iconx:"; diff "$T/$w.oracle.txt" "$T/$w.m3.txt" | head -8; red=1; }
    cmp -s "$T/$w.oracle.txt" "$T/$w.m4.txt" || { echo "  $w: m4 differs from iconx:"; diff "$T/$w.oracle.txt" "$T/$w.m4.txt" | head -8; red=1; }
done
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: $n witnesses -- error 106 through a value names iconx's line and ends its traceback with the attempted call, m3 and m4"; exit 0; }
echo "⛔ GATE FAIL [$G]: a call through a value reports the wrong line or frame"; exit 1
