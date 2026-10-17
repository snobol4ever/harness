#!/usr/bin/env bash
# test_gate_icn_ipl_m4_run_ends_the_runtime_switches_before_the_programs_argv.sh -- THE IPL RUNNER PUTS -- BEFORE A PROGRAM'S ARGV
# IN MODE 4 (hq_icon 2026-09-27; Lon's word "Get IPL to 843."; ceo CEO-1315). Lon's CEO-1261 convention makes well-formed
# -d -i -s -m -u the compiled binary's own runtime switches and a double dash ends them; the rungs harness writes the double dash
# before a program's argv in m4, and test_icon_ipl_suite.sh did not, so gprogs/cquilts' own "-i 5000" was read as a 4 KB heap
# window and the binary refused (rc=134) where iconx and m3 run it.
# ARMS: (a) the runner's m4 run writes -- before the program's argv (read off test_icon_ipl_suite.sh); (b) GREEN a planted unit
# given "-i 5000 -x" as its argv mints and matches in m3 and in m4 run with --; (c) the same m4 binary run WITHOUT -- does not
# reach the program's argv intact, so the separator is load-bearing; (d) RED a runner copy without -- fails arm (a).
set -uo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_ipl_sidecar_gate.sh"
G=test_gate_icn_ipl_m4_run_ends_the_runtime_switches_before_the_programs_argv
sg_init
plant() {
  printf 'procedure main(a)\n   every write("arg ", image(!a));\nend\n' > "$SG_PKG/progs/argw.icn"
  printf 'argw\t-i\t5000\t-x\n' > "$SG_PKG/progs/argw.argv"
}
red=0
dd() { grep -c 'ipl_isolation_run "$TMP/${base}.m4.out" "$TIMEOUT" "$stdin_src" "$bin4" $_sw -- "${IPLARGV\[@\]}"' "$1/test_icon_ipl_suite.sh"; }
[ "$(dd "$SG_HERE")" -eq 1 ] || { echo "  FAIL (a): test_icon_ipl_suite.sh's m4 run does not write -- before the program's argv"; red=1; }
g="$(sg_verdict "$SG_HERE" argw plant)"
case "$g" in "MINTED=1 M3=PASS M4=PASS"*) ;; *) echo "  FAIL (b) green: $g"; red=1 ;; esac
bin="$(ls "$SG_T"/argw.*.bin 2>/dev/null | head -1)"
if [ -x "$bin" ]; then o="$("$bin" -i 5000 -x 2>&1)"; rc=$?; printf '%s' "$o" | grep -q 'arg "-i"' && [ "$rc" -eq 0 ] && { echo "  FAIL (c): without -- the binary still handed -i 5000 to the program -- the separator is not load-bearing"; red=1; }
else echo "  FAIL (c): no m4 binary to probe"; red=1; fi
d="$(sg_doctor "s = s.replace('\"\$bin4\" \$_sw -- \"\${IPLARGV[@]}\"', '\"\$bin4\" \$_sw \"\${IPLARGV[@]}\"', 1)" test_icon_ipl_suite.sh)" || exit 2
[ "$(dd "$d")" -eq 0 ] || { echo "  FAIL (d) red: the doctored runner still reads as writing --"; red=1; }
[ "$red" -eq 0 ] && { echo "✅ GATE PASS [$G]: the IPL runner ends the runtime switches before a program's argv in m4; a unit given -i 5000 matches in m3 and m4 ($g); without -- its argv does not arrive (rc=$rc)"; exit 0; }
echo "⛔ GATE FAIL [$G]"; exit 1
