#!/usr/bin/env bash
# test_gate_icn_ipl_declared_status_and_empty_output_are_graded.sh -- A PROGRAM WHOSE CORRECT EXIT STATUS IS NOT 0, OR WHOSE CORRECT
# OUTPUT IS EMPTY, IS GRADED ON IT (hq_icon 2026-09-27; Lon's word "Get IPL to 843."; ceo CEO-1315). IPL's ttt, hr and krieg end
# every run in stop() (status 1); progs/proto exits before it prints. The status is declared in the pre-existing NAME.rc (seat07's
# sidecar, which the cutter already mints under) and test_icon_ipl_suite.sh now grades it in both modes; an empty output by design
# is declared in NAME.empty, with its reason, and the cutter then mints the empty ref instead of refusing it as EMPTY.
# ARMS: (a) GREEN a planted stop() unit with NAME.rc = 1 mints and matches in m3 and m4 with status 1 checked; (b) the runner
# grades NAME.rc in its m3 and m4 verdicts (read off test_icon_ipl_suite.sh) and a copy without that check reads RED; (c) GREEN a
# planted unit that exits before printing, with NAME.empty, mints a 0-byte ref that m3 and m4 match; (d) RED a cutter copy
# whose EMPTY arm ignores NAME.empty (the origin behaviour) refuses it; (e) RED a declared status that is WRONG (a comment line, then 0,
# for a unit that exits 1) is refused by the cutter -- before ipl_rc_declared the cutter read the file with a bare cat, compared the
# integer to a two-line string, the test errored, and the unit minted with its status never compared (the coo's review of 569bf02c6);
# (f) RED a malformed NAME.rc ("1 2") is refused as RC_SIDECAR_MALFORMED, never compared as a string or skipped.
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_declared_status_and_empty_output_are_graded
sg_init
plant_rc() {
  printf 'procedure main()\n   writes("prompt: ");\n   write("a line");\n   stop("Game Over.");\nend\n' > "$SG_PKG/progs/rcw.icn"
  printf '# every exit is stop()\n1\n' > "$SG_PKG/progs/rcw.rc"
}
plant_rc_wrong() {
  printf 'procedure main()\n   writes("prompt: ");\n   write("a line");\n   stop("Game Over.");\nend\n' > "$SG_PKG/progs/rcw.icn"
  printf '# a wrong declaration: the unit exits 1\n0\n' > "$SG_PKG/progs/rcw.rc"
}
plant_rc_bad() {
  printf 'procedure main()\n   writes("prompt: ");\n   write("a line");\n   stop("Game Over.");\nend\n' > "$SG_PKG/progs/rcw.icn"
  printf '1 2\n' > "$SG_PKG/progs/rcw.rc"
}
plant_empty() {
  printf 'procedure main()\n   exit();\n   write("never");\nend\n' > "$SG_PKG/progs/emw.icn"
  printf 'exit() is the first statement, so the program prints nothing by design\n' > "$SG_PKG/progs/emw.empty"
}
red=0
g="$(sg_verdict "$SG_HERE" rcw plant_rc)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL (a) green: $g"; red=1 ;; esac
rgrade() { grep -cE 'elif \[ -n "\$want_rc" \] && \[ "\$rc[34]" -ne "\$want_rc" \]' "$1/test_icon_ipl_suite.sh"; }
[ "$(rgrade "$SG_HERE")" -eq 2 ] || { echo "  FAIL (b): test_icon_ipl_suite.sh does not grade NAME.rc in both modes"; red=1; }
d="$(sg_doctor "import re; s = re.sub(r'\n *elif \[ -n \"\\\$want_rc\" \].*', '', s)" test_icon_ipl_suite.sh)" || exit 2
[ "$(rgrade "$d")" -eq 0 ] || { echo "  FAIL (b) red: the doctored runner still reads as grading NAME.rc"; red=1; }
e="$(sg_verdict "$SG_HERE" emw plant_empty)"
case "$e" in "MINTED=1 M3=PASS M4=PASS REF=0") ;; *) echo "  FAIL (c) green: $e"; red=1 ;; esac
d2="$(sg_doctor "s = s.replace('if [ \"\$by1\" -eq 0 ] && ! ipl_empty_declared \"\$PROGS/\$f\" 2>/dev/null; then', 'if [ \"\$by1\" -eq 0 ]; then', 1)" util_cut_icon_ipl_refs.sh)" || exit 2
r="$(sg_verdict "$d2" emw plant_empty)"
case "$r" in "MINTED=0"*) ;; *) echo "  FAIL (d) red: a cutter ignoring NAME.empty still minted ($r)"; red=1 ;; esac
w="$(sg_verdict "$SG_HERE" rcw plant_rc_wrong)"
case "$w" in "MINTED=0"*) ;; *) echo "  FAIL (e) red: a wrong declared status behind a comment line still minted ($w)"; red=1 ;; esac
b="$(sg_verdict "$SG_HERE" rcw plant_rc_bad)"
case "$b" in "MINTED=0"*) ;; *) echo "  FAIL (f) red: a malformed NAME.rc still minted ($b)"; red=1 ;; esac
grep -q '^RC_SIDECAR_MALFORMED	rcw.icn' "$SG_T/cut.$(basename "$SG_HERE").log" || { echo "  FAIL (f): the cutter did not classify the malformed NAME.rc as RC_SIDECAR_MALFORMED"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: a declared status 1 is minted and graded in m3 and m4 ($g), the runner's check reads red when removed, a wrong status is refused ($w) and a malformed one is RC_SIDECAR_MALFORMED ($b); an empty-by-design unit mints and matches ($e), and without NAME.empty refuses ($r)"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
