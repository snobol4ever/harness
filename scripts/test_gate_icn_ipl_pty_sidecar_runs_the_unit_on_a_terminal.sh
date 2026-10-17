#!/usr/bin/env bash
# test_gate_icn_ipl_pty_sidecar_runs_the_unit_on_a_terminal.sh -- NAME.pty RUNS THE UNIT ON A PSEUDO-TERMINAL FOR THE REF AND BOTH
# SCRIP MODES ALIKE (hq_icon 2026-09-27; Lon's word "Get IPL to 843."; ceo CEO-1315). IPL's bj and snake run stty on their standard
# input and exit 4 when it is not a terminal; getchlib and iprofile read a terminal. ipl_pty_declared/ipl_pty_cmd in
# lib_icon_ipl_isolation.sh wrap the run in script(1) -- iconx in the cutter's run_isolated, SCRIP in ipl_isolation_run.
# GREEN: a planted unit asking whether its standard input is a terminal cuts a ref that says so (CRLF line ends from the terminal)
# and m3 and m4 match it. RED: a copy that ignores NAME.pty (the origin behaviour) cuts a ref saying "no terminal".
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_pty_sidecar_runs_the_unit_on_a_terminal
command -v script >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: script(1) is not installed"; exit 2; }
sg_init
plant() {
  printf 'procedure main()\n   system("tty -s && echo terminal || echo no terminal");\n   write("done");\nend\n' > "$SG_PKG/progs/ptyw.icn"
  printf 'the unit asks whether its standard input is a terminal\n' > "$SG_PKG/progs/ptyw.pty"
}
red=0
g="$(sg_verdict "$SG_HERE" ptyw plant)"; gref="$(cat "$(sg_ref "$SG_HERE" ptyw)" 2>/dev/null)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL green: $g"; red=1 ;; esac
printf '%s' "$gref" | grep -q '^terminal' || { echo "  FAIL green: the ref does not say the unit ran on a terminal: $(printf '%s' "$gref" | tr '\n\r' '|~')"; red=1; }
d="$(sg_doctor "s = s.replace('ipl_pty_declared() {\n  local side=\"\${1%.icn}.pty\" r\n', 'ipl_pty_declared() {\n  return 1\n  local side=\"\${1%.icn}.pty\" r\n', 1)")" || exit 2
r="$(sg_verdict "$d" ptyw plant)"; rref="$(cat "$(sg_ref "$d" ptyw)" 2>/dev/null)"
printf '%s' "$rref" | grep -q '^terminal' && { echo "  FAIL red: with NAME.pty ignored the unit still ran on a terminal ($r)"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: NAME.pty puts iconx in the cutter and SCRIP in m3 and m4 on a terminal ($g); ignored, the ref says no terminal ($r)"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
